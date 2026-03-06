#!/usr/bin/env python3
"""
Commodore 64 Ham Radio Log Server v2.0

Command/response server for the C64 Ham Log client.
The C64 sends text commands; the server responds with
CSV-formatted data that C64 BASIC INPUT# can parse natively.

Protocol:
  C64 sends:  COMMAND[,arg1][,arg2]...
  Server responds:  !STATUS lines + CSV data + !END
"""

import asyncio
import logging
import os
import re
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from urllib.parse import urlencode

import aiohttp
from dotenv import load_dotenv

load_dotenv()

# ── Configuration ──────────────────────────────────────────────
HOST = os.getenv("LISTEN_HOST", "0.0.0.0")
PORT = int(os.getenv("LISTEN_PORT", "6400"))
QRZ_USER = os.getenv("QRZ_USERNAME", "")
QRZ_PASS = os.getenv("QRZ_PASSWORD", "")
QRZ_API_KEY = os.getenv("QRZ_API_KEY", "")
MY_CALL = os.getenv("MY_CALLSIGN", "N0CALL")
ADIF_FILE = os.getenv("ADIF_FILE", "kg4olw.adi")

# ── Constants ──────────────────────────────────────────────────
CRLF = "\r\n"
QRZ_XML_URL = "https://xmldata.qrz.com/xml/current/"
QRZ_LOG_URL = "https://logbook.qrz.com/api"
POTA_URL = "https://api.pota.app/spot/activator"
USER_AGENT = f"C64HamLog/2.0 ({MY_CALL})"
QRZ_NS = {"q": "http://xmldata.qrz.com"}
PROTOCOL_VERSION = "2.0"

log = logging.getLogger("c64hamlog")


# ── Frequency / Band Mapping ──────────────────────────────────

BAND_EDGES = [
    (1800, 2000, "160M"),
    (3500, 4000, "80M"),
    (5330, 5410, "60M"),
    (7000, 7300, "40M"),
    (10100, 10150, "30M"),
    (14000, 14350, "20M"),
    (18068, 18168, "17M"),
    (21000, 21450, "15M"),
    (24890, 24990, "12M"),
    (28000, 29700, "10M"),
    (50000, 54000, "6M"),
    (144000, 148000, "2M"),
    (420000, 450000, "70CM"),
]


def freq_to_band(freq_str):
    """Convert frequency (kHz string) to band label. Returns '' if unknown."""
    try:
        freq = float(freq_str)
    except (ValueError, TypeError):
        return ""
    for lo, hi, band in BAND_EDGES:
        if lo <= freq <= hi:
            return band
    return ""


# ── ADIF Helpers ───────────────────────────────────────────────

def adif_field(name, value):
    """Format a single ADIF field: <name:len>value"""
    return f"<{name}:{len(value)}>{value}"


def adif_record(**fields):
    """Build an ADIF record string from keyword arguments."""
    parts = [adif_field(k, v) for k, v in fields.items()]
    parts.append("<eor>")
    return "".join(parts)


def parse_adif(text):
    """Parse ADIF text into a list of record dicts."""
    records = []
    current = {}
    i = 0
    n = len(text)
    while i < n:
        if text[i] == "<":
            j = text.find(">", i)
            if j == -1:
                break
            tag = text[i + 1 : j]
            tag_lower = tag.lower()
            if tag_lower == "eor":
                if current:
                    records.append(current)
                    current = {}
                i = j + 1
                continue
            if tag_lower == "eoh":
                current = {}
                i = j + 1
                continue
            parts = tag.split(":")
            if len(parts) >= 2:
                name = parts[0].lower()
                try:
                    length = int(parts[1])
                except ValueError:
                    i = j + 1
                    continue
                value = text[j + 1 : j + 1 + length]
                current[name] = value
                i = j + 1 + length
            else:
                i = j + 1
        else:
            i += 1
    return records


def parse_qrz_logbook_response(text):
    """Parse QRZ Logbook API response (key=value& format with ADIF)."""
    result = {}
    if "ADIF=" in text:
        idx = text.index("ADIF=")
        prefix = text[:idx].rstrip("&")
        result["ADIF"] = text[idx + 5 :]
        for pair in prefix.split("&"):
            if "=" in pair:
                k, v = pair.split("=", 1)
                result[k] = v
    else:
        for pair in text.split("&"):
            if "=" in pair:
                k, v = pair.split("=", 1)
                result[k] = v
    return result


# ── QRZ XML API (Callsign Lookups) ────────────────────────────

class QRZXmlApi:
    """Manages QRZ.com XML session for callsign lookups."""

    def __init__(self, username, password):
        self.username = username
        self.password = password
        self.session_key = None

    async def login(self, http):
        params = {
            "username": self.username,
            "password": self.password,
            "agent": USER_AGENT,
        }
        async with http.get(QRZ_XML_URL, params=params) as resp:
            text = await resp.text()
        root = ET.fromstring(text)
        key = root.find(".//q:Key", QRZ_NS)
        if key is not None:
            self.session_key = key.text
            return True
        err = root.find(".//q:Error", QRZ_NS)
        raise Exception(err.text if err is not None else "QRZ login failed")

    async def lookup(self, callsign, http):
        """Return (data_dict, error_string). One will be None."""
        if not self.session_key:
            await self.login(http)
        params = {"s": self.session_key, "callsign": callsign}
        async with http.get(QRZ_XML_URL, params=params) as resp:
            text = await resp.text()
        root = ET.fromstring(text)
        err = root.find(".//q:Error", QRZ_NS)
        if err is not None:
            if "session" in err.text.lower() or "invalid" in err.text.lower():
                self.session_key = None
                await self.login(http)
                return await self.lookup(callsign, http)
            return None, err.text
        node = root.find(".//q:Callsign", QRZ_NS)
        if node is None:
            return None, "Not found"
        data = {}
        for child in node:
            tag = child.tag.split("}")[-1]
            data[tag] = child.text or ""
        return data, None


# ── QRZ Logbook API ───────────────────────────────────────────

class QRZLogbookApi:
    """QRZ.com Logbook API for log entry management."""

    def __init__(self, api_key):
        self.api_key = api_key

    async def _post(self, http, **params):
        params["KEY"] = self.api_key
        headers = {"User-Agent": USER_AGENT}
        async with http.post(QRZ_LOG_URL, data=params, headers=headers) as resp:
            text = await resp.text()
        return parse_qrz_logbook_response(text)

    async def status(self, http):
        return await self._post(http, ACTION="STATUS")

    async def fetch(self, http, option="ALL,MAX:25"):
        return await self._post(http, ACTION="FETCH", OPTION=option)

    async def insert(self, http, adif_str):
        return await self._post(http, ACTION="INSERT", ADIF=adif_str)


# ── Local ADIF File Loader ─────────────────────────────────────

def load_local_adif():
    """Load QSO records from a local ADIF file for offline testing."""
    if not os.path.exists(ADIF_FILE):
        return []
    try:
        with open(ADIF_FILE, "r", encoding="latin-1") as f:
            text = f.read()
        records = parse_adif(text)
        log.info("Loaded %d QSOs from local ADIF file: %s", len(records), ADIF_FILE)
        return records
    except Exception as e:
        log.warning("Failed to load ADIF file %s: %s", ADIF_FILE, e)
        return []


# ── CSV Helpers ────────────────────────────────────────────────

def sanitize_csv(value):
    """Remove commas, control chars, and non-ASCII from a value for CSV safety.
    Uppercases everything — lowercase ASCII displays as graphics chars in PETSCII."""
    s = str(value) if value else ""
    s = s.replace(",", ";").replace("\r", "").replace("\n", " ").strip()
    return s.encode("ascii", errors="ignore").decode("ascii").upper()


# ── Client Session Handler (Command/Response Protocol) ────────

class ClientHandler:
    """Handles one client connection using command/response protocol.

    The C64 sends a text command (one line), the server responds with
    structured CSV data. Lines starting with ! are control/status lines.
    """

    def __init__(self, reader, writer):
        self.reader = reader
        self.writer = writer
        self.qrz_xml = QRZXmlApi(QRZ_USER, QRZ_PASS) if QRZ_USER else None
        self.qrz_log = QRZLogbookApi(QRZ_API_KEY) if QRZ_API_KEY else None
        self.http = None

    # ── I/O ─────────────────────────────────────────────────────

    async def send(self, text):
        """Send a single line (adds CR+LF), paced for 1200 baud.
        All text is lowercased because the C64 BASIC source is lowercased
        during the build (tr A-Z a-z) and string comparisons are case-sensitive."""
        log.debug("TX: %r", text)
        data = (text + CRLF).encode("latin-1", errors="replace")
        for byte in data:
            self.writer.write(bytes([byte]))
            await self.writer.drain()
            await asyncio.sleep(0.009)  # ~1ms/char at 1200 baud (10 bits/char)

    async def readline(self):
        """Read one line from client, stripping CR/LF and IP232/telnet escapes."""
        buf = []
        while True:
            data = await self.reader.read(1)
            if not data:
                raise ConnectionError("Client disconnected")
            b = data[0]
            # IP232/Telnet: 0xFF escape — consume 1 following byte
            if b == 255:
                try:
                    await asyncio.wait_for(self.reader.read(1), timeout=1.0)
                except asyncio.TimeoutError:
                    pass
                continue
            if b in (10, 13):
                if b == 13:
                    try:
                        await asyncio.wait_for(
                            self.reader.read(1), timeout=0.05
                        )
                    except asyncio.TimeoutError:
                        pass
                line = "".join(buf).strip()
                if line:
                    log.debug("RX: %r", line)
                return line
            if 32 <= b < 127:
                buf.append(chr(b))
            else:
                log.debug("RX byte: 0x%02x (ignored)", b)

    # ── Command Dispatcher ──────────────────────────────────────

    async def dispatch(self, line):
        """Parse and dispatch a command line."""
        parts = [p.strip() for p in line.split(",")]
        cmd = parts[0].upper() if parts else ""
        args = parts[1:] if len(parts) > 1 else []

        if cmd.startswith("ATDT") or cmd.startswith("AT"):
            # Hayes modem command — respond like a modem for IP232 compatibility
            await self.send("CONNECT 1200")
        elif cmd == "HELLO":
            await self.cmd_hello()
        elif cmd == "SPOTS":
            await self.cmd_spots(args)
        elif cmd == "LOOKUP":
            await self.cmd_lookup(args)
        elif cmd == "FETCH":
            await self.cmd_fetch(args)
        elif cmd == "ADD":
            await self.cmd_add(args)
        elif cmd == "SYNC":
            await self.cmd_sync(args)
        elif cmd == "BYE":
            await self.cmd_bye()
            return False
        else:
            await self.send(f"!ERR,UNKNOWN COMMAND: {cmd}")
        return True

    # ── HELLO ───────────────────────────────────────────────────

    async def cmd_hello(self):
        """Handshake: return version and UTC time."""
        now = datetime.now(timezone.utc)
        date_str = now.strftime("%Y%m%d")
        time_str = now.strftime("%H%M")
        await self.send(f"!OK,C64HAMLOG,{PROTOCOL_VERSION},{date_str},{time_str}")

    # ── SPOTS ───────────────────────────────────────────────────

    async def cmd_spots(self, args):
        """Fetch POTA spots, optionally filtered by band and/or mode.

        SPOTS[,band][,mode]  e.g.  SPOTS  SPOTS,20M  SPOTS,20M,CW
        """
        filter_band = args[0].upper() if len(args) > 0 and args[0] else ""
        filter_mode = args[1].upper() if len(args) > 1 and args[1] else ""

        try:
            headers = {"User-Agent": USER_AGENT}
            async with self.http.get(POTA_URL, headers=headers) as resp:
                if resp.status != 200:
                    await self.send(f"!ERR,POTA HTTP {resp.status}")
                    return
                spots = await resp.json()

            if not spots:
                await self.send("!SPOTS,0")
                await self.send("!END")
                return

            # Apply filters
            now = datetime.now(timezone.utc)
            filtered = []
            for spot in spots:
                # Skip spots older than 5 minutes
                spot_time_str = spot.get("spotTime", "")
                if spot_time_str:
                    try:
                        st = datetime.fromisoformat(spot_time_str.replace("Z", "+00:00"))
                        if st.tzinfo is None:
                            st = st.replace(tzinfo=timezone.utc)
                        age = (now - st).total_seconds()
                        if age > 300:
                            continue
                    except (ValueError, TypeError):
                        pass

                freq = sanitize_csv(str(spot.get("frequency", "")))[:10]
                mode = sanitize_csv(str(spot.get("mode", ""))).upper()[:6]
                band = freq_to_band(freq)

                if filter_band and band != filter_band:
                    continue
                if filter_mode and mode != filter_mode:
                    continue

                call = sanitize_csv(spot.get("activator", ""))[:12]
                park_ref = sanitize_csv(spot.get("reference", ""))[:10]
                park_name = sanitize_csv(spot.get("name", ""))[:30]
                location = sanitize_csv(spot.get("locationDesc", ""))[:15]
                grid = sanitize_csv(spot.get("grid", ""))[:6]

                filtered.append(
                    f"{call},{freq},{mode},{park_ref},"
                    f"{park_name},{location},{grid}"
                )

            filtered = filtered[:20]
            await self.send(f"!SPOTS,{len(filtered)}")
            for line in filtered:
                await self.send(line)
            await self.send("!END")

        except Exception as e:
            await self.send(f"!ERR,{sanitize_csv(str(e))}")

    # ── LOOKUP ──────────────────────────────────────────────────

    async def cmd_lookup(self, args):
        """Look up a callsign on QRZ.com.

        LOOKUP,callsign
        Response: !LOOKUP,OK followed by CSV data, or !LOOKUP,ERR,reason
        """
        if not args:
            await self.send("!LOOKUP,ERR,NO CALLSIGN")
            return
        if not self.qrz_xml:
            await self.send("!LOOKUP,ERR,QRZ NOT CONFIGURED")
            return

        callsign = args[0].upper()
        try:
            data, err = await self.qrz_xml.lookup(callsign, self.http)
            if err:
                await self.send(f"!LOOKUP,ERR,{sanitize_csv(err)}")
                return

            # Build CSV: call,name,addr,city,state,country,grid,class,
            #            cqzone,ituzone,lotw,eqsl,dxcc
            call = sanitize_csv(data.get("call", ""))
            name = sanitize_csv(
                f"{data.get('fname', '')} {data.get('name', '')}".strip()
            )
            addr = sanitize_csv(data.get("addr1", ""))
            city = sanitize_csv(data.get("addr2", ""))
            state = sanitize_csv(data.get("state", ""))
            country = sanitize_csv(data.get("country", ""))
            grid = sanitize_csv(data.get("grid", ""))
            lic_class = sanitize_csv(data.get("class", ""))
            cqzone = sanitize_csv(data.get("cqzone", ""))
            ituzone = sanitize_csv(data.get("ituzone", ""))
            lotw = "Y" if data.get("lotw") == "1" else "N"
            eqsl = "Y" if data.get("eqsl") == "1" else "N"
            dxcc = sanitize_csv(data.get("dxcc", ""))

            await self.send("!LOOKUP,OK")
            await self.send(
                f"{call},{name},{addr},{city},{state},{country},"
                f"{grid},{lic_class},{cqzone},{ituzone},{lotw},{eqsl},{dxcc}"
            )
            await self.send("!END")

        except Exception as e:
            await self.send(f"!LOOKUP,ERR,{sanitize_csv(str(e))}")

    # ── FETCH ───────────────────────────────────────────────────

    async def cmd_fetch(self, args):
        """Fetch logbook entries from QRZ or local ADIF file.

        FETCH[,YYYYMMDD]  — optionally filter since a date
        Response: !LOG,count followed by CSV records, then !END
        """
        try:
            records = []
            if self.qrz_log:
                if args and len(args[0]) == 8:
                    since = args[0]
                    option = (
                        f"MODSINCE:{since[:4]}-{since[4:6]}"
                        f"-{since[6:8]},MAX:100"
                    )
                else:
                    option = "ALL,MAX:100"

                resp = await self.qrz_log.fetch(self.http, option)
                if resp.get("RESULT") != "OK":
                    reason = resp.get("REASON", "UNKNOWN")
                    await self.send(f"!ERR,{sanitize_csv(reason)}")
                    return
                records = parse_adif(resp.get("ADIF", ""))
            else:
                # No QRZ logbook configured — nothing to fetch
                await self.send("!LOG,0")
                await self.send("!END")
                return

            await self._send_log_records(records, paced=True)

        except Exception as e:
            await self.send(f"!ERR,{sanitize_csv(str(e))}")

    async def _send_log_records(self, records, paced=False):
        """Format and send log records as CSV.

        If paced=True, wait for a 'K' ACK from the client after each record
        to avoid overflowing the C64's 256-byte RS232 receive buffer during
        slow disk writes.
        """
        await self.send(f"!LOG,{len(records)}")

        for idx, rec in enumerate(records):
            logid = sanitize_csv(
                rec.get("app_qrzlog_logid", str(idx + 1))
            )
            call = sanitize_csv(rec.get("call", ""))
            band = sanitize_csv(rec.get("band", ""))
            mode = sanitize_csv(rec.get("mode", ""))
            freq = sanitize_csv(rec.get("freq", ""))
            date = sanitize_csv(rec.get("qso_date", ""))
            time = sanitize_csv(rec.get("time_on", ""))[:4]
            rsts = sanitize_csv(rec.get("rst_sent", ""))
            rstr = sanitize_csv(rec.get("rst_rcvd", ""))
            grid = sanitize_csv(rec.get("gridsquare", ""))
            name = sanitize_csv(rec.get("name", ""))[:30]
            country = sanitize_csv(rec.get("country", ""))[:15]
            comment = sanitize_csv(rec.get("comment", ""))[:40]

            await self.send(
                f"{logid},{call},{band},{mode},{freq},{date},{time},"
                f"{rsts},{rstr},{grid},{name},{country},{comment}"
            )

            if paced:
                try:
                    ack = await asyncio.wait_for(self.readline(), timeout=30.0)
                    log.debug("ACK: %r", ack)
                except asyncio.TimeoutError:
                    log.warning("Timeout waiting for ACK after record %d", idx + 1)
                    break

        await self.send("!END")

    # ── ADD ─────────────────────────────────────────────────────

    async def cmd_add(self, args):
        """Add a QSO to the QRZ logbook.

        ADD,call,band,mode,freq,date,time,rsts,rstr,comment
        Response: !ADD,OK,logid  or  !ADD,ERR,reason
        """
        if not self.qrz_log:
            await self.send("!ADD,ERR,QRZ LOGBOOK NOT CONFIGURED")
            return

        if len(args) < 8:
            await self.send("!ADD,ERR,TOO FEW FIELDS")
            return

        call = args[0].upper()
        band = args[1].lower()
        if not band.endswith("m") and not band.endswith("cm"):
            band += "m"
        mode = args[2].upper()
        freq = args[3]
        date = args[4]
        time = args[5]
        rsts = args[6]
        rstr = args[7]
        comment = args[8] if len(args) > 8 else ""

        fields = dict(
            call=call,
            band=band,
            mode=mode,
            qso_date=date,
            time_on=time,
            station_callsign=MY_CALL,
            rst_sent=rsts,
            rst_rcvd=rstr,
        )
        if freq:
            fields["freq"] = freq
        if comment:
            fields["comment"] = comment

        rec = adif_record(**fields)

        try:
            resp = await self.qrz_log.insert(self.http, rec)
            result = resp.get("RESULT", "")
            if result in ("OK", "REPLACE"):
                logid = resp.get("LOGID", "0")
                await self.send(f"!ADD,OK,{logid}")
            else:
                reason = resp.get("REASON", "UNKNOWN ERROR")
                await self.send(f"!ADD,ERR,{sanitize_csv(reason)}")
        except Exception as e:
            await self.send(f"!ADD,ERR,{sanitize_csv(str(e))}")

    # ── SYNC ────────────────────────────────────────────────────

    async def cmd_sync(self, args):
        """Incremental sync — return QSOs added since last known LogID.

        SYNC,lastlogid  — returns all QSOs with LogID > lastlogid
        Response: same as FETCH (!LOG,count + CSV + !END)
        """
        last_id = args[0] if args else "0"

        try:
            if self.qrz_log:
                resp = await self.qrz_log.fetch(self.http, "ALL,MAX:200")
                if resp.get("RESULT") != "OK":
                    reason = resp.get("REASON", "UNKNOWN")
                    await self.send(f"!ERR,{sanitize_csv(reason)}")
                    return
                records = parse_adif(resp.get("ADIF", ""))
            else:
                # Fall back to local ADIF file
                records = load_local_adif()

            # Filter to records with LogID > last_id
            try:
                last_num = int(last_id)
            except ValueError:
                last_num = 0

            new_records = []
            for idx, rec in enumerate(records):
                logid_str = rec.get("app_qrzlog_logid", str(idx + 1))
                try:
                    logid_num = int(logid_str)
                except ValueError:
                    logid_num = idx + 1
                if logid_num > last_num:
                    new_records.append(rec)

            await self._send_log_records(new_records, paced=True)

        except Exception as e:
            await self.send(f"!ERR,{sanitize_csv(str(e))}")

    # ── BYE ─────────────────────────────────────────────────────

    async def cmd_bye(self):
        """Disconnect gracefully."""
        await self.send(f"!BYE,73 DE {MY_CALL}")

    # ── Main Session Loop ───────────────────────────────────────

    async def run(self):
        addr = self.writer.get_extra_info("peername")
        log.info("Connection from %s", addr)
        try:
            async with aiohttp.ClientSession() as http:
                self.http = http

                # Pre-login to QRZ if configured
                if self.qrz_xml:
                    try:
                        await self.qrz_xml.login(http)
                        log.info("QRZ XML session ready for %s", addr)
                    except Exception as e:
                        log.warning("QRZ login failed: %s", e)

                # Command loop
                while True:
                    line = await self.readline()
                    if not line:
                        continue
                    log.info("CMD from %s: %s", addr, line)
                    keep_going = await self.dispatch(line)
                    if not keep_going:
                        break

        except (ConnectionError, asyncio.IncompleteReadError):
            log.info("Client %s disconnected", addr)
        except Exception:
            log.exception("Error with client %s", addr)
        finally:
            try:
                self.writer.close()
                await self.writer.wait_closed()
            except Exception:
                pass
            log.info("Session ended: %s", addr)


# ── Server Entry Point ────────────────────────────────────────

async def handle_client(reader, writer):
    handler = ClientHandler(reader, writer)
    await handler.run()


async def main():
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s [%(name)s] %(levelname)s %(message)s",
    )
    server = await asyncio.start_server(handle_client, HOST, PORT)
    addrs = ", ".join(str(s.getsockname()) for s in server.sockets)
    log.info("C64 Ham Log Server v%s listening on %s", PROTOCOL_VERSION, addrs)
    log.info("Station: %s", MY_CALL)
    if not QRZ_USER:
        log.warning("QRZ_USERNAME not set — callsign lookups disabled")
    if not QRZ_API_KEY:
        log.warning("QRZ_API_KEY not set — logbook operations disabled")
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())

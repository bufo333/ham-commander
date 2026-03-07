#!/usr/bin/env python3
"""Commodore disk image builder — D81 (1581) and D64 (1541) formats.

Shared module used by create_disk.py and import_adif.py.
See DISK_FORMAT.md for detailed technical reference.
"""

import math
import os
import struct
import subprocess
import sys

# ── Common constants ──────────────────────────────────────────
SECTOR_SIZE = 256
DATA_PER_SECTOR = 254          # 256 - 2 byte chain link
RECORD_SIZE = 168              # full detail record
SUMMARY_SIZE = 40              # quick summary record for log screen

# Max records per disk format (conservative, accounts for PRG + overhead)
MAX_RECORDS = {"d81": 3500, "d64": 700}

# ── Band edges (shared with server.py) ───────────────────────
BAND_EDGES = [
    (1800, 2000, "160M"), (3500, 4000, "80M"), (5330, 5410, "60M"),
    (7000, 7300, "40M"), (10100, 10150, "30M"), (14000, 14350, "20M"),
    (18068, 18168, "17M"), (21000, 21450, "15M"), (24890, 24990, "12M"),
    (28000, 29700, "10M"), (50000, 54000, "6M"), (144000, 148000, "2M"),
    (420000, 450000, "70CM"),
]


def freq_to_band(freq_str):
    try:
        freq = float(freq_str)
    except (ValueError, TypeError):
        return ""
    for lo, hi, band in BAND_EDGES:
        if lo <= freq <= hi:
            return band
    return ""


# ── ADIF Parser ───────────────────────────────────────────────

def parse_adif(text):
    records, current, i, n = [], {}, 0, len(text)
    while i < n:
        if text[i] == "<":
            j = text.find(">", i)
            if j == -1:
                break
            tag = text[i + 1 : j]
            tl = tag.lower()
            if tl == "eor":
                if current:
                    records.append(current)
                    current = {}
                i = j + 1
                continue
            if tl == "eoh":
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
                current[name] = text[j + 1 : j + 1 + length]
                i = j + 1 + length
            else:
                i = j + 1
        else:
            i += 1
    return records


# ── Record packing ────────────────────────────────────────────

def pack_summary(rec):
    """Pack a 40-byte summary record: call(10)+band(4)+mode(4)+date(8)+time(4)+rsts(3)+rstr(3)+flag(1)+pad(2)+CR."""
    def field(key, width):
        return rec.get(key, "").upper()[:width].ljust(width)

    band = rec.get("band", "").upper()
    if not band:
        band = freq_to_band(rec.get("freq", ""))

    body = (
        field("call", 10) +
        band[:4].ljust(4) +
        field("mode", 4) +
        field("qso_date", 8) +
        field("time_on", 4) +
        field("rst_sent", 3) +
        field("rst_rcvd", 3) +
        "S" +
        "  "
    )  # = 39 chars
    assert len(body) == 39, f"Summary body is {len(body)}, expected 39"
    body = body.replace(",", ";").replace("\r", " ").replace("\n", " ")
    return (body + "\r").encode("ascii", errors="replace")


def pack_record(rec):
    """Pack an ADIF dict into a 168-byte C64 REL record (ASCII bytes)."""
    def field(key, width):
        return rec.get(key, "").upper()[:width].ljust(width)

    band = rec.get("band", "").upper()
    if not band:
        band = freq_to_band(rec.get("freq", ""))

    freq = rec.get("freq", "").upper()
    comment = rec.get("comment", "").upper()[:40]

    half1 = (
        field("call", 12) +
        band[:6].ljust(6) +
        field("mode", 6) +
        field("qso_date", 8) +
        field("time_on", 4) +
        freq[:10].ljust(10) +
        field("rst_sent", 3) +
        field("rst_rcvd", 3) +
        field("station_callsign", 12) +
        field("app_qrzlog_logid", 12) +
        "S" +
        comment[:6].ljust(6)
    )
    assert len(half1) == 83, f"Half1 is {len(half1)}, expected 83"

    half2 = (
        comment[6:40].ljust(34) +
        field("gridsquare", 6) +
        field("name", 30) +
        field("country", 13)
    )
    assert len(half2) == 83, f"Half2 is {len(half2)}, expected 83"

    half1 = half1.replace(",", ";").replace("\r", " ").replace("\n", " ")
    half2 = half2.replace(",", ";").replace("\r", " ").replace("\n", " ")
    data = half1 + "\r" + half2 + "\r"
    assert len(data) == RECORD_SIZE
    return data.encode("ascii", errors="replace")


# ── D64 Geometry ──────────────────────────────────────────────

D64_TRACKS = 35
D64_DIR_TRACK = 18

# Sectors per track for 1541
D64_SPT = {}
for _t in range(1, 18):
    D64_SPT[_t] = 21
for _t in range(18, 25):
    D64_SPT[_t] = 19
for _t in range(25, 31):
    D64_SPT[_t] = 18
for _t in range(31, 36):
    D64_SPT[_t] = 17

# Pre-compute cumulative sector offsets for each track
D64_TRACK_OFFSET = {}
_cumulative = 0
for _t in range(1, 36):
    D64_TRACK_OFFSET[_t] = _cumulative
    _cumulative += D64_SPT[_t]
D64_TOTAL_SECTORS = _cumulative  # 683


# ── D81 Geometry ──────────────────────────────────────────────

D81_TRACKS = 80
D81_SECTORS_PER_TRACK = 40
D81_DIR_TRACK = 40


# ── Directory entry builder ───────────────────────────────────

def make_dir_entry(file_type, first_t, first_s, filename, side_t=0, side_s=0,
                   rec_len=0, total_sectors=0):
    """Build a 32-byte directory entry."""
    e = bytearray(32)
    e[0x02] = file_type
    e[0x03] = first_t
    e[0x04] = first_s
    nm = filename.upper().encode("ascii")[:16].ljust(16, b'\xa0')
    e[0x05:0x15] = nm
    e[0x15] = side_t
    e[0x16] = side_s
    e[0x17] = rec_len
    e[0x1E] = total_sectors & 0xFF
    e[0x1F] = (total_sectors >> 8) & 0xFF
    return bytes(e)


# ── D81 Image ─────────────────────────────────────────────────

class D81Image:
    """1581 D81 disk image builder."""

    FORMAT = "d81"
    HAS_SSS = True

    def __init__(self):
        self.data = bytearray(D81_TRACKS * D81_SECTORS_PER_TRACK * SECTOR_SIZE)
        self.free = {}
        for t in range(1, 81):
            self.free[t] = set(range(40))
        for s in range(4):
            self.free[D81_DIR_TRACK].discard(s)

    def _off(self, t, s):
        return ((t - 1) * D81_SECTORS_PER_TRACK + s) * SECTOR_SIZE

    def write_sector(self, t, s, data):
        off = self._off(t, s)
        self.data[off:off + 256] = data[:256].ljust(256, b'\x00')

    def alloc(self, preferred_track=None):
        order = list(range(1, 40)) + list(range(41, 81))
        if preferred_track and preferred_track != D81_DIR_TRACK:
            order = [preferred_track] + [t for t in order if t != preferred_track]
        for t in order:
            if self.free[t]:
                s = min(self.free[t])
                self.free[t].discard(s)
                return t, s
        raise RuntimeError("Disk full!")

    def alloc_on_dir_track(self):
        if self.free[D81_DIR_TRACK]:
            s = min(self.free[D81_DIR_TRACK])
            self.free[D81_DIR_TRACK].discard(s)
            return D81_DIR_TRACK, s
        raise RuntimeError("Track 40 full!")

    def write_header(self, name, disk_id):
        sec = bytearray(256)
        sec[0x00] = D81_DIR_TRACK
        sec[0x01] = 3  # DIR_START_SECTOR
        sec[0x02] = 0x44  # 'D' for 1581
        nm = name.upper().encode("ascii")[:16].ljust(16, b'\xa0')
        sec[0x04:0x14] = nm
        sec[0x14] = 0xA0
        sec[0x15] = 0xA0
        did = disk_id.upper().encode("ascii")[:2].ljust(2, b'\xa0')
        sec[0x16:0x18] = did
        sec[0x18] = 0xA0
        sec[0x19] = 0x33  # '3'
        sec[0x1A] = 0x44  # 'D'
        sec[0x1B] = 0xA0
        sec[0x1C] = 0xA0
        self.write_sector(D81_DIR_TRACK, 0, sec)

    def write_bam(self, disk_id):
        did = disk_id.upper().encode("ascii")[:2].ljust(2, b'\xa0')
        for bam_num in range(2):
            sec = bytearray(256)
            if bam_num == 0:
                sec[0x00] = D81_DIR_TRACK
                sec[0x01] = 2  # BAM2
                tracks = range(1, 41)
            else:
                sec[0x00] = 0x00
                sec[0x01] = 0xFF
                tracks = range(41, 81)
            sec[0x02] = 0x44
            sec[0x03] = 0xBB
            sec[0x04:0x06] = did
            sec[0x06] = 0xC0
            off = 0x10
            for t in tracks:
                free_set = self.free[t]
                cnt = len(free_set)
                bitmap = 0
                for s2 in free_set:
                    bitmap |= (1 << s2)
                bm = struct.pack("<Q", bitmap)[:5]
                sec[off] = cnt
                sec[off + 1:off + 6] = bm
                off += 6
            bam_sec = 1 if bam_num == 0 else 2
            self.write_sector(D81_DIR_TRACK, bam_sec, sec)

    def init_directory(self, num_entries_needed):
        num_sectors = max(1, math.ceil(num_entries_needed / 8))
        dir_sectors = [(D81_DIR_TRACK, 3)]
        for i in range(1, num_sectors):
            t, s = self.alloc_on_dir_track()
            dir_sectors.append((t, s))
        for i, (t, s) in enumerate(dir_sectors):
            sec = bytearray(256)
            if i < len(dir_sectors) - 1:
                sec[0x00], sec[0x01] = dir_sectors[i + 1]
            else:
                sec[0x00] = 0x00
                sec[0x01] = 0xFF
            self.write_sector(t, s, sec)
        self.dir_sectors = dir_sectors

    def write_dir_entry(self, index, entry):
        sec_idx = index // 8
        ent_idx = index % 8
        t, s = self.dir_sectors[sec_idx]
        off = self._off(t, s) + ent_idx * 32
        if ent_idx == 0:
            self.data[off + 2:off + 32] = entry[2:32]
        else:
            self.data[off:off + 32] = entry[:32]

    def save(self, path):
        with open(path, "wb") as f:
            f.write(self.data)

    def free_sectors(self):
        return sum(len(s) for s in self.free.values())


# ── D64 Image ─────────────────────────────────────────────────

class D64Image:
    """1541 D64 disk image builder."""

    FORMAT = "d64"
    HAS_SSS = False

    def __init__(self):
        self.data = bytearray(D64_TOTAL_SECTORS * SECTOR_SIZE)
        self.free = {}
        for t in range(1, 36):
            self.free[t] = set(range(D64_SPT[t]))
        # Reserve track 18 sector 0 (BAM/header)
        self.free[D64_DIR_TRACK].discard(0)
        # Sector 1 reserved for first directory sector
        self.free[D64_DIR_TRACK].discard(1)
        self._disk_name = "HAMLOG"
        self._disk_id = "HL"

    def _off(self, t, s):
        return (D64_TRACK_OFFSET[t] + s) * SECTOR_SIZE

    def write_sector(self, t, s, data):
        off = self._off(t, s)
        self.data[off:off + 256] = data[:256].ljust(256, b'\x00')

    def alloc(self, preferred_track=None):
        order = list(range(1, 18)) + list(range(19, 36))
        if preferred_track and preferred_track != D64_DIR_TRACK:
            order = [preferred_track] + [t for t in order if t != preferred_track]
        for t in order:
            if self.free[t]:
                s = min(self.free[t])
                self.free[t].discard(s)
                return t, s
        raise RuntimeError("Disk full!")

    def alloc_on_dir_track(self):
        if self.free[D64_DIR_TRACK]:
            s = min(self.free[D64_DIR_TRACK])
            self.free[D64_DIR_TRACK].discard(s)
            return D64_DIR_TRACK, s
        raise RuntimeError("Track 18 full!")

    def write_header(self, name, disk_id):
        # D64 header is part of BAM sector — stored for write_bam
        self._disk_name = name
        self._disk_id = disk_id

    def write_bam(self, disk_id):
        sec = bytearray(256)
        sec[0x00] = D64_DIR_TRACK  # first dir track
        sec[0x01] = 1              # first dir sector
        sec[0x02] = 0x41           # 'A' — DOS version
        sec[0x03] = 0x00

        # BAM entries: 4 bytes per track (tracks 1-35) starting at $04
        off = 0x04
        for t in range(1, 36):
            free_set = self.free[t]
            cnt = len(free_set)
            bitmap = 0
            for s2 in free_set:
                bitmap |= (1 << s2)
            bm = struct.pack("<I", bitmap)[:3]
            sec[off] = cnt
            sec[off + 1:off + 4] = bm
            off += 4

        # Disk name at $90
        nm = self._disk_name.upper().encode("ascii")[:16].ljust(16, b'\xa0')
        sec[0x90:0xA0] = nm
        sec[0xA0] = 0xA0
        sec[0xA1] = 0xA0
        did = disk_id.upper().encode("ascii")[:2].ljust(2, b'\xa0')
        sec[0xA2:0xA4] = did
        sec[0xA4] = 0xA0
        sec[0xA5] = 0x32  # '2'
        sec[0xA6] = 0x41  # 'A'
        sec[0xA7:0xAB] = b'\xa0' * 4

        self.write_sector(D64_DIR_TRACK, 0, sec)

    def init_directory(self, num_entries_needed):
        num_sectors = max(1, math.ceil(num_entries_needed / 8))
        dir_sectors = [(D64_DIR_TRACK, 1)]
        for i in range(1, num_sectors):
            t, s = self.alloc_on_dir_track()
            dir_sectors.append((t, s))
        for i, (t, s) in enumerate(dir_sectors):
            sec = bytearray(256)
            if i < len(dir_sectors) - 1:
                sec[0x00], sec[0x01] = dir_sectors[i + 1]
            else:
                sec[0x00] = 0x00
                sec[0x01] = 0xFF
            self.write_sector(t, s, sec)
        self.dir_sectors = dir_sectors

    def write_dir_entry(self, index, entry):
        sec_idx = index // 8
        ent_idx = index % 8
        t, s = self.dir_sectors[sec_idx]
        off = self._off(t, s) + ent_idx * 32
        if ent_idx == 0:
            self.data[off + 2:off + 32] = entry[2:32]
        else:
            self.data[off:off + 32] = entry[:32]

    def save(self, path):
        with open(path, "wb") as f:
            f.write(self.data)

    def free_sectors(self):
        return sum(len(s) for s in self.free.values())


# ── Factory ───────────────────────────────────────────────────

def create_disk_image(fmt="d81"):
    if fmt == "d81":
        return D81Image()
    elif fmt == "d64":
        return D64Image()
    else:
        raise ValueError(f"Unknown disk format: {fmt}")


# ── Shared file-writing functions ─────────────────────────────

def write_prg_file(img, filename, prg_bytes, dir_index):
    """Write a PRG file to the image."""
    sectors_needed = max(1, math.ceil(len(prg_bytes) / DATA_PER_SECTOR))
    chain = [img.alloc() for _ in range(sectors_needed)]

    for i, (t, s) in enumerate(chain):
        sec = bytearray(256)
        chunk = prg_bytes[i * DATA_PER_SECTOR:(i + 1) * DATA_PER_SECTOR]
        if i < len(chain) - 1:
            sec[0x00], sec[0x01] = chain[i + 1]
        else:
            sec[0x00] = 0x00
            sec[0x01] = len(chunk) + 1
        sec[2:2 + len(chunk)] = chunk
        img.write_sector(t, s, sec)

    entry = make_dir_entry(0x82, chain[0][0], chain[0][1], filename,
                           total_sectors=len(chain))
    img.write_dir_entry(dir_index, entry)
    return chain[0], len(chain)


def write_seq_file(img, filename, content_bytes, dir_index):
    """Write a SEQ file to the image."""
    sectors_needed = max(1, math.ceil(len(content_bytes) / DATA_PER_SECTOR))
    chain = [img.alloc() for _ in range(sectors_needed)]

    for i, (t, s) in enumerate(chain):
        sec = bytearray(256)
        chunk = content_bytes[i * DATA_PER_SECTOR:(i + 1) * DATA_PER_SECTOR]
        if i < len(chain) - 1:
            sec[0x00], sec[0x01] = chain[i + 1]
        else:
            sec[0x00] = 0x00
            sec[0x01] = len(chunk) + 1
        sec[2:2 + len(chunk)] = chunk
        img.write_sector(t, s, sec)

    entry = make_dir_entry(0x81, chain[0][0], chain[0][1], filename,
                           total_sectors=len(chain))
    img.write_dir_entry(dir_index, entry)
    return chain[0], len(chain)


def write_rel_file(img, filename, records_data, record_size, dir_index):
    """Write a REL file with packed record data.

    Uses super side sector for D81 (1581), plain side sectors for D64 (1541).
    """
    num_records = len(records_data)

    # ── Build contiguous data stream ──────────────────────────
    stream = bytearray()
    for rec in records_data:
        stream.extend(rec)
    remainder = len(stream) % DATA_PER_SECTOR
    if remainder:
        stream.extend(b'\x00' * (DATA_PER_SECTOR - remainder))

    num_data_sectors = len(stream) // DATA_PER_SECTOR

    # ── Allocate and write data sectors ───────────────────────
    data_chain = [img.alloc() for _ in range(num_data_sectors)]

    for i, (t, s) in enumerate(data_chain):
        sec = bytearray(256)
        if i < len(data_chain) - 1:
            sec[0x00], sec[0x01] = data_chain[i + 1]
        else:
            used = (num_records * record_size) % DATA_PER_SECTOR
            if used == 0:
                used = DATA_PER_SECTOR
            sec[0x00] = 0x00
            sec[0x01] = used + 1
        sec[2:] = stream[i * DATA_PER_SECTOR:(i + 1) * DATA_PER_SECTOR]
        img.write_sector(t, s, sec)

    # ── Build side sectors ────────────────────────────────────
    groups = []
    ds_idx = 0
    while ds_idx < len(data_chain):
        group_data = data_chain[ds_idx:ds_idx + 720]
        ds_idx += len(group_data)
        ss_count = math.ceil(len(group_data) / 120)
        ss_ts = [img.alloc() for _ in range(ss_count)]
        groups.append((ss_ts, group_data))

    # Write side sectors
    total_ss = 0
    for g_idx, (ss_ts, group_data) in enumerate(groups):
        for ss_idx, (t, s) in enumerate(ss_ts):
            sec = bytearray(256)
            if ss_idx < len(ss_ts) - 1:
                sec[0x00], sec[0x01] = ss_ts[ss_idx + 1]
            else:
                chunk = group_data[ss_idx * 120:(ss_idx + 1) * 120]
                sec[0x00] = 0x00
                sec[0x01] = 0x10 + len(chunk) * 2 - 1
            sec[0x02] = ss_idx  # within group (0-5)
            sec[0x03] = record_size
            for i in range(min(6, len(ss_ts))):
                sec[0x04 + i * 2] = ss_ts[i][0]
                sec[0x05 + i * 2] = ss_ts[i][1]
            chunk = group_data[ss_idx * 120:(ss_idx + 1) * 120]
            for i, (dt, ds_) in enumerate(chunk):
                sec[0x10 + i * 2] = dt
                sec[0x11 + i * 2] = ds_
            img.write_sector(t, s, sec)
            total_ss += 1

    if img.HAS_SSS:
        # D81: write super side sector
        sss_t, sss_s = img.alloc()
        sec = bytearray(256)
        first_ss_t, first_ss_s = groups[0][0][0]
        sec[0x00] = first_ss_t
        sec[0x01] = first_ss_s
        sec[0x02] = 0xFE  # super side sector marker
        for i, (ss_ts, _) in enumerate(groups):
            if i < 126:
                sec[0x03 + i * 2] = ss_ts[0][0]
                sec[0x04 + i * 2] = ss_ts[0][1]
        img.write_sector(sss_t, sss_s, sec)

        entry = make_dir_entry(0x84, data_chain[0][0], data_chain[0][1], filename,
                               side_t=sss_t, side_s=sss_s, rec_len=record_size,
                               total_sectors=num_data_sectors)
        img.write_dir_entry(dir_index, entry)
        return num_data_sectors + total_ss + 1
    else:
        # D64: no SSS, directory points to first side sector
        first_ss_t, first_ss_s = groups[0][0][0]
        entry = make_dir_entry(0x84, data_chain[0][0], data_chain[0][1], filename,
                               side_t=first_ss_t, side_s=first_ss_s,
                               rec_len=record_size, total_sectors=num_data_sectors)
        img.write_dir_entry(dir_index, entry)
        return num_data_sectors + total_ss


# ── PRG build helper ──────────────────────────────────────────

def build_prg(bas_path="c64_hamlog.bas", prg_path="c64_hamlog.prg"):
    """Build PRG from .bas source using bas_lower.py + petcat.

    Returns the PRG bytes. Saves to prg_path.
    """
    script_dir = os.path.dirname(os.path.abspath(__file__))
    bas_lower = os.path.join(script_dir, "bas_lower.py")

    if not os.path.exists(bas_path):
        print(f"Error: {bas_path} not found")
        sys.exit(1)
    if not os.path.exists(bas_lower):
        print(f"Error: bas_lower.py not found at {bas_lower}")
        sys.exit(1)

    tmp_lower = "/tmp/hamlog_lower.bas"

    # Step 1: lowercase BASIC keywords (preserving string literals)
    with open(bas_path, "r") as fin:
        source = fin.read()
    result = subprocess.run(
        [sys.executable, bas_lower],
        input=source, capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"Error running bas_lower.py: {result.stderr}")
        sys.exit(1)
    with open(tmp_lower, "w") as f:
        f.write(result.stdout)

    # Step 2: tokenize with petcat
    result = subprocess.run(
        ["petcat", "-w2", "-o", prg_path, "--", tmp_lower],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"Error running petcat: {result.stderr}")
        sys.exit(1)

    with open(prg_path, "rb") as f:
        return f.read()


# ── Disk building helper ─────────────────────────────────────

def build_disk(fmt, prg_bytes, packed_sum, packed_full, import_count,
               max_records, last_logid, cfg_content, output_path,
               disk_number=1):
    """Build a single disk image with the given records.

    packed_sum/packed_full: lists of packed record bytes (already padded to max_records).
    """
    img = create_disk_image(fmt)
    img.write_header("HAMLOG", "HL")
    img.init_directory(num_entries_needed=5)

    dir_idx = 0

    # PRG
    if prg_bytes:
        write_prg_file(img, "HAMLOG", prg_bytes, dir_idx)
        dir_idx += 1

    # HAMLOG.SUM
    sum_sectors = write_rel_file(img, "HAMLOG.SUM", packed_sum, SUMMARY_SIZE, dir_idx)
    dir_idx += 1

    # HAMLOG.DAT
    dat_sectors = write_rel_file(img, "HAMLOG.DAT", packed_full, RECORD_SIZE, dir_idx)
    dir_idx += 1

    # HAMLOG.IDX
    idx_content = f"{import_count}\r{last_logid}\r0\r{max_records}\r{disk_number}\r".encode("ascii")
    write_seq_file(img, "HAMLOG.IDX", idx_content, dir_idx)
    dir_idx += 1

    # HAMLOG.CFG
    write_seq_file(img, "HAMLOG.CFG", cfg_content, dir_idx)
    dir_idx += 1

    # BAM (must be last)
    img.write_bam("HL")
    img.save(output_path)

    return img.free_sectors(), sum_sectors, dat_sectors

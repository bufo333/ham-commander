#!/usr/bin/env python3
"""Import ADIF records into a D81 disk image as a CBM REL file.

Creates hamlog.d81 with:
  - HAMLOG     (PRG) — the C64 program (from c64_hamlog.prg)
  - HAMLOG.DAT (REL) — QSO records, 168 bytes each
  - HAMLOG.IDX (SEQ) — record count + last logid
  - HAMLOG.CFG (SEQ) — station config

Usage:
  python3 import_adif.py [--skip-last N] [--prg c64_hamlog.prg]

Defaults: skip last 50 records, read kg4olw.adi, output hamlog.d81
"""

import argparse
import math
import struct
import os
import subprocess
import sys

# ── D81 Geometry ─────────────────────────────────────────────
TRACKS = 80
SECTORS_PER_TRACK = 40
SECTOR_SIZE = 256
DATA_PER_SECTOR = 254          # 256 - 2 byte forward-link
RECORD_SIZE = 168       # full detail record
SUMMARY_SIZE = 40       # quick summary record for log screen

# Track 40 layout
DIR_TRACK = 40
HEADER_SECTOR = 0
BAM1_SECTOR = 1                # tracks 1-40
BAM2_SECTOR = 2                # tracks 41-80
DIR_START_SECTOR = 3


def sector_offset(track, sector):
    return ((track - 1) * SECTORS_PER_TRACK + sector) * SECTOR_SIZE


# ── ADIF Parser (same as server.py) ─────────────────────────

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


# ── Band edges (same as server.py) ──────────────────────────

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


# ── Pack one QSO into a 168-byte record ─────────────────────

def pack_summary(rec):
    """Pack a 40-byte summary record: call(10)+band(4)+mode(4)+date(8)+time(4)+rsts(3)+rstr(3)+flag(1)+pad(2)+CR = 40."""
    def field(key, width):
        val = rec.get(key, "").upper()[:width]
        return val.ljust(width)

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
        "S" +                       # sync flag
        "  "                        # padding
    )  # = 39 chars
    assert len(body) == 39, f"Summary body is {len(body)}, expected 39"
    body = body.replace(",", ";").replace("\r", " ").replace("\n", " ")
    return (body + "\r").encode("ascii", errors="replace")


def pack_record(rec):
    """Pack an ADIF dict into a 168-byte C64 REL record (ASCII bytes).

    All text is uppercased for PETSCII compatibility on C64 screen.
    """
    def field(key, width):
        val = rec.get(key, "").upper()[:width]
        return val.ljust(width)

    # Band: prefer explicit, fall back to freq_to_band
    band = rec.get("band", "").upper()
    if not band:
        band = freq_to_band(rec.get("freq", ""))

    # Freq: strip trailing zeros, convert to kHz string
    freq = rec.get("freq", "").upper()

    # Two-half format: half1(83)+CR + half2(83)+CR = 168 bytes
    # Each half fits in C64 INPUT# buffer (max ~160 chars)
    comment = rec.get("comment", "").upper()[:40]

    # Half 1 (83): call(12)+band(6)+mode(6)+date(8)+time(4)+freq(10)+
    #              rsts(3)+rstr(3)+stn(12)+logid(12)+flag(1)+cmt(6)
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

    # Half 2 (83): cmt(34)+grid(6)+name(30)+country(13)
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
    assert len(data) == RECORD_SIZE, f"Record is {len(data)} bytes, expected {RECORD_SIZE}"
    return data.encode("ascii", errors="replace")


# ── D81 Image Builder ───────────────────────────────────────

class D81Image:
    def __init__(self):
        self.data = bytearray(TRACKS * SECTORS_PER_TRACK * SECTOR_SIZE)
        # Track free sector sets
        self.free = {}
        for t in range(1, 81):
            self.free[t] = set(range(40))
        # Reserve track 40 system sectors
        for s in range(4):
            self.free[40].discard(s)

    def _off(self, t, s):
        return sector_offset(t, s)

    def write_sector(self, t, s, data):
        off = self._off(t, s)
        self.data[off:off + 256] = data[:256].ljust(256, b'\x00')

    def alloc(self, preferred_track=None):
        """Allocate next free sector, avoiding track 40."""
        order = list(range(1, 40)) + list(range(41, 81))
        if preferred_track and preferred_track != 40:
            order = [preferred_track] + [t for t in order if t != preferred_track]
        for t in order:
            if self.free[t]:
                s = min(self.free[t])
                self.free[t].discard(s)
                return t, s
        raise RuntimeError("Disk full!")

    def alloc_on_40(self):
        """Allocate a sector on track 40 (for directory)."""
        if self.free[40]:
            s = min(self.free[40])
            self.free[40].discard(s)
            return 40, s
        raise RuntimeError("Track 40 full!")

    def write_header(self, name, disk_id):
        sec = bytearray(256)
        sec[0x00] = DIR_TRACK
        sec[0x01] = DIR_START_SECTOR
        sec[0x02] = 0x44  # 'D'
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
        self.write_sector(DIR_TRACK, HEADER_SECTOR, sec)

    def write_bam(self, disk_id):
        did = disk_id.upper().encode("ascii")[:2].ljust(2, b'\xa0')
        for bam_num in range(2):
            sec = bytearray(256)
            if bam_num == 0:
                sec[0x00] = DIR_TRACK
                sec[0x01] = BAM2_SECTOR
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
            bam_sec = BAM1_SECTOR if bam_num == 0 else BAM2_SECTOR
            self.write_sector(DIR_TRACK, bam_sec, sec)

    def init_directory(self, num_entries_needed):
        """Initialize directory chain with enough sectors."""
        num_sectors = max(1, math.ceil(num_entries_needed / 8))
        dir_sectors = []
        # First dir sector is always 40/3
        dir_sectors.append((40, DIR_START_SECTOR))
        for i in range(1, num_sectors):
            t, s = self.alloc_on_40()
            dir_sectors.append((t, s))
        # Write chain
        for i, (t, s) in enumerate(dir_sectors):
            sec = bytearray(256)
            if i < len(dir_sectors) - 1:
                nt, ns = dir_sectors[i + 1]
                sec[0x00] = nt
                sec[0x01] = ns
            else:
                sec[0x00] = 0x00
                sec[0x01] = 0xFF
            self.write_sector(t, s, sec)
        self.dir_sectors = dir_sectors

    def write_dir_entry(self, index, entry):
        """Write a 32-byte directory entry at the given index."""
        sec_idx = index // 8
        ent_idx = index % 8
        t, s = self.dir_sectors[sec_idx]
        off = self._off(t, s) + ent_idx * 32
        # Don't overwrite link bytes in first entry
        if ent_idx == 0:
            self.data[off + 2:off + 32] = entry[2:32]
        else:
            self.data[off:off + 32] = entry[:32]

    def save(self, path):
        with open(path, "wb") as f:
            f.write(self.data)


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


def write_seq_file(img, filename, content_bytes, dir_index):
    """Write a SEQ file to the image. Returns (first_t, first_s, num_sectors)."""
    sectors_needed = max(1, math.ceil(len(content_bytes) / DATA_PER_SECTOR))
    chain = []
    for _ in range(sectors_needed):
        chain.append(img.alloc())

    for i, (t, s) in enumerate(chain):
        sec = bytearray(256)
        chunk = content_bytes[i * DATA_PER_SECTOR:(i + 1) * DATA_PER_SECTOR]
        if i < len(chain) - 1:
            nt, ns = chain[i + 1]
            sec[0x00] = nt
            sec[0x01] = ns
        else:
            sec[0x00] = 0x00
            sec[0x01] = len(chunk) + 1  # bytes used in this sector (1-indexed)
        sec[2:2 + len(chunk)] = chunk
        img.write_sector(t, s, sec)

    entry = make_dir_entry(0x81, chain[0][0], chain[0][1], filename,
                           total_sectors=len(chain))
    img.write_dir_entry(dir_index, entry)
    return chain[0], len(chain)


def write_prg_file(img, filename, prg_bytes, dir_index):
    """Write a PRG file to the image."""
    sectors_needed = max(1, math.ceil(len(prg_bytes) / DATA_PER_SECTOR))
    chain = []
    for _ in range(sectors_needed):
        chain.append(img.alloc())

    for i, (t, s) in enumerate(chain):
        sec = bytearray(256)
        chunk = prg_bytes[i * DATA_PER_SECTOR:(i + 1) * DATA_PER_SECTOR]
        if i < len(chain) - 1:
            nt, ns = chain[i + 1]
            sec[0x00] = nt
            sec[0x01] = ns
        else:
            sec[0x00] = 0x00
            sec[0x01] = len(chunk) + 1
        sec[2:2 + len(chunk)] = chunk
        img.write_sector(t, s, sec)

    entry = make_dir_entry(0x82, chain[0][0], chain[0][1], filename,
                           total_sectors=len(chain))
    img.write_dir_entry(dir_index, entry)
    return chain[0], len(chain)


def write_rel_file(img, filename, records_data, record_size, dir_index):
    """Write a REL file with packed record data to the image.

    records_data: list of bytes objects, each exactly record_size bytes.
    Uses 1581-style super side sector.
    """
    num_records = len(records_data)

    # ── Build contiguous data stream ─────────────────────────
    stream = bytearray()
    for rec in records_data:
        stream.extend(rec)
    # Pad last sector with $00
    remainder = len(stream) % DATA_PER_SECTOR
    if remainder:
        stream.extend(b'\x00' * (DATA_PER_SECTOR - remainder))

    num_data_sectors = len(stream) // DATA_PER_SECTOR

    # ── Allocate and write data sectors ──────────────────────
    data_chain = []
    for _ in range(num_data_sectors):
        data_chain.append(img.alloc())

    for i, (t, s) in enumerate(data_chain):
        sec = bytearray(256)
        if i < len(data_chain) - 1:
            nt, ns = data_chain[i + 1]
            sec[0x00] = nt
            sec[0x01] = ns
        else:
            # Last sector: track=0, sector = bytes used + 1
            used = (num_records * record_size) % DATA_PER_SECTOR
            if used == 0:
                used = DATA_PER_SECTOR
            sec[0x00] = 0x00
            sec[0x01] = used + 1
        sec[2:] = stream[i * DATA_PER_SECTOR:(i + 1) * DATA_PER_SECTOR]
        img.write_sector(t, s, sec)

    # ── Build side sectors ───────────────────────────────────
    # Each side sector covers 120 data sectors
    # Each group has up to 6 side sectors (720 data sectors)
    groups = []
    ds_idx = 0
    while ds_idx < len(data_chain):
        group_data = data_chain[ds_idx:ds_idx + 720]
        ds_idx += len(group_data)
        ss_count = math.ceil(len(group_data) / 120)
        ss_ts = [img.alloc() for _ in range(ss_count)]
        groups.append((ss_ts, group_data))

    # Write side sectors
    global_ss_num = 0
    for g_idx, (ss_ts, group_data) in enumerate(groups):
        for ss_idx, (t, s) in enumerate(ss_ts):
            sec = bytearray(256)
            # Next side sector link
            if ss_idx < len(ss_ts) - 1:
                sec[0x00], sec[0x01] = ss_ts[ss_idx + 1]
            # Side sector block number
            sec[0x02] = global_ss_num
            sec[0x03] = record_size
            # Side sector group table ($04-$0F)
            for i in range(min(6, len(ss_ts))):
                sec[0x04 + i * 2] = ss_ts[i][0]
                sec[0x05 + i * 2] = ss_ts[i][1]
            # Data sector T/S pairs ($10-$FF)
            chunk = group_data[ss_idx * 120:(ss_idx + 1) * 120]
            for i, (dt, ds_) in enumerate(chunk):
                sec[0x10 + i * 2] = dt
                sec[0x11 + i * 2] = ds_
            img.write_sector(t, s, sec)
            global_ss_num += 1

    # ── Write super side sector ──────────────────────────────
    sss_t, sss_s = img.alloc()
    sec = bytearray(256)
    sec[0x00] = groups[0][0][0][0]  # group 0 first SS track
    sec[0x01] = groups[0][0][0][1]  # group 0 first SS sector
    sec[0x02] = 0xFE               # super side sector marker
    for i, (ss_ts, _) in enumerate(groups):
        if i < 126:
            sec[0x03 + i * 2] = ss_ts[0][0]
            sec[0x04 + i * 2] = ss_ts[0][1]
    img.write_sector(sss_t, sss_s, sec)

    # ── Directory entry ──────────────────────────────────────
    total_sectors = num_data_sectors + global_ss_num + 1  # data + side + super
    entry = make_dir_entry(0x84, data_chain[0][0], data_chain[0][1], filename,
                           side_t=sss_t, side_s=sss_s, rec_len=record_size,
                           total_sectors=num_data_sectors)  # size = data sectors only
    img.write_dir_entry(dir_index, entry)
    return num_data_sectors + global_ss_num + 1  # total sectors used


def main():
    parser = argparse.ArgumentParser(description="Import ADIF into D81 image")
    parser.add_argument("--adif", default="kg4olw.adi", help="ADIF file to import")
    parser.add_argument("--prg", default="c64_hamlog.prg", help="PRG file to put on disk")
    parser.add_argument("--output", default="hamlog.d81", help="Output D81 path")
    parser.add_argument("--skip-last", type=int, default=50,
                        help="Skip last N records (for sync testing)")
    parser.add_argument("--callsign", default="KG4OLW", help="Station callsign")
    parser.add_argument("--name", default="John Burns", help="Operator name")
    parser.add_argument("--grid", default="EL95tn", help="Grid square")
    parser.add_argument("--server", default="127.0.0.1", help="Server IP")
    parser.add_argument("--port", default="6400", help="Server port")
    parser.add_argument("--baud", default="1200", help="Baud rate")
    args = parser.parse_args()

    # ── Parse ADIF ───────────────────────────────────────────
    print(f"Reading {args.adif}...")
    with open(args.adif, encoding="latin-1") as f:
        text = f.read()
    all_records = parse_adif(text)
    print(f"  {len(all_records)} total records")

    import_count = len(all_records) - args.skip_last
    if import_count <= 0:
        print(f"Error: only {len(all_records)} records, can't skip {args.skip_last}")
        sys.exit(1)
    records_to_import = all_records[:import_count]
    print(f"  importing {import_count}, skipping last {args.skip_last}")

    # ── Pack records ─────────────────────────────────────────
    print("Packing records...")
    packed_full = []
    packed_sum = []
    for rec in records_to_import:
        packed_full.append(pack_record(rec))
        packed_sum.append(pack_summary(rec))

    last_logid = records_to_import[-1].get("app_qrzlog_logid", "0")

    # ── Build D81 image ──────────────────────────────────────
    print("Building D81 image...")
    img = D81Image()
    img.write_header("HAMLOG", "HL")
    # We need 5 directory entries: PRG, SUM(REL), DAT(REL), IDX, CFG
    img.init_directory(num_entries_needed=5)

    dir_idx = 0

    # ── Write PRG ────────────────────────────────────────────
    if os.path.exists(args.prg):
        print(f"  writing {args.prg}...")
        with open(args.prg, "rb") as f:
            prg_data = f.read()
        write_prg_file(img, "HAMLOG", prg_data, dir_idx)
        dir_idx += 1
    else:
        print(f"  warning: {args.prg} not found, skipping PRG")

    # ── Write REL (HAMLOG.SUM) — summary for fast log screen ─
    print(f"  writing {import_count} summaries to HAMLOG.SUM...")
    sum_sectors = write_rel_file(img, "HAMLOG.SUM", packed_sum, SUMMARY_SIZE, dir_idx)
    dir_idx += 1
    print(f"    {sum_sectors} sectors used")

    # ── Write REL (HAMLOG.DAT) — full detail records ────────
    print(f"  writing {import_count} records to HAMLOG.DAT...")
    rel_sectors = write_rel_file(img, "HAMLOG.DAT", packed_full, RECORD_SIZE, dir_idx)
    dir_idx += 1
    print(f"    {rel_sectors} sectors used")

    # ── Write IDX (HAMLOG.IDX) ───────────────────────────────
    idx_content = f"{import_count}\r{last_logid}\r".encode("ascii")
    write_seq_file(img, "HAMLOG.IDX", idx_content, dir_idx)
    dir_idx += 1
    print(f"  wrote HAMLOG.IDX (rc={import_count}, logid={last_logid})")

    # ── Write CFG (HAMLOG.CFG) ───────────────────────────────
    # Uppercase for PETSCII compatibility on C64 screen
    cfg_content = (
        f"{args.server}\r{args.port}\r{args.callsign.upper()}\r"
        f"{args.baud}\r{args.name.upper()}\r{args.grid.upper()}\r"
    ).encode("ascii")
    write_seq_file(img, "HAMLOG.CFG", cfg_content, dir_idx)
    dir_idx += 1
    print(f"  wrote HAMLOG.CFG")

    # ── Write BAM (must be last, after all allocations) ──────
    img.write_bam("HL")

    # ── Save ─────────────────────────────────────────────────
    img.save(args.output)
    free_sectors = sum(len(s) for s in img.free.values())
    print(f"\nDone! {args.output} created.")
    print(f"  {import_count} QSOs imported, {args.skip_last} skipped for sync testing")
    print(f"  {free_sectors} sectors free ({free_sectors * 254 // 1024}KB)")


if __name__ == "__main__":
    main()

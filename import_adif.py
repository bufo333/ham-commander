#!/usr/bin/env python3
"""Import ADIF records into Commodore disk image(s).

Creates D81 or D64 disk image(s) with:
  - HAMLOG     (PRG) — the C64 program
  - HAMLOG.SUM (REL) — summary records (40 bytes each)
  - HAMLOG.DAT (REL) — full detail records (168 bytes each)
  - HAMLOG.IDX (SEQ) — record count + last logid
  - HAMLOG.CFG (SEQ) — station config

For large logs (>3500 on D81, >700 on D64), automatically splits across
multiple disk images: hamlog-01.d81, hamlog-02.d81, etc.

Usage:
  python3 import_adif.py --adif mylog.adi              # import ADIF into D81
  python3 import_adif.py --adif mylog.adi             # custom ADIF file
  python3 import_adif.py --format d64                 # create D64 instead
  python3 import_adif.py --skip-last 0                # import all records
  python3 import_adif.py --adif huge.adi              # auto multi-disk if >3500
"""

import argparse
import os
import sys

from diskimage import (
    MAX_RECORDS, RECORD_SIZE, SUMMARY_SIZE,
    parse_adif, pack_record, pack_summary,
    build_prg, build_disk,
)


def main():
    parser = argparse.ArgumentParser(description="Import ADIF into disk image(s)")
    parser.add_argument("--adif", required=True, help="ADIF file to import")
    parser.add_argument("--format", choices=["d81", "d64"], default="d81",
                        help="Disk format (default: d81)")
    parser.add_argument("--prg", default="c64_hamlog.prg", help="PRG file to put on disk")
    parser.add_argument("--bas", default="c64_hamlog.bas", help="BASIC source (builds PRG if needed)")
    parser.add_argument("--output", default="hamlog", help="Output base name (without extension)")
    parser.add_argument("--skip-last", type=int, default=50,
                        help="Skip last N records (for sync testing)")
    parser.add_argument("--callsign", default="N0CALL", help="Station callsign")
    parser.add_argument("--name", default="", help="Operator name")
    parser.add_argument("--grid", default="", help="Grid square")
    parser.add_argument("--server", default="127.0.0.1", help="Server IP")
    parser.add_argument("--port", default="6400", help="Server port")
    parser.add_argument("--baud", default="1200", help="Baud rate")
    args = parser.parse_args()

    fmt = args.format
    max_rec = MAX_RECORDS[fmt]

    # ── Build PRG ─────────────────────────────────────────────
    if os.path.exists(args.prg):
        print(f"Using existing PRG: {args.prg}")
        with open(args.prg, "rb") as f:
            prg_bytes = f.read()
    elif os.path.exists(args.bas):
        print(f"Building PRG from {args.bas}...")
        prg_bytes = build_prg(args.bas, args.prg)
        print(f"  {len(prg_bytes)} bytes")
    else:
        print(f"Error: neither {args.prg} nor {args.bas} found")
        sys.exit(1)

    # ── Parse ADIF ────────────────────────────────────────────
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

    # ── Pack records ──────────────────────────────────────────
    print("Packing records...")
    packed_full = []
    packed_sum = []
    for rec in records_to_import:
        packed_full.append(pack_record(rec))
        packed_sum.append(pack_summary(rec))

    # ── Config (shared across disks) ──────────────────────────
    cfg_content = (
        f"{args.server}\r{args.port}\r{args.callsign.upper()}\r"
        f"{args.baud}\r{args.name.upper()}\r{args.grid.upper()}\r"
    ).encode("ascii")

    # ── Split into disk-sized chunks ──────────────────────────
    num_disks = max(1, (import_count + max_rec - 1) // max_rec)
    multi = num_disks > 1

    if multi:
        print(f"  {import_count} records require {num_disks} {fmt.upper()} disks")

    for disk_num in range(num_disks):
        start = disk_num * max_rec
        end = min(start + max_rec, import_count)
        disk_count = end - start

        disk_sum = list(packed_sum[start:end])
        disk_full = list(packed_full[start:end])

        # Last logid for this disk's records
        last_logid = records_to_import[end - 1].get("app_qrzlog_logid", "0")

        # Pad to max_records
        pad = max_rec - disk_count
        disk_sum.extend([b'\x00' * SUMMARY_SIZE] * pad)
        disk_full.extend([b'\x00' * RECORD_SIZE] * pad)

        # Output filename
        if multi:
            output_path = f"{args.output}-{disk_num + 1:02d}.{fmt}"
        else:
            output_path = f"{args.output}.{fmt}"

        print(f"Building {output_path}...")
        print(f"  records {start + 1}-{end} ({disk_count} QSOs, {pad} padding)")

        free, sum_sec, dat_sec = build_disk(
            fmt, prg_bytes, disk_sum, disk_full,
            import_count=disk_count, max_records=max_rec,
            last_logid=last_logid, cfg_content=cfg_content,
            output_path=output_path, disk_number=disk_num + 1,
        )

        print(f"  SUM: {sum_sec} sectors, DAT: {dat_sec} sectors")
        print(f"  {free} sectors free ({free * 254 // 1024}KB)")

    # ── Summary ───────────────────────────────────────────────
    print()
    if multi:
        print(f"Done! {num_disks} disk images created.")
        for i in range(num_disks):
            s = i * max_rec
            e = min(s + max_rec, import_count)
            name = f"{args.output}-{i + 1:02d}.{fmt}"
            print(f"  {name}: records {s + 1}-{e}")
    else:
        print(f"Done! {args.output}.{fmt} created.")
        print(f"  {import_count} QSOs imported, {args.skip_last} skipped for sync testing")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Create a Ham Commander disk image with the program and empty log files.

Usage:
  python3 create_disk.py                       # D81 with PRG + empty REL files
  python3 create_disk.py --format d64          # D64 with PRG + empty REL files
  python3 create_disk.py --prg-only            # Just build the PRG file, no disk
  python3 create_disk.py --output mylog.d81    # Custom output filename

The PRG is built automatically from c64_hamlog.bas using bas_lower.py + petcat.
"""

import argparse
import sys

from diskimage import (
    MAX_RECORDS, RECORD_SIZE, SUMMARY_SIZE,
    build_prg, build_disk,
)


def main():
    parser = argparse.ArgumentParser(
        description="Create a Ham Commander disk image (blank or PRG-only)"
    )
    parser.add_argument("--format", choices=["d81", "d64"], default="d81",
                        help="Disk format (default: d81)")
    parser.add_argument("--output", default=None,
                        help="Output filename (default: hamlog.d81 or hamlog.d64)")
    parser.add_argument("--bas", default="c64_hamlog.bas",
                        help="BASIC source file")
    parser.add_argument("--prg", default="c64_hamlog.prg",
                        help="PRG output filename")
    parser.add_argument("--prg-only", action="store_true",
                        help="Only build the PRG file, don't create a disk image")
    parser.add_argument("--max-records", type=int, default=None,
                        help="Max records to pre-allocate (default: auto by format)")
    parser.add_argument("--callsign", default="N0CALL", help="Station callsign")
    parser.add_argument("--name", default="", help="Operator name")
    parser.add_argument("--grid", default="", help="Grid square")
    parser.add_argument("--server", default="127.0.0.1", help="Server IP")
    parser.add_argument("--port", default="6400", help="Server port")
    parser.add_argument("--baud", default="1200", help="Baud rate")
    parser.add_argument("--disk-number", type=int, default=1, help="Disk sequence number")
    args = parser.parse_args()

    # ── Build PRG ─────────────────────────────────────────────
    print(f"Building PRG from {args.bas}...")
    prg_bytes = build_prg(args.bas, args.prg)
    print(f"  {len(prg_bytes)} bytes -> {args.prg}")

    if args.prg_only:
        print("Done! PRG file created.")
        return

    # ── Create disk image ─────────────────────────────────────
    fmt = args.format
    output = args.output or f"hamlog.{fmt}"
    max_rec = args.max_records or MAX_RECORDS[fmt]

    print(f"Creating {fmt.upper()} disk image...")
    print(f"  pre-allocating {max_rec} empty records")

    # Empty records
    packed_sum = [b'\x00' * SUMMARY_SIZE for _ in range(max_rec)]
    packed_full = [b'\x00' * RECORD_SIZE for _ in range(max_rec)]

    # Config
    cfg_content = (
        f"{args.server}\r{args.port}\r{args.callsign.upper()}\r"
        f"{args.baud}\r{args.name.upper()}\r{args.grid.upper()}\r"
    ).encode("ascii")

    free, sum_sec, dat_sec = build_disk(
        fmt, prg_bytes, packed_sum, packed_full,
        import_count=0, max_records=max_rec,
        last_logid="0", cfg_content=cfg_content,
        output_path=output, disk_number=args.disk_number,
    )

    print(f"\nDone! {output} created.")
    print(f"  {max_rec} empty record slots pre-allocated")
    print(f"  {free} sectors free ({free * 254 // 1024}KB)")


if __name__ == "__main__":
    main()

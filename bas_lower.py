#!/usr/bin/env python3
"""Convert C64 BASIC source to lowercase while preserving string literals.

petcat requires BASIC keywords in lowercase, but string literals must
keep their original case because the C64 compares strings using PETSCII
values (uppercase ASCII 0x41-0x5A matches PETSCII uppercase).

Usage: python3 bas_lower.py < input.bas > output.bas
"""

import sys

for line in sys.stdin:
    result = []
    in_string = False
    for ch in line:
        if ch == '"':
            in_string = not in_string
            result.append(ch)
        elif in_string:
            result.append(ch)  # preserve case inside strings
        else:
            result.append(ch.lower())
    sys.stdout.write("".join(result))

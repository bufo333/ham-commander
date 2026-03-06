# CBM Disk Format & REL File Technical Reference

How Ham Commander's `import_adif.py` builds D81 disk images with REL (relative) files from scratch in Python — no Commodore DOS required.

## D81 Disk Geometry (1581 Drive)

| Property | Value |
|---|---|
| Tracks | 80 (numbered 1–80) |
| Sectors per track | 40 (numbered 0–39) |
| Sector size | 256 bytes |
| Usable data per sector | 254 bytes (first 2 bytes = chain link) |
| Total sectors | 3,200 |
| System track | Track 40 (header, BAM, directory) |
| Available for files | ~3,160 sectors (~784 KB) |

### D64 Comparison (1541 Drive)

| Property | Value |
|---|---|
| Tracks | 35 (numbered 1–35) |
| Sectors per track | 17–21 (varies by zone) |
| Total sectors | 683 |
| System track | Track 18 |
| Available for files | ~664 sectors (~164 KB) |
| Max QSOs at 168 bytes | ~810 |

The D81 holds roughly 4x more data. At 168 bytes per QSO record, a D81 fits ~3,500 QSOs vs ~810 on a D64.

## Sector Chain Links

Every sector on a CBM disk starts with a 2-byte forward link:

```
Byte 0: Next track  (0 = this is the last sector in the chain)
Byte 1: Next sector (if track=0: position of last valid byte, 1-indexed)
```

Files are stored as linked lists of sectors. To read a file, follow the chain from the first sector (stored in the directory entry) until track = 0.

```
Sector N:  [next_track] [next_sector] [254 bytes of data...]
Sector N+1: [next_track] [next_sector] [254 bytes of data...]
Last sector: [0x00] [bytes_used+1] [data...] [unused padding...]
```

## Track 40 — System Track

Track 40 contains four reserved sectors:

### Sector 0 — Disk Header

```
$00-$01: Track/sector of first directory sector (40/3)
$02:     DOS version ('D' = 0x44 for 1581)
$04-$13: Disk name (16 bytes, padded with 0xA0)
$16-$17: Disk ID (2 bytes)
$19-$1A: DOS type ("3D" for 1581)
```

### Sectors 1–2 — Block Allocation Map (BAM)

Two BAM sectors cover tracks 1–40 and 41–80 respectively.

```
$00-$01: Chain link (BAM1 → BAM2, BAM2 → 00/FF)
$02:     DOS version (0x44)
$04-$05: Disk ID
$10+:    6 bytes per track: [free_count] [5-byte bitmap]
```

Each bit in the bitmap represents one sector: 1 = free, 0 = allocated. 40 sectors need 5 bytes (40 bits).

The BAM must be written **last**, after all sectors are allocated, so the free/used counts are accurate.

### Sector 3+ — Directory

Each directory sector holds 8 file entries of 32 bytes each:

```
$00-$01: Chain link to next directory sector
$02:     File type (0x81=SEQ, 0x82=PRG, 0x84=REL)
$03-$04: First data track/sector
$05-$14: Filename (16 bytes, padded with 0xA0)
$15-$16: Side sector track/sector (REL files only)
$17:     Record length (REL files only)
$1E-$1F: File size in sectors (16-bit little-endian)
```

## File Types

### SEQ (Sequential) — Type 0x81

Simple chain of sectors read front to back. Used for HAMLOG.IDX and HAMLOG.CFG.

### PRG (Program) — Type 0x82

Same structure as SEQ but first 2 bytes of file data are the load address (little-endian). The C64 BASIC program lives here.

### REL (Relative) — Type 0x84

Random-access record files. This is the complex one — and the whole reason this document exists.

## REL File Architecture

A REL file has three layers:

```
┌─────────────────────────────────────────────────┐
│  Super Side Sector (1 sector)                   │
│  Points to first side sector of each group      │
├────────────────┬────────────────┬───────────────-┤
│  Side Sector   │  Side Sector   │  Side Sector   │
│  Group 0       │  Group 0       │  Group 1       │
│  SS #0         │  SS #1         │  SS #2         │
│  120 pointers  │  120 pointers  │  120 pointers  │
├────────────────┴────────────────┴────────────────┤
│  Data Sectors (linked chain)                     │
│  Records packed contiguously, spanning sectors   │
└──────────────────────────────────────────────────┘
```

### Data Sectors

Records are packed into a contiguous byte stream across sectors. A record can start in one sector and end in the next — there's no alignment to sector boundaries. The C64 DOS handles the math.

```
Record size: 168 bytes (HAMLOG.DAT) or 40 bytes (HAMLOG.SUM)
Bytes per sector: 254
Records per sector: not an integer — records span sectors freely
```

For example, with 40-byte records in a 254-byte sector:
- Records 1–6 fit entirely (6 × 40 = 240 bytes, 14 bytes left)
- Record 7 starts at byte 240, spans into the next sector (26 bytes there)

The C64 `POSITION` command calculates which sector(s) to read for any given record number using: `sector_index = (record_number - 1) * record_size / 254`.

### Side Sectors — The Index

Side sectors are the REL file's index. Each one maps up to **120 data sectors** by storing their track/sector pairs:

```
Byte $00-$01: Link to next side sector
              If last: $00 = track 0, $01 = offset of last valid pointer byte
Byte $02:     Side sector number (0-based, sequential across all groups)
Byte $03:     Record length
Byte $04-$0F: Group table — T/S of all side sectors in this group (up to 6 pairs)
Byte $10-$FF: Data sector T/S pairs (up to 120 entries × 2 bytes = 240 bytes)
```

**Critical: Last side sector byte 1 format**

When byte 0 = 0 (end of chain), byte 1 must be the offset of the last valid data pointer byte:

```
byte_1 = 0x10 + (num_entries × 2) - 1
```

For a side sector with 44 data entries: `byte_1 = 0x10 + 88 - 1 = 0x67`

Setting byte 1 to 0 causes the CBM DOS to compute a nonsensical record count (arithmetic underflow), resulting in the drive hanging while seeking invalid sectors.

**Side sector number (byte 2) must be per-group, not global.** The numbering restarts at 0 for each group of 6. If side sector #6 (the first in group 1) has byte 2 = 6 instead of 0, the 1581 DOS fails to match it and can't open the file. This only manifests when a REL file spans more than 720 data sectors (multiple groups).

### Side Sector Groups

Each group contains up to **6 side sectors** (720 data sectors). When a file exceeds 720 data sectors, a new group starts. The group table (bytes $04–$0F) in each side sector lists all side sectors belonging to its group.

### Super Side Sector — 1581 Extension

The 1581 added the super side sector to support files larger than 720 sectors (the 1541's limit). It sits above the side sectors:

```
Byte $00-$01: T/S of first side sector (group 0, SS #0)
              The 1581 ROM follows this link to navigate into the side sector chain.
              NOT an end-of-chain marker — this is a forward pointer.
Byte $02:     0xFE (super side sector marker)
Byte $03-$04: T/S of first side sector of group 0 (same as bytes 0-1)
Byte $05-$06: T/S of first side sector of group 1
...continuing for each group...
              Up to 126 groups × 720 sectors = 90,720 sectors theoretical max
```

**Critical: Bytes 0-1 must point to the first side sector.** The 1581 ROM routine at $A574 loads the SSS, then reads bytes 0-1 as a forward link to enter the side sector chain. Setting these to (0x00, 0xFE) — as some documentation suggests — causes the ROM to treat it as an end-of-chain marker and fail to navigate to any side sectors. The VICE source (`vdrive-rel.c`) confirms: `p->super_side_sector[0] = first_ss_track; p->super_side_sector[1] = first_ss_sector;`

The directory entry's "side track/sector" field points to the super side sector (not the first side sector directly, as on the 1541).

## How import_adif.py Builds a D81

### Step 1: Initialize Blank Image

```python
img = D81Image()  # 80 tracks × 40 sectors × 256 bytes = 819,200 bytes of zeros
```

All 3,200 sectors start free. Track 40 sectors 0–3 are reserved for system use.

### Step 2: Write Header and Directory

The header at T40/S0 stores the disk name and ID. Directory sectors are pre-allocated on track 40 (enough for 5 file entries = 1 sector).

### Step 3: Write PRG File

The compiled BASIC program (c64_hamlog.prg) is written as a chain of sectors starting from track 1. Each sector links to the next. The last sector's byte 1 indicates how many bytes are used.

### Step 4: Pack QSO Records

Each ADIF record is packed into two formats:

**HAMLOG.SUM** (40 bytes) — fast summary for the log screen:
```
call(10) + band(4) + mode(4) + date(8) + time(4) + rsts(3) + rstr(3) + flag(1) + pad(2) + CR
```

**HAMLOG.DAT** (168 bytes) — full detail, two-half format:
```
Half 1 (83 + CR): call(12)+band(6)+mode(6)+date(8)+time(4)+freq(10)+rsts(3)+rstr(3)+stn(12)+logid(12)+flag(1)+cmt(6)
Half 2 (83 + CR): cmt(34)+grid(6)+name(30)+country(13)
```

The two-half format exists because the C64's `INPUT#` reads until a CR delimiter. A single 168-byte string would overflow the INPUT# buffer.

### Step 5: Pre-allocate to Maximum Capacity

After packing the imported records, empty (zero-filled) padding records are appended to bring the total up to ~3,500 records — the maximum a D81 can hold. This avoids the C64 DOS needing to extend the REL file when new QSOs are added, which is slow and can fail if the disk is fragmented.

```python
pad_count = 3500 - import_count
for _ in range(pad_count):
    packed_sum.append(b'\x00' * 40)
    packed_full.append(b'\x00' * 168)
```

### Step 6: Write REL Files

For each REL file (SUM and DAT):

1. **Build data stream**: Concatenate all packed records into one contiguous byte array. Pad the end to fill the last sector.

2. **Allocate and write data sectors**: Sectors are allocated sequentially (track 1 upward, skipping track 40). Each sector links to the next. The last sector's byte 1 = bytes used + 1.

3. **Build side sectors**: For every 120 data sectors, allocate one side sector. Store the T/S of each data sector at offsets $10–$FF. Group side sectors into sets of 6. The last side sector's byte 1 = `0x10 + entries × 2 - 1`.

4. **Build super side sector**: Allocate one sector. Byte 2 = 0xFE (marker). Store the T/S of the first side sector of each group starting at byte 3.

5. **Write directory entry**: File type 0x84, first data T/S, super side sector T/S, record length, sector count.

### Step 7: Write SEQ Files

HAMLOG.IDX stores the record count and last QRZ log ID. HAMLOG.CFG stores station configuration. Both are simple sector chains.

### Step 8: Write BAM

The BAM is written last. For each track, count remaining free sectors and build the 5-byte allocation bitmap. This ensures the BAM accurately reflects all allocations made in steps 3–7.

### Step 9: Save

Write the 819,200-byte array to disk as a .d81 file. The image can be loaded directly by VICE, mounted on an SD2IEC, or written to a real 3.5" disk for use in a 1581 drive.

## Capacity Planning

| Records | SUM Sectors | DAT Sectors | Side Sectors | Total + PRG | Fits D81? |
|---------|------------|------------|-------------|-------------|-----------|
| 500 | 79 | 331 | 6 | 500 | Yes |
| 1,000 | 158 | 662 | 9 | 911 | Yes |
| 2,000 | 315 | 1,323 | 16 | 1,736 | Yes |
| 3,500 | 552 | 2,315 | 28 | 2,977 | Yes (~180 free) |
| 4,000 | 630 | 2,646 | 31 | 3,389 | No (exceeds ~3,160) |

The practical limit is ~3,500 QSOs per D81 disk. Beyond that, the archive disk feature allows spanning across multiple disk images.

## How the C64 Reads REL Files

The C64 BASIC program uses the `POSITION` command to random-access records:

```basic
RN = 274                              : REM record number (1-based)
LO = RN AND 255 : HI = INT(RN/256)   : REM split into low/high bytes
PRINT#15,"P"+CHR$(3)+CHR$(LO)+CHR$(HI)+CHR$(1)  : REM position channel 3
INPUT#3,A$                            : REM read half 1 (83 bytes + CR)
PRINT#15,"P"+CHR$(3)+CHR$(LO)+CHR$(HI)+CHR$(85) : REM position to byte 85
INPUT#3,B$                            : REM read half 2 (83 bytes + CR)
W$ = A$ + B$                          : REM full 166-char record string
```

The `P` command tells the drive's DOS to seek to a specific record and byte offset within that record. The DOS uses the side sector index to find which data sector contains that position, reads it (and the next sector if the record spans a boundary), and returns the data.

### POSITION Command Byte Format

```
P  channel  lo_byte  hi_byte  byte_offset
```

The record number is encoded as: `record = hi_byte * 256 + lo_byte` (1-based).

**Critical gotcha: Do NOT add +1 to hi_byte.** Some code examples add +1 to avoid sending CHR$(0) as the high byte (since CHR$(0) can be problematic in PRINT# strings). However, the 1581 DOS uses the bytes exactly as received — it does NOT subtract 1. Adding +1 to hi_byte offsets every record access by 256 positions. For record 274:

```
WRONG:  LO = 274 AND 255 = 18,  HI = INT(274/256) + 1 = 2  → record = 2*256 + 18 = 530
RIGHT:  LO = 274 AND 255 = 18,  HI = INT(274/256) = 1      → record = 1*256 + 18 = 274
```

This bug is insidious because it only manifests when accessing records above ~254 (where HI > 0), and the symptom is the drive hanging while seeking into unallocated side sectors — not an obvious "wrong record" error.

For records 1–255, HI=0 works fine since `CHR$(0)` is sent as a null byte and the drive interprets it correctly. The concern about CHR$(0) being stripped is unfounded when using the `PRINT#15,"P"+CHR$(...)` idiom — the string concatenation preserves null bytes.

### How the 1581 ROM Processes POSITION

The 1581 ROM uses a multi-step process to locate a record (analyzed from ROM disassembly):

1. **$8D06 — Division routine**: Computes `sector_index = (record - 1) * record_size / 254` to find which data sector contains the start of the record.

2. **$8D06 again**: Computes `ss_index = sector_index / 120` to find which side sector holds the pointer, and `entry_index = sector_index MOD 120` for the offset within that side sector.

3. **$8D06 again**: Computes `group = ss_index / 6` and `ss_within_group = ss_index MOD 6` to locate the correct side sector group.

4. **$A574 — Load SSS**: Reads the super side sector from disk (T/S from directory entry). Follows bytes 0-1 as a forward link into the side sector chain.

5. **$A5A9 — Find group**: Uses `group` to index into the SSS group table (byte $03+) and find the first side sector of that group.

6. **$A5D2 — Navigate SS chain**: Follows the side sector chain `ss_within_group` times to reach the target side sector.

7. **$9EF9 — Read data sector pointer**: Reads the T/S pair at offset `$10 + entry_index * 2` in the side sector to find the actual data sector.

8. **Read data**: Seeks to the byte offset within the data sector where the record begins. If the record spans a sector boundary, reads the next sector in the chain too.

## Pitfalls and Lessons Learned

### Building REL Files Without Commodore DOS

When constructing REL files in Python (or any external tool) for use on real 1581 hardware or VICE TDE mode, every byte must be exactly right. The 1581 ROM has no error recovery — a single wrong byte in the side sector chain causes the drive CPU to loop forever seeking phantom sectors.

Key correctness requirements:
1. **SSS bytes 0-1**: Must be T/S of first side sector (not 0x00/0xFE)
2. **Side sector byte 2**: Must restart at 0 for each group (not global sequential numbering)
3. **Last side sector byte 1**: Must be `0x10 + entries*2 - 1` (not 0 or 0xFF)
4. **Data sector chain**: Must be a properly terminated linked list (last sector: track=0, sector=bytes_used+1)
5. **BAM**: Must accurately reflect all allocated sectors (write BAM last)

### VICE TDE vs Virtual Drive

VICE has two drive emulation modes:
- **TDE on** (`-drive8truedrive`): Full 1581 ROM emulation. Exercises the real ROM code paths. Required for testing REL file correctness.
- **TDE off** (`+drive8truedrive`): VICE's virtual drive (`vdrive-rel.c`). More forgiving — may accept slightly malformed disk images that the real ROM rejects.

**VICE saves drive settings persistently.** After using `+drive8truedrive` once, subsequent launches keep TDE off even without the flag. Always use `-drive8truedrive` explicitly when testing disk-intensive code.

## References

- [Inside Commodore DOS](https://www.pagetable.com/docs/Inside%20Commodore%20DOS.pdf) — Richard Immers & Gerald Neufeld
- [1581 User's Guide](https://www.commodore.ca/manuals/pdfs/1581_Disk_Drive_Users_Guide.pdf)
- VICE source: `vdrive-rel.c` — virtual drive REL file implementation
- Commodore 1581 ROM disassembly

- [Inside Commodore DOS](https://www.pagetable.com/docs/Inside%20Commodore%20DOS.pdf) — Richard Immers & Gerald Neufeld
- [1581 User's Guide](https://www.commodore.ca/manuals/pdfs/1581_Disk_Drive_Users_Guide.pdf)
- VICE source: `vdrive-rel.c` — virtual drive REL file implementation
- Commodore 1581 ROM disassembly

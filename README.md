# Ham Commander v2.0

A Commodore 64 ham radio logging application with local disk storage and optional online features via an RS232 modem connection.

```
┌──────────────────────┐     RS232      ┌───────────────┐     TCP      ┌──────────┐
│  Commodore 64        │◄──(1200 baud)──│  PTY Bridge   │◄────────────►│  Server  │
│  c64_hamlog.bas      │   /tmp/c64modem│  pty_bridge.py │              │ server.py│
│                      │                └───────────────┘              └────┬─────┘
│  1541/1581/SD2IEC    │                                                   │
│  HAMLOG.DAT (REL)    │                                          ┌────────┴────────┐
│  HAMLOG.SUM (REL)    │                                          │  QRZ.com API    │
│  HAMLOG.IDX (SEQ)    │                                          │  POTA Spots API │
│  HAMLOG.CFG (SEQ)    │                                          └─────────────────┘
└──────────────────────┘
```

## Features

- **Local logging** — Log QSOs directly on the C64 with full REL file storage on 1541 (D64) or 1581/SD2IEC (D81) drives
- **QRZ callsign lookups** — Look up name, location, and grid square via RS232 modem
- **POTA spots** — View Parks on the Air activations with band/mode filtering
- **QRZ sync** — Incremental sync of your QRZ logbook to the C64
- **Reverse-chronological log** — Newest QSOs shown first, with paged browsing
- **Multi-disk support** — Import tool automatically splits large logs across multiple disk images

## Prerequisites

- **Python 3.10+** with pip
- **VICE emulator** (provides `petcat`, `c1541`, and `x64sc`)
  ```bash
  brew install vice        # macOS
  apt install vice         # Debian/Ubuntu
  ```
- **Python packages**:
  ```bash
  pip install -r requirements.txt
  ```

## Quick Start

There are three ways to get started, depending on your situation:

### Path 1: Fresh Start (No Existing Log)

Create a blank disk image with the program and empty pre-allocated log files:

```bash
# D81 disk (1581/SD2IEC — holds up to 3,500 QSOs)
python3 create_disk.py --callsign YOURCALL --name "Your Name" --grid AB12cd

# D64 disk (1541 — holds up to 700 QSOs)
python3 create_disk.py --format d64 --callsign YOURCALL --name "Your Name" --grid AB12cd
```

This builds the PRG automatically from `c64_hamlog.bas` and creates a ready-to-use disk image with pre-allocated REL files. No Commodore DOS extension needed — just load and go.

### Path 2: Import from ADIF (QRZ Export, etc.)

If you have an ADIF log file (exported from QRZ, LOTW, or another logger):

```bash
# Import into a D81 (auto-splits if >3,500 QSOs)
python3 import_adif.py --adif yourlog.adi --callsign YOURCALL --name "Your Name" --grid AB12cd

# Import into D64 disks (auto-splits if >700 QSOs)
python3 import_adif.py --adif yourlog.adi --format d64 --callsign YOURCALL

# Skip the last N records (useful for testing sync)
python3 import_adif.py --adif yourlog.adi --skip-last 50
```

For large logs, the tool automatically creates numbered disk images:
```
hamlog-01.d81  (records 1-3500)
hamlog-02.d81  (records 3501-7000)
hamlog-03.d81  (records 7001-8200)
```

Each disk is self-contained with the program, data, config, and index.

### Path 3: PRG Only (For Existing Disks)

If you already have a disk image and just want the compiled program:

```bash
python3 create_disk.py --prg-only
```

This produces `c64_hamlog.prg` which you can copy to any disk using c1541:

```bash
# Copy PRG to an existing D81
c1541 -attach yourdisk.d81 -write c64_hamlog.prg "hamlog"

# Copy PRG to an existing D64
c1541 -attach yourdisk.d64 -write c64_hamlog.prg "hamlog"
```

Note: The disk must already have HAMLOG.DAT, HAMLOG.SUM, HAMLOG.IDX, and HAMLOG.CFG files. Use the setup wizard (first run) to create config, or copy these from a disk created by `create_disk.py`.

## Running in VICE Emulator

### Offline Mode (No Server)

```bash
# D81 disk
GSETTINGS_SCHEMA_DIR=/opt/homebrew/share/glib-2.0/schemas x64sc \
  -drive8truedrive -autostart hamlog.d81 -autostartprgmode 1

# D64 disk
GSETTINGS_SCHEMA_DIR=/opt/homebrew/share/glib-2.0/schemas x64sc \
  -drive8truedrive -autostart hamlog.d64 -autostartprgmode 1
```

The `-drive8truedrive` flag enables true drive emulation (TDE), which is required for REL file support. VICE saves this setting persistently — if you previously disabled TDE, you must re-enable it explicitly.

### Online Mode (With Server)

Start three terminals:

**Terminal 1 — Server:**
```bash
python3 -u server.py
```

**Terminal 2 — PTY Bridge:**
```bash
python3 -u pty_bridge.py
```

**Terminal 3 — VICE:**
```bash
GSETTINGS_SCHEMA_DIR=/opt/homebrew/share/glib-2.0/schemas x64sc \
  -rsdev1 "/tmp/c64modem" +rsdev1ip232 -rsdev1baud 1200 \
  -userportdevice 2 -rsuserdev 0 -rsuserbaud 1200 +acia1 \
  -drive8truedrive -autostart hamlog.d81 -autostartprgmode 1
```

## Running on Real Hardware

### SD2IEC

Copy the `.d81` file to your SD card. Mount it on the SD2IEC and load:

```
LOAD "HAMLOG",8,1
RUN
```

### 1581 Drive

Write the `.d81` to a 3.5" disk using an appropriate transfer tool, or use an SD2IEC in D81 mode.

### 1541 Drive

Use a D64 disk image. The 1541 supports REL files natively (no super side sector needed). Transfer the `.d64` to a 5.25" disk.

## Server Configuration

The server requires a `.env` file for QRZ API access:

```bash
cp .env.example .env
# Edit .env with your QRZ credentials:
#   QRZ_USER=yourcall
#   QRZ_PASS=yourpassword
#   QRZ_API_KEY=your_api_key  (for logbook access)
```

The server listens on port 6400 by default and provides:
- `HELLO` — Connection handshake
- `LOOKUP,callsign` — QRZ callsign lookup
- `SPOTS[,band][,mode]` — POTA spot feed (filtered, max 20)
- `SYNC,last_logid` — Incremental logbook sync from QRZ
- `ADD,call,band,mode,...` — Upload QSO to QRZ logbook

## C64 Usage

### F-Key Controls

| Key | Function |
|-----|----------|
| F1 | POTA Spots (with band/mode filter when online) |
| F3 | Log Browser (newest first) |
| F4 | Configuration Editor |
| F5 | New QSO Entry |
| F6 | Sync with QRZ (when online) |
| F7 | Go Online / Offline |

### Log Browser

- **Cursor Up/Down** — Move selection
- **Enter** — View QSO detail
- **D** — Delete QSO (from detail view)
- Records are displayed newest-first

### Screen Layout

```
Row 0:  Title bar (reverse video)
Row 1:  Status line
Rows 2-20: Data area (19 rows)
Row 21: Separator
Row 22: Help text
Row 24: F-key bar
```

## Disk Capacity

| Format | Drive | Max QSOs | Disk Images for 10K QSOs |
|--------|-------|----------|--------------------------|
| D81 | 1581 / SD2IEC | 3,500 | 3 disks |
| D64 | 1541 | 700 | 15 disks |

Each disk image is self-contained — program, data, config, and index are all included. Multi-disk import numbers them sequentially (`hamlog-01.d81`, `hamlog-02.d81`, etc.).

## File Reference

| File | Description |
|------|-------------|
| `c64_hamlog.bas` | C64 BASIC source code |
| `bas_lower.py` | Lowercases BASIC keywords (preserves string literals) |
| `diskimage.py` | Shared D81/D64 disk image builder library |
| `create_disk.py` | Creates blank disk images with PRG + empty REL files |
| `import_adif.py` | Imports ADIF logs into disk images (multi-disk capable) |
| `server.py` | Asyncio TCP server (QRZ lookups, POTA spots, sync) |
| `pty_bridge.py` | Bridges VICE RS232 PTY to TCP server |
| `DISK_FORMAT.md` | Deep-dive technical reference for D81/D64/REL file formats |
| `CLAUDE.md` | Developer reference (line ranges, variables, record formats) |

## Troubleshooting

### "DEVICE NOT PRESENT" error
VICE TDE (True Drive Emulation) is off. VICE saves drive settings persistently. Use `-drive8truedrive` explicitly when launching.

### Drive hangs / freezes on large files
If using a custom disk image, verify the POSITION command high byte calculation: `hi=int(rn/256)` — do NOT add +1. See DISK_FORMAT.md for details.

### Garbled text on screen (graphics characters)
Data contains lowercase ASCII. All data sent to the C64 must be uppercased. The server's `sanitize_csv()` and import scripts handle this automatically.

### "STRING TOO LONG" error
The RS232 readline buffer (`rl$`) has a 250-char guard. If the server sends lines longer than 255 bytes, they'll be truncated. This shouldn't happen with normal data.

### VICE RS232 not connecting
On macOS ARM (Apple Silicon), VICE 3.10's IP232 mode is broken. Use the PTY bridge approach with `+rsdev1ip232` (note the `+` to disable IP232).

# Ham Commander v2.2 — Annotated BASIC Source Reference

A line-by-line educational guide to the C64 BASIC ham radio logging program.
This document explains every line, variable, and technique used.

---

## Table of Contents

1. [Global Variables](#global-variables)
2. [Hardware Detection & RS232 Buffer Pre-allocation (Line 1)](#line-1-hardware-detection--rs232-buffer-pre-allocation)
3. [Initialization (Lines 9–70)](#initialization-lines-970)
4. [Main Loop & Key Dispatcher (Lines 102–136)](#main-loop--key-dispatcher-lines-102136)
5. [Cursor Navigation Dispatch (Lines 150–183)](#cursor-navigation-dispatch-lines-150183)
6. [POTA Spots Screen (Lines 200–335)](#pota-spots-screen-lines-200335)
7. [CSV Parser (Lines 240–257)](#csv-parser-lines-240257)
8. [Spot Cursor & Selection (Lines 260–299)](#spot-cursor--selection-lines-260299)
9. [Spot Screen Redraw (Lines 300–335)](#spot-screen-redraw-lines-300335)
10. [Log Screen (Lines 500–607)](#log-screen-lines-500607)
11. [Callsign Search (Lines 700–782)](#callsign-search-lines-700782)
12. [QSO Detail & Delete (Lines 800–907)](#qso-detail--delete-lines-800907)
13. [New QSO Entry (Lines 1000–1293)](#new-qso-entry-lines-10001293)
14. [Spot Filter Menu (Lines 1300–1345)](#spot-filter-menu-lines-13001345)
15. [Go Online / Connect (Lines 1500–1544)](#go-online--connect-lines-15001544)
16. [Queue Upload (Lines 1550–1602)](#queue-upload-lines-15501602)
17. [Go Offline / Disconnect (Lines 1700–1721)](#go-offline--disconnect-lines-17001721)
18. [QRZ Sync (Lines 1750–1802)](#qrz-sync-lines-17501802)
19. [Disk Mount & Navigation (Lines 1830–1872)](#disk-mount--navigation-lines-18301872)
20. [REL File Page Loader (Lines 1900–1922)](#rel-file-page-loader-lines-19001922)
21. [Server Protocol (Lines 2000–2021)](#server-protocol-lines-20002021)
22. [Screen Drawing Utilities (Lines 2200–2263)](#screen-drawing-utilities-lines-22002263)
23. [Config, Index, & Queue File I/O (Lines 2400–2491)](#config-index--queue-file-io-lines-24002491)
24. [Setup Wizard (Lines 2500–2588)](#setup-wizard-lines-25002588)
25. [Config Editor (Lines 2600–2655)](#config-editor-lines-26002655)
26. [Archive Disk (Lines 2670–2701)](#archive-disk-lines-26702701)
27. [Splash Screen & Morse Code (Lines 2710–2769)](#splash-screen--morse-code-lines-27102769)
28. [ACIA Baud Rate (Lines 2870–2875)](#acia-baud-rate-lines-28702875)
29. [RS232 I/O Subroutines (Lines 2880–2892)](#rs232-io-subroutines-lines-28802892)
30. [Machine Language DATA (Lines 2900–2915)](#machine-language-data-lines-29002915)
31. [Key Concepts & Gotchas](#key-concepts--gotchas)

---

## Global Variables

C64 BASIC limits variable names to 2 characters. Here is every variable used:

### State & Navigation
| Var  | Type   | Description |
|------|--------|-------------|
| `ol` | Number | Online flag: 0=offline, 1=connected to server |
| `sc` | Number | Current screen: 0=log, 1=spots, 2=new QSO, 3=detail, 4=search |
| `sl` | Number | Selected line (cursor position, 0-based within current page) |
| `lp` | Number | Log page number (0=most recent page) |
| `tp` | Number | Top line offset for spot scrolling |
| `vw` | Number | Visible rows (always 19) |
| `sf` | Number | Search flag: 1=viewing detail from search results |
| `sr` | Number | Search result count |
| `pc` | Number | Page count — number of records loaded for current log page |
| `os` | Number | Old selected line (saved before cursor move for redraw) |

### Record Counts & Disk
| Var  | Type   | Description |
|------|--------|-------------|
| `rc` | Number | Total record count on disk |
| `dc` | Number | Deleted record count |
| `mx` | Number | Max records per disk (3500 for D81, 600 for D64) |
| `dn` | Number | Disk sequence number (1, 2, 3...) |
| `dk` | Number | Disk type: 81 (D81) or 64 (D64) |
| `pq` | Number | Pending queue count (QSOs waiting to sync) |
| `sp` | Number | Number of POTA spots loaded |
| `fi` | Number | Filtered spot count |

### Station Config
| Var  | Type   | Description |
|------|--------|-------------|
| `mc$`| String | My callsign |
| `mn$`| String | My name |
| `mg$`| String | My grid square |
| `sv$`| String | Server IP address |
| `pt$`| String | Server port |
| `bd$`| String | Baud rate setting |

### Date/Time
| Var  | Type   | Description |
|------|--------|-------------|
| `ut$`| String | UTC date in YYYYMMDD format |
| `uh$`| String | UTC time in HHMM format |

### Communication
| Var  | Type   | Description |
|------|--------|-------------|
| `cm$`| String | Command to send to server |
| `s$` | String | String to send via RS232 (gosub 2880) |
| `a$` | String | Single character received via RS232 (gosub 2890) |
| `rl$`| String | Received line from server |
| `li$`| String | Last synced QRZ logid (for incremental sync) |
| `rt` | Number | Receive timeout counter |
| `hw` | Number | Hardware flag: 0=KERNAL RS232, 1=SwiftLink ACIA detected |

### Spot Arrays (DIM 20)
| Var  | Type   | Description |
|------|--------|-------------|
| `ca$()` | Array | Callsigns |
| `fq$()` | Array | Frequencies |
| `mo$()` | Array | Modes |
| `rf$()` | Array | Park references |
| `sd$()` | Array | (unused, reserved) |
| `fx()`  | Array | Filter index — maps display position to array index (shared with log!) |

### Log Display Arrays (DIM 20)
| Var  | Type   | Description |
|------|--------|-------------|
| `xc$()` | Array | Callsigns for log page |
| `xb$()` | Array | Band+mode formatted "20m |SSB |" |
| `xd$()` | Array | Date+time formatted "20240301|1423" |
| `xr$()` | Array | RST sent+received "599|599" |
| `fx()`  | Array | Record numbers for current page (**shared with spots!**) |

### CSV Parser Temporaries
| Var  | Type   | Description |
|------|--------|-------------|
| `p1$`–`p7$` | String | Parsed CSV field values |
| `pn` | Number | Current field number being parsed |
| `tl$`| String | Temporary copy of line being parsed |

### New QSO Fields
| Var  | Type   | Description |
|------|--------|-------------|
| `nc$`| String | New callsign |
| `nb$`| String | New band |
| `nm$`| String | New mode |
| `nf$`| String | New frequency |
| `nd$`| String | New date |
| `nt$`| String | New time |
| `rs$`| String | RST sent |
| `rr$`| String | RST received |
| `co$`| String | Comment |
| `na$`| String | Contact name (from lookup) |
| `gr$`| String | Contact grid (from lookup) |
| `cy$`| String | Contact country (from lookup) |
| `lg$`| String | QRZ log ID returned after upload |
| `lk$`| String | Lookup result temp |

### String Constants
| Var  | Type   | Description |
|------|--------|-------------|
| `h$` | String | 39 hyphens "---...---" for separator bars |
| `e$` | String | 39 equals "===...===" for title bars |
| `da$`| String | DAT file open string: `"hamlog.dat,l,"+chr$(168)` |
| `su$`| String | SUM file open string: `"hamlog.sum,l,"+chr$(40)` |
| `s9$`| String | 83 spaces — used to pad INPUT# results |

### Filters
| Var  | Type   | Description |
|------|--------|-------------|
| `fb$`| String | Band filter (e.g. "20m" or "" for all) |
| `fm$`| String | Mode filter (e.g. "cw" or "" for all) |

### Misc Temporaries
| Var  | Type   | Description |
|------|--------|-------------|
| `w$` | String | General-purpose temp (user input, key press, disk read) |
| `k$` | String | Key press from main loop GET |
| `rn` | Number | Record number for disk access |
| `lo` | Number | Low byte of record number: `rn AND 255` |
| `hi` | Number | High byte of record number: `INT(rn/256)` |
| `en` | Number | Error number from disk error channel |
| `em$`| String | Error message from disk |
| `ix` | Number | Index into spot/search arrays via fx() |
| `ri` | Number | Real index in spot display loop |
| `ln$`| String | Formatted line for display |
| `cf` | Number | Connect flag (modem got response) |
| `ef` | Number | Error flag for disk mount (0=ok, 1=failed) |
| `qi` | Number | Loop counter for ML readline / RS232 send (avoids `i` conflicts) |
| `si` | Number | Sync loop counter |
| `sa` | Number | Sync added count |
| `sn` | Number | Sync total count from server |
| `uq` | Number | Upload queue counter |

---

## Line 1: Hardware Detection & RS232 Buffer Pre-allocation

```basic
1 poke 56835,42:hw=-(peek(56835)=42):poke 56835,0:if hw=0 then open 2,2,0,chr$(8)+chr$(0)
```

**This is the most critical line in the entire program.** It must be line 1.

### What it does:
1. **ACIA detection**: Writes 42 to address $DE03 (SwiftLink command register). If it reads back 42, a SwiftLink/ACIA chip is present (Ultimate 64, Turbo232, etc.). The `-(...)` idiom converts BASIC's `-1` (true) to `1`.
2. **Cleanup**: Writes 0 back to $DE03 to reset the register.
3. **KERNAL RS232 open**: If no ACIA (`hw=0`), opens device 2 (userport RS232) with `CHR$(8)` = 1200 baud, `CHR$(0)` = 8N1.

### Why it must be line 1:
Opening device 2 causes the C64 KERNAL to allocate **512 bytes** of RS232 buffers at the top of BASIC RAM. If any `DIM` statements or variables exist first, the buffer allocation **silently overwrites** them, corrupting arrays, strings, and numeric values. By opening device 2 before anything else, the buffers are safely placed before any BASIC data exists.

Device 2 stays open for the entire program lifetime — going online/offline never closes it.

---

## Initialization (Lines 9–70)

```basic
9 poke 53280,0:poke 53281,0:print chr$(147);:gosub 2710
```
- `POKE 53280,0` — Set border color to black ($D020)
- `POKE 53281,0` — Set background color to black ($D021)
- `CHR$(147)` — Clear screen (PETSCII clear)
- `GOSUB 2710` — Show splash screen with ASCII art antenna and Morse code

```basic
10 print chr$(147);chr$(5);
11 print "  ham commander v2.2"
12 print chr$(159);"  loading..."
```
- `CHR$(5)` — Set text color to white
- `CHR$(159)` — Set text color to cyan

```basic
15 sv$="127.0.0.1":pt$="6400"
16 mc$="n0call":bd$="1200"
17 mn$="":mg$=""
```
Default configuration values. These get overwritten when HAMLOG.CFG is loaded from disk.

```basic
18 ol=0:sc=0:rc=0:li$="0":pq=0:sp=0:lp=0:sl=0:fi=0:sf=0:sr=0:dc=0:mx=3500:dn=1:dk=81
19 fb$="":fm$=""
```
Initialize all state variables to safe defaults. `mx=3500` is the default max records for D81 format.

```basic
28 ut$="00000000":uh$="0000"
```
Placeholder UTC date/time until server provides real values via HELLO response.

```basic
29 s9$="                                                                                   "
```
83 spaces — used to left-pad strings after INPUT# strips leading spaces from REL file data.

```basic
30 if hw then for i=0to145:read a:poke 49152+i,a:next:for i=0to82:read a:poke 49920+i,a:next:sys 49152
```
If SwiftLink detected: load the machine language driver into memory.
- **49152–49297 ($C000)**: 146-byte ACIA driver (NMI interrupt handler, send, get routines)
- **49920–50002 ($C300)**: 83-byte ML readline (reads complete line from NMI ring buffer)
- `SYS 49152` initializes the driver (hooks NMI vector, configures ACIA registers)

```basic
31 dim ca$(20),fq$(20),mo$(20),rf$(20),sd$(20)
35 dim xc$(20),xb$(20),xd$(20),xr$(20)
40 dim fx(20)
```
Array allocation. DIM 20 creates indices 0–20 (21 elements). All arrays capped at 20 entries to conserve RAM.

```basic
42 h$="---------------------------------------"
43 e$="======================================="
```
39-character separator bars. **Must be 39, not 40!** Printing exactly 40 characters causes the C64 to extend the logical line across two physical screen rows, corrupting the display.

```basic
44 da$="hamlog.dat,l,"+chr$(168)
45 su$="hamlog.sum,l,"+chr$(40)
```
REL file open strings. The `chr$(168)` = record length 168 bytes. The `chr$(40)` = record length 40 bytes. The `,l,` means "relative" file type in CBM DOS.

```basic
50 gosub 2400
51 if hw then gosub 2870
52 gosub 2450
54 gosub 2480
```
Load configuration from disk:
- 2400 — Read HAMLOG.CFG (callsign, server, etc.)
- 2870 — Set ACIA baud rate from config (only if SwiftLink present)
- 2450 — Read HAMLOG.IDX (record count, logid, disk number, etc.)
- 2480 — Count pending queue entries in HAMLOG.QUE

```basic
55–62 (Station info display)
```
Print loaded configuration: callsign, name, grid, server, record count, disk number, pending sync count.

```basic
63 print " utc date yyyymmdd (enter=skip):"
64 input " ";td$
65 if td$<>"" then ut$=td$
66–67 (optional time entry)
```
Manual UTC entry for offline use. When online, the server provides accurate UTC via the HELLO response.

```basic
72 lp=0:sc=0:gosub 500:goto 102
```
Initialize to log screen (page 0) and enter main loop.

### Startup Archive Disk Loader (Lines 80–88)

```basic
80 print " load archive disk? (y/n)"
81 get w$:if w$="" then 81
82 if w$<>"y" then return
83 print:input " disk # ";td
84 if td<1 or td=dn then print " cancelled.":return
85 gosub 1830:if ef then return
86 dn=td:gosub 2400:gosub 2450:gosub 2480
87 print " loaded disk #";dn;" (";rc-dc;"/";mx;")"
88 return
```
Offered when `dn>1` (multi-disk setup). Lets the user switch to a different numbered disk at startup. Calls the mount subroutine (1830) which handles both SD2IEC and manual disk swap.

---

## Main Loop & Key Dispatcher (Lines 102–136)

```basic
102 get k$:if k$="" then 102
```
The heart of the program. `GET` reads one keypress without waiting for RETURN. If no key is pressed (`k$=""`), loop back. This is a busy-wait polling loop — standard C64 pattern.

### F-Key Handlers

```basic
104 if k$=chr$(133) and sp>0 then sc=1:sl=0:gosub 290:gosub 300:goto 102
105 if k$=chr$(133) and ol=1 then sc=1:gosub 1300:goto 102
106 if k$=chr$(133) and ol=0 then sc=1:gosub 200:goto 102
```
**F1 (CHR$(133))** — POTA Spots:
- Line 104: If spots are cached (`sp>0`), rebuild filter index (`gosub 290`) and redraw from cache. The `gosub 290` is critical because `fx()` may have been overwritten by the log screen.
- Line 105: If online but no cached spots, show filter menu first, then fetch.
- Line 106: If offline, show "go online" message.

**Note the priority**: Lines are checked top-to-bottom. Line 104 catches F1 when spots exist, so 105/106 only fire when `sp=0`.

```basic
107 if k$=chr$(134) then sc=0:lp=0:gosub 500:goto 102
```
**F3 (CHR$(134))** — Log screen. Resets to page 0.

```basic
108 if k$=chr$(135) then sc=2:gosub 1000:goto 102
```
**F5 (CHR$(135))** — New QSO entry screen.

```basic
110 if k$=chr$(136) and ol=0 then goto 1500
111 if k$=chr$(136) and ol=1 then goto 1700
```
**F7 (CHR$(136))** — Toggle online/offline. Note the use of `GOTO` instead of `GOSUB` — this is intentional! The online/offline routines jump directly back to `102` when done. Using `GOSUB` here would leave return addresses on the stack, eventually causing stack overflow during long sessions.

```basic
114 if k$=chr$(17) then gosub 150:goto 102
116 if k$=chr$(145) then gosub 160:goto 102
118 if k$=chr$(13) then gosub 170:goto 102
120 if k$=chr$(20) then gosub 180:goto 102
```
- **Cursor Down (17)** → dispatch to cursor-down handler for current screen
- **Cursor Up (145)** → dispatch to cursor-up handler
- **RETURN (13)** → dispatch to select/enter handler
- **DEL (20)** → dispatch to back/delete handler

```basic
122 if k$=chr$(137) and sc=1 then gosub 1300:goto 102
```
**F2 (CHR$(137))** — Re-filter spots (only on spot screen).

```basic
124 if k$=chr$(139) and ol=1 then goto 1750
```
**F6 (CHR$(139))** — Sync with QRZ (only when online). Uses `GOTO` to avoid stack issues.

```basic
126 if k$=chr$(138) then gosub 2600:goto 102
```
**F4 (CHR$(138))** — Configuration editor.

```basic
128 if k$="d" and sc=3 and sf=0 then gosub 843:goto 102
129 if k$="s" and sc=0 and rc>0 then gosub 700:goto 102
130 if k$="+" and sc=0 then gosub 575:goto 102
131 if k$="-" and sc=0 then gosub 577:goto 102
132 if k$="r" and sc=1 and ol=1 then gosub 200:goto 102
133 if k$="<" and sc=0 and dn>1 then gosub 1850:goto 102
135 if k$=">" and sc=0 then gosub 1860:goto 102
136 goto 102
```
- **d** — Delete QSO (detail screen, not from search results)
- **s** — Search by callsign (log screen)
- **+/-** — Next/prev log page
- **r** — Refresh spots
- **</>** — Navigate to previous/next archive disk

---

## Cursor Navigation Dispatch (Lines 150–183)

```basic
150 if sc=0 then gosub 561:return
151 if sc=1 then gosub 260:return
152 if sc=4 then gosub 760:return
153 return
```
**Cursor Down**: Routes to the appropriate handler based on current screen.

```basic
160 if sc=0 then gosub 571:return
161 if sc=1 then gosub 270:return
162 if sc=4 then gosub 770:return
163 return
```
**Cursor Up**: Same routing pattern.

```basic
170 if sc=0 then gosub 580:return
171 if sc=1 then gosub 280:return
172 if sc=4 then gosub 780:return
173 return
```
**RETURN/Enter**: Select item on current screen.

```basic
180 if sc=3 and sf=1 then sf=0:sc=4:gosub 735:return
181 if sc=3 then sc=0:gosub 500:return
182 if sc=4 then sc=0:gosub 500:return
183 return
```
**DEL/Back**:
- From detail view via search (`sf=1`): go back to search results
- From detail view: go back to log
- From search results: go back to log

---

## POTA Spots Screen (Lines 200–335)

### Fetching Spots from Server (Lines 200–234)

```basic
200 if ol=0 then gosub 2200
203 if ol=0 then print:print "  go online for spots (f7)"
204 if ol=0 then gosub 2260:return
```
If offline, show a message and the F-key bar, then return.

```basic
206 gosub 2200
207 print " fetching spots..."
208 cm$="spots"
209 if fb$<>"" then cm$=cm$+","+fb$
210 if fm$<>"" then cm$=cm$+","+fm$
211 gosub 2000
212 gosub 2010
```
Build the SPOTS command with optional band/mode filters. Send it (2000) and read the response line (2010).

```basic
214 if left$(rl$,6)<>"!spots" then 231
215 sp=val(mid$(rl$,8)):if sp>20 then sp=20
216 if sp<1 then gosub 2010:print " no spots.":gosub 2260:return
```
Parse the `!spots,N` response header. Cap at 20 spots. If zero, consume the `!END` marker and return.

```basic
217 gosub 2200:print chr$(159);"loading ";sp;" spots...";chr$(5)
218 print chr$(154);h$;chr$(5)
219 for i=1 to sp
220 gosub 2010
221 gosub 240
222 if i<1 or i>20 then 226
223 ca$(i)=p1$:fq$(i)=p2$:mo$(i)=p3$
224 rf$(i)=p4$:sd$(i)=""
225 print left$(p1$+"          ",10);left$(p2$+"       ",7);" ";left$(p3$+"    ",4);" ";left$(p4$+"          ",10)
226 s$="k"+chr$(13):gosub 2880
227 next i
```
**Progressive loading loop**: For each spot, read a CSV line from server, parse it, store in arrays, print immediately (user sees spots appear one by one), and send ACK (`"k\r"`) so the server sends the next record. The ACK handshake prevents buffer overrun — the C64 is too slow to receive all spots at once.

```basic
228 gosub 2010
229 gosub 290:sl=0:tp=0
```
Read the `!END` marker from server. Build the filter index (`gosub 290`), reset cursor to top.

```basic
230 st$="online":if fb$<>"" or fm$<>"" then st$=st$+" | "+fb$+" "+fm$
231 st$=st$+" | "+str$(fi)+" spots":poke 214,0:print:print chr$(159);left$(st$+"...",39);chr$(5)
232 poke 214,fi+2:print:print chr$(154);h$;chr$(5):print chr$(155);" ent=log f2=filt r=rfsh ...";chr$(5)
```
Draw status bar and help bar. `POKE 214,n` sets the cursor row (0-based) — a fast way to position without printing blank lines.

```basic
233 gosub 2260:i=0:gosub 295:poke 214,2:print:print chr$(158);chr$(18);left$(ln$+"...",39);chr$(146);chr$(5);
234 return
```
Draw F-key bar, then highlight the first spot (index 0). `CHR$(18)` = reverse on, `CHR$(146)` = reverse off. `CHR$(158)` = yellow text for selection highlight.

---

## CSV Parser (Lines 240–257)

```basic
240 p1$="":p2$="":p3$="":p4$="":p5$="":p6$="":p7$=""
241 tl$=rl$:pn=1
242 for j=1 to len(tl$)
243 c$=mid$(tl$,j,1)
244 if c$<>"," then 248
245 pn=pn+1:if pn>7 then j=len(tl$):goto 249
246 goto 249
248 on pn goto 251,252,253,254,255,256,257
249 next j:return
```
A general-purpose CSV parser. Splits `rl$` into up to 7 fields (`p1$`–`p7$`).

### How it works:
1. Initialize all 7 output fields to empty strings
2. Walk through the string character by character
3. If comma: advance field counter `pn`, if >7 fields skip the rest
4. If not comma: `ON pn GOTO` dispatches to the appropriate append line
5. Lines 251–257 each append the character to the corresponding field

The `ON...GOTO` statement is an efficient computed jump — the C64 equivalent of a switch/case. `ON 1 GOTO 251,252,...` jumps to the Nth target.

```basic
251 p1$=p1$+c$:goto 249
252 p2$=p2$+c$:goto 249
...
257 p7$=p7$+c$:goto 249
```
Each just appends the current character to the right field variable and jumps back to the loop.

---

## Spot Cursor & Selection (Lines 260–299)

### Cursor Down (Line 260)

```basic
260 if fi<1 or sl>=fi-1 then return
262 os=sl:sl=sl+1
263 if sl-tp>=19 then tp=tp+1:gosub 300:return
264 gosub 297:return
```
- Bounds check: can't go below last spot
- Save old position, increment selection
- If cursor would go off screen (19 visible rows), scroll down and full redraw
- Otherwise, just update the two affected lines (old and new selection) via `gosub 297`

### Cursor Up (Lines 270–273)

```basic
270 if sl<1 then return
271 os=sl:sl=sl-1
272 if sl<tp then tp=tp-1:gosub 300:return
273 gosub 297:return
```
Mirror of cursor-down. Scroll up if needed.

### Enter/Select (Lines 280–287)

```basic
280 if fi=0 then return
281 ix=fx(sl+1)
283 nc$=ca$(ix):nf$=fq$(ix):nm$=mo$(ix)
284 nb$=""
285 gosub 1280
286 sc=2:gosub 1000
287 return
```
When user presses RETURN on a spot:
1. Look up the real array index via `fx()` filter mapping
2. Pre-fill new QSO fields with the spot's callsign, frequency, mode
3. Auto-detect band from frequency (`gosub 1280`)
4. Jump to New QSO entry screen

### Build Filter Index (Lines 290–294)

```basic
290 fi=0
291 for i=1 to sp
292 fi=fi+1:fx(fi)=i
293 next i
294 return
```
Creates a 1:1 mapping `fx(1)=1, fx(2)=2, ...`. In the current code, there's no actual filtering here (all spots pass), but the indirection through `fx()` allows future filtering without changing the display code.

### Line Formatter (Line 295)

```basic
295 ix=fx(i+1):ln$=left$(ca$(ix)+"          ",10)+left$(fq$(ix)+"       ",7)+" "+left$(mo$(ix)+"    ",4)+" "+left$(rf$(ix)+"          ",10)
```
Formats one spot line for display. The `left$(str+"padding",width)` pattern is the C64 equivalent of printf field padding — append excess spaces then truncate to exact width.

### Two-Line Redraw (Lines 297–299)

```basic
297 i=os:gosub 295:poke 214,(os-tp)+2:print
298 print left$(ln$+"...",39);
299 i=sl:gosub 295:poke 214,(sl-tp)+2:print:print chr$(158);chr$(18);left$(ln$+"...",39);chr$(146);chr$(5);:return
```
Efficient cursor movement: instead of redrawing the entire screen, only redraw the old line (un-highlight) and the new line (highlight). `POKE 214,row` positions the cursor vertically. The `+2` accounts for the title bar and status bar.

---

## Spot Screen Redraw (Lines 300–335)

```basic
300 gosub 2200
302 st$=""
303 if ol=1 then st$="online"
304 if ol=0 then st$="offline"
305 if fb$<>"" or fm$<>"" then st$=st$+" | "+fb$+" "+fm$
306 st$=st$+" | "+str$(fi)+" spots"
307 print chr$(159);left$(st$,40);chr$(5)
309 print chr$(154);h$;chr$(5)
311 vw=19
312 tp=sl:if tp>fi-vw then tp=fi-vw
313 if tp<0 then tp=0
```
Clear screen, draw title, status bar, separator. Calculate scroll offset so the selected item is visible.

```basic
315 for i=0 to vw-1
316 ri=tp+i+1
317 if ri>fi then print "                                        ";:goto 330
318 ix=fx(ri)
320 if tp+i=sl then print chr$(158);chr$(18);
321 cl$=left$(ca$(ix)+"          ",10)
322 fr$=left$(fq$(ix)+"       ",7)
323 md$=left$(mo$(ix)+"    ",4)
324 pr$=left$(rf$(ix)+"          ",10)
325 print cl$;fr$;" ";md$;" ";pr$;
326 if tp+i=sl then print chr$(146);chr$(5);
327 print
330 next i
```
Print each visible spot row. The `fx()` indirection allows filtered views. Selected line gets reverse-video highlight.

---

## Log Screen (Lines 500–607)

### Main Log Display (Lines 500–519)

```basic
500 gosub 2200
504 st$=""
505 if ol=1 then st$="online"
506 if ol=0 then st$="offline"
507 st$=st$+" | "+str$(rc-dc)+" qsos"
508 if pq>0 then st$=st$+" | pend:"+str$(pq)
509 if rc>mx*0.8 then st$=st$+" "+str$(int(rc/mx*100))+"%"
510 print chr$(159);left$(st$+"...",39);chr$(5)
```
Status bar shows: online/offline, QSO count (minus deleted), pending sync count, and disk capacity percentage when >80% full.

```basic
512 if rc=0 then print:print "  no qsos yet. press f5 to add.":gosub 2260:sl=0:return
513 gosub 1900
```
Empty log shortcut. Otherwise, load one page of records from disk (`gosub 1900`).

```basic
515 sl=0:vw=19
516 poke 214,pc+1:print:print chr$(154);h$;chr$(5)
517 print chr$(155);" pg ";lp+1;" s=srch ent=dtl +/- <> ...";chr$(5):gosub 2260
518 i=0:gosub 590:poke 214,1:print:print chr$(158);chr$(18);left$(ln$+"...",39);chr$(146);chr$(5);
519 return
```
Note that `gosub 1900` (page loader) progressively prints records as they load, so by the time we get here, the data rows are already on screen. We just need to add the separator, help text, and highlight the first row.

### Log Line Formatter (Lines 590–599)

```basic
590 d$=left$(xd$(i+1),8)
592 if len(xd$(i+1))>9 then t$=mid$(xd$(i+1),10,4):goto 594
593 t$="----"
594 cl$=left$(xc$(i+1)+"         ",9)
595 bx$=left$(xb$(i+1),3)
596 md$=left$(mid$(xb$(i+1),6,3)+"   ",3)
598 ln$=mid$(d$,5,2)+"/"+mid$(d$,7,2)+"/"+mid$(d$,3,2)+" "+t$+" "+cl$+bx$+" "+md$
599 return
```
Formats a log entry as: `MM/DD/YY HHMM CALLSIGN  20m SSB`

The date is stored YYYYMMDD but displayed MM/DD/YY using `MID$` to rearrange. The `xb$` format is `"20m |SSB |"` — band at position 1, mode at position 6.

### Cursor Movement (Lines 561–607)

```basic
561 if pc<1 then return
563 if sl<pc-1 then os=sl:sl=sl+1:gosub 600:return
565 if pc>=19 then lp=lp+1:gosub 1900:sl=0:gosub 540
566 return
```
**Cursor down** on log: if not at bottom of page, move cursor. If at bottom and page is full (19 records), load next page.

```basic
571 if sl>0 then os=sl:sl=sl-1:gosub 600:return
573 if lp>0 then lp=lp-1:gosub 1900:sl=18:gosub 540
574 return
```
**Cursor up**: if not at top, move cursor. If at top and there's a previous page, load it and set cursor to bottom.

```basic
575 if pc>=19 then lp=lp+1:gosub 1900:sl=0:gosub 540
576 return
577 if lp>0 then lp=lp-1:gosub 1900:sl=0:gosub 540
578 return
```
**+/-** page forward/back.

```basic
580 if rc=0 then return
581 rn=rc-lp*19-sl
582 if rn<1 then return
583 sc=3:gosub 800
584 return
```
**RETURN**: calculate absolute record number from page and cursor position. The log displays newest-first, so `rn = rc - (page*19 + cursor_pos)`. Then show QSO detail.

```basic
600 i=os:gosub 590:poke 214,os+1:print
604 print left$(ln$+"...",39);
605 i=sl:gosub 590:poke 214,sl+1:print
606 print chr$(158);chr$(18);left$(ln$+"...",39);chr$(146);chr$(5);
607 return
```
Two-line redraw for cursor movement (same pattern as spot screen).

---

## Callsign Search (Lines 700–782)

```basic
700 gosub 2200
701 sc=4:print " search by callsign:"
702 print:input " search: ";sq$
703 if sq$="" then sc=0:gosub 500:return
704 print " searching ";rc;" records..."
705 sr=0
706 open 15,8,15:open 3,8,3,su$
707 for rn=1 to rc
708 if sr>=20 then 718
709 lo=rn and 255:hi=int(rn/256)
710 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
711 input#3,w$
712 if left$(w$,len(sq$))<>sq$ then 718
713 sr=sr+1:fx(sr)=rn
```
Sequential scan through all summary records. The POSITION command (`"p"`) sets the REL file pointer: channel 3, low byte, high byte, byte offset 1 (start of record). `INPUT#3` reads one record. Prefix-matches the callsign against the search term. Stores matching record numbers in `fx()` (up to 20 matches).

Lines 735–747 display search results using the same format as the log screen. Lines 760–782 handle cursor navigation and detail view within search results.

---

## QSO Detail & Delete (Lines 800–907)

### Detail View (Lines 800–840)

```basic
805 rn=fx(sl+1)
806 open 15,8,15
807 open 3,8,3,da$
808 lo=rn and 255:hi=int(rn/256)
809 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
810 input#3,a$:print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(85)
811 input#3,b$:if len(b$)<83 then b$=left$(s9$,83-len(b$))+b$
812 close 3:close 15:w$=a$+b$
```
**Two-half REL file read**: Each 168-byte record is stored as two 83-byte halves separated by CR bytes. The first `INPUT#3` reads half1 (stops at CR). Then POSITION to byte 85 (83 data + 1 CR + 1 for 1-based = byte 85) and `INPUT#3` reads half2.

**Critical**: `INPUT#` strips leading spaces. Half2 often starts with spaces (empty comment field), so we must left-pad it back to 83 bytes using `s9$` (83 spaces).

After concatenation, `w$` is 166 bytes (83+83) and fields can be extracted by position using `MID$`.

Lines 819–838 display all fields with labels. The sync status flag at position 77 shows "synced", "pending sync", or "local only".

### Delete QSO (Lines 843–907)

```basic
843–849 (confirmation prompt)
851 rn=fx(sl+1):gosub 890:return
```

```basic
890 open 15,8,15
891 open 3,8,3,da$
892–895 (read both halves)
896 w$=a$+b$:of$=mid$(w$,77,1):w$=left$(w$,76)+"d"+mid$(w$,78)
897–898 (write both halves back with flag="d")
899–901 (also update SUM record with flag="d")
902 close 3:close 15
903 dc=dc+1:if of$="n" or of$="p" then pq=pq-1:if pq<0 then pq=0
904 gosub 2462
```
Delete is a soft-delete: reads the record, replaces the sync flag (position 77) with "d", writes it back. Updates both DAT and SUM files. Increments deleted count `dc`. If the record was pending sync, decrements the pending queue count. Saves the updated index.

---

## New QSO Entry (Lines 1000–1293)

### Entry Form (Lines 1000–1071)

```basic
1005 if rc>=mx then print:print "  disk full!...":gosub 2260:return
1006 if nc$<>"" then print "  callsign: ";nc$:print "  del=cancel":goto 1010
1007 print:input "  callsign: ";nc$
```
If disk is full, refuse entry. If callsign was pre-filled (from spot selection), show it with option to cancel.

```basic
1012 lk$="":lg$="":ln$="":ly$=""
1013 if ol=1 then gosub 1200
```
If online, do a QRZ lookup to pre-fill name, grid, country.

```basic
1015–1038 (input fields: band, mode, freq, date, time, RST sent/received, comment)
1040–1052 (confirmation display)
```
Standard form input. Date/time default to the current UTC values.

```basic
1055 rc=rc+1
1056 gosub 1100
1057 gosub 1130
1058 gosub 1150
1059 pq=pq+1
1061 gosub 2462
```
After confirmation:
1. Increment record count
2. Write DAT record (`gosub 1100`)
3. Write SUM record (`gosub 1130`)
4. Append to sync queue (`gosub 1150`)
5. Increment pending count
6. Save index file

```basic
1067 if ol=1 then gosub 1170
```
If online, attempt immediate upload to QRZ (`gosub 1170`).

### DAT Record Builder (Lines 1100–1126)

```basic
1100 w$=left$(nc$+"            ",12)
1102 w$=w$+left$(nb$+"      ",6)
1103 w$=w$+left$(nm$+"      ",6)
...
1115 w$=w$+left$(cy$+"             ",13)
```
Builds the 166-byte record string by padding each field to its exact width. This is the record layout:

| Offset | Width | Field |
|--------|-------|-------|
| 1 | 12 | Callsign |
| 13 | 6 | Band |
| 19 | 6 | Mode |
| 25 | 8 | Date |
| 33 | 4 | Time |
| 37 | 10 | Frequency |
| 47 | 3 | RST Sent |
| 50 | 3 | RST Received |
| 53 | 12 | Station callsign |
| 65 | 12 | QRZ Log ID |
| 77 | 1 | Sync flag |
| 78 | 40 | Comment |
| 118 | 6 | Grid |
| 124 | 30 | Name |
| 154 | 13 | Country |

```basic
1117 open 15,8,15
1118 open 3,8,3,da$
1120 lo=rc and 255:hi=int(rc/256)
1121 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
1122 print#3,left$(w$,83):print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(85):print#3,mid$(w$,84)
```
**Two-half write**: POSITION to record, write first 83 bytes, POSITION to byte 85, write remaining bytes. Each `PRINT#` appends a CR, giving the 83+CR+83+CR = 168 byte record structure.

### Band Auto-Detection (Lines 1280–1293)

```basic
1284 if fv>=7000 and fv<=7300 then nb$="40m":return
```
Converts frequency (in kHz) to band name by checking amateur band boundaries.

---

## Spot Filter Menu (Lines 1300–1345)

```basic
1300–1342 (band/mode selection UI)
1344 sc=1:gosub 200
1345 return
```
Shows numbered menu for band (0-9) and mode (0-4) filters. After selection, calls `gosub 200` which sends the SPOTS command with filter parameters to the server.

---

## Go Online / Connect (Lines 1500–1544)

```basic
1510 print " dialing ";sv$;":";pt$
1511 s$="atdt"+sv$+":"+pt$+chr$(13):gosub 2880
```
Send Hayes AT modem dial command. The WiFi modem interprets `ATDT ip:port` as a TCP connection request.

```basic
1512–1518 (wait for modem response, print connect message)
1520 for w=1to200:gosub 2890:next
1521 cm$="hello":gosub 2000
1522 gosub 2010
1524 if left$(rl$,3)<>"!ok" then print " connection failed":goto 1540
```
Flush modem buffer (200 reads to clear stale data), then send HELLO command and check for `!ok` response.

```basic
1526 gosub 240:ut$=p4$:uh$=p5$
1529 ut$=p4$:uh$=p5$
1530 ol=1
```
Parse the HELLO response CSV to get server UTC date/time. Set online flag.

```basic
1537 if sc=1 then gosub 200:goto 102
1538 sc=0:gosub 500:goto 102
```
Return to the appropriate screen. Note `GOTO 102` — does not use `RETURN`, avoiding GOSUB stack buildup.

---

## Queue Upload (Lines 1550–1602)

```basic
1551 open 15,8,15:open 4,8,4,"hamlog.que,s,r"
1554 uq=0
1555 input#4,qc$,qb$,qm$,qf$,qd$,qt$,qs$,qr$,qo$,qn$
1558 cm$="add,"+qc$+","+qb$+","+qm$+","+qf$+","+qd$+","+qt$+","+qs$+","+qr$+","+qo$
1559 gosub 2000:gosub 2010
1560 if left$(rl$,7)="!add,ok" then uq=uq+1:print " synced: ";qc$
1563 rn=val(qn$):if rn>0 and left$(rl$,7)="!add,ok" then close 15:gosub 1590:open 15,8,15
1564 if ef then 1580
1565 goto 1555
```
Reads QSOs from the queue file one at a time, sends ADD command to server. On success, updates the local record with the QRZ log ID (`gosub 1590`). The `close 15` / `open 15,8,15` around `gosub 1590` avoids the "FILE OPEN ERROR" — the subroutine needs its own channel 15 for POSITION commands.

```basic
1584 if pq=0 then open 15,8,15,"s0:hamlog.que":close 15
```
If all records uploaded, delete the queue file. The `"s0:filename"` syntax is the CBM DOS scratch (delete) command.

---

## Go Offline / Disconnect (Lines 1700–1721)

```basic
1706 cm$="bye":gosub 2000
1707 gosub 2010
1709 for i=1 to 500:next i
1710 s$="+++":gosub 2880
1711 for i=1 to 500:next i
1712 s$="ath"+chr$(13):gosub 2880
```
Standard Hayes modem disconnect sequence:
1. Send BYE to server (graceful close)
2. Wait 1 second (guard time)
3. Send `+++` (escape to command mode)
4. Wait 1 second
5. Send `ATH` (hang up)

---

## QRZ Sync (Lines 1750–1802)

```basic
1758 cm$="sync,"+li$+","+str$(mx-rc):gosub 2000
```
Send SYNC command with last logid and available capacity. Server returns only records newer than `li$`, up to `mx-rc` records.

```basic
1765 open 15,8,15:open 3,8,3,da$:open 5,8,5,su$
1766 sa=0:for si=1 to sn
1767 gosub 2010:gosub 240
1771 if rc>=mx then print " disk full!":goto 1794
1772 rc=rc+1:sa=sa+1:w$=left$(p2$+"            ",12)
...
1789 print#3,left$(w$,83):print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(85):print#3,mid$(w$,84)
1790 s$=...
1791 print#15,"p"+chr$(5)+chr$(lo)+chr$(hi)+chr$(1):print#5,s$
1792 if si<sn then s$="k"+chr$(13):gosub 2880
```
For each synced record: parse CSV, build DAT record, write to both DAT (channel 3) and SUM (channel 5), send ACK. Note channel 5 for SUM — both files are open simultaneously for efficiency.

**Critical timing**: ACK is sent AFTER disk writes complete. If sent before, the server's next record arrives while the 1581 drive is still writing, and the data is lost (RS232 NMI can be blocked during TDE disk I/O).

---

## Disk Mount & Navigation (Lines 1830–1872)

### SD2IEC Mount (Lines 1830–1846)

```basic
1830 ef=0:td$=right$(str$(td+100),2):df$="hamlog-"+td$+".d"+right$(str$(dk),2)
1831 open 15,8,15,"cd:"+chr$(95):input#15,en,em$,et$,es$:close 15
1832 if en>0 then 1840
1833 open 15,8,15,"cd:"+df$:input#15,en,em$,et$,es$:close 15
1834 if en=0 then print " mounted ";df$:return
```
Tries SD2IEC CD command: first `CD:←` (go to root, CHR$(95) = back-arrow = root), then `CD:hamlog-NN.d81` to mount the disk image. The `right$(str$(td+100),2)` trick generates zero-padded 2-digit numbers: `str$(101)` = " 101", `right$(...,2)` = "01".

If SD2IEC commands fail (error on `CD:←`), falls through to manual disk swap prompt (line 1840).

### Disk Navigation (Lines 1850–1872)

```basic
1850 td=dn-1:gosub 1830:if ef then gosub 500:return
1851 dn=td:goto 1870
1860 td=dn+1:gosub 1830:if ef then gosub 500:return
1861 dn=td
1870 gosub 2400:gosub 2450:gosub 2480
1871 lp=0:sl=0:gosub 500
```
`<` and `>` keys on log screen: mount previous/next disk image, reload config + index + queue, refresh log display.

---

## REL File Page Loader (Lines 1900–1922)

```basic
1900 if rc=0 then return
1904 open 15,8,15
1905 open 3,8,3,su$
1906 pc=0:sk=0
1907 for j=rc to 1 step -1
1908 lo=j and 255:hi=int(j/256)
1909 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
1910 input#3,w$
1911 if mid$(w$,37,1)="d" then 1920
1912 if sk<lp*19 then sk=sk+1:goto 1920
1913 pc=pc+1:fx(pc)=j
1914 xc$(pc)=left$(w$,10)
1915 xb$(pc)=mid$(w$,11,4)+"|"+mid$(w$,15,4)+"|"
1916 xd$(pc)=mid$(w$,19,8)+"|"+mid$(w$,27,4)
1917 xr$(pc)=mid$(w$,31,3)+"|"+mid$(w$,34,3):i=pc-1:gosub 590:print ln$
1918 if pc>=19 then j=1
1920 next j
1921 close 3:close 15
```

**Reverse-order loading**: Iterates from `rc` down to 1 (newest records first). For each record:
1. POSITION to record in SUM file (40 bytes, fast read)
2. Read the summary record
3. **Skip deleted**: if flag at position 37 is "d", skip
4. **Skip previous pages**: if we haven't skipped enough records for the current page (`lp`), increment skip counter
5. **Store**: save record number in `fx()`, extract fields into display arrays
6. **Progressive display**: `i=pc-1:gosub 590:print ln$` — format and print each record as it loads, so the user sees data appearing progressively
7. **Stop at page size**: when `pc>=19`, force loop exit by setting `j=1`

**Important**: `fx()` stores the absolute record number for each displayed row. This is how detail view and delete know which record to access.

---

## Server Protocol (Lines 2000–2021)

### Send Command (Line 2000)

```basic
2000 s$=cm$+chr$(13):gosub 2880
2003 return
```
Append CR to command and send via RS232.

### Receive Line — KERNAL RS232 (Lines 2010–2018)

```basic
2010 rl$="":rt=0:if hw then 2020
2011 gosub 2890
2012 if a$="" or a$=chr$(0) then rt=rt+1:if rt>2000 then return
2013 if a$="" or a$=chr$(0) then 2011
2014 rt=0:if a$=chr$(10) then 2011
2015 if a$=chr$(13) then return
2016 if len(rl$)<250 then rl$=rl$+a$
2018 goto 2011
```
Character-by-character readline. Skip nulls and LF (10), accumulate until CR (13) or timeout. The 250-char guard prevents STRING TOO LONG error (C64 max = 255). Timeout after 2000 empty reads (~4 seconds).

### Receive Line — SwiftLink ML (Lines 2020–2021)

```basic
2020 sys 49920:ln=peek(49392):if ln=0 then rt=rt+1:if rt<20 then 2020
2021 for qi=0toln-1:rl$=rl$+chr$(peek(49664+qi)):next:return
```
Calls the ML readline at $C300. It reads from the NMI ring buffer (filled by interrupt handler) into $C200. Length stored at $C0F0 (49392). Much faster than BASIC character-by-character — the main bottleneck with KERNAL RS232 is GOSUB overhead (~180ms per character).

**Critical**: Uses `qi` as loop counter, not `i` — outer loops (spot loading, sync) use `i`.

---

## Screen Drawing Utilities (Lines 2200–2263)

### Clear & Title Bar (Lines 2200–2212)

```basic
2200 print chr$(147);chr$(5);
2203 print chr$(154);chr$(18);"                                       ";chr$(146)
2205 print chr$(19);
2206 if sc=1 then print chr$(154);chr$(18);"  pota spots ";chr$(146);
2207 if sc=0 then print chr$(154);chr$(18);"  qso log ";chr$(146);
...
2211 print chr$(154);chr$(18);" de ";mc$;" ";chr$(146)
2212 print chr$(5);:return
```
- `CHR$(147)` — Clear screen
- `CHR$(18)` — Reverse video on (for title bar background)
- `CHR$(146)` — Reverse video off
- `CHR$(19)` — HOME (cursor to top-left, no clear)
- `CHR$(154)` — Light blue text
- `CHR$(5)` — White text

First prints a full 39-space reversed bar, then HOMEs and overlays the screen name on the left and callsign on the right. The 39-char limit prevents the 40-column line extension bug.

### Status Bar Helper (Lines 2220–2227)

```basic
2220 st$=""
2221 if ol=1 then st$="online"
2222 if ol=0 then st$="offline"
2223 st$=st$+" | "+str$(rc-dc)+" qsos"
2224 if pq>0 then st$=st$+" | pend:"+str$(pq)
2225 if rc>mx*0.8 then st$=st$+" "+str$(int(rc/mx*100))+"%"
2226 print chr$(159);left$(st$,40);chr$(5)
2227 return
```

### F-Key Bar (Lines 2260–2263)

```basic
2260 poke 214,23:print
2262 print chr$(154);chr$(18);"f1=spt f3=log f4=cfg f5=nw f6=syn f7=on";chr$(146);chr$(5);
2263 return
```
`POKE 214,23` positions cursor to row 23 (second to last). The F-key bar is always at the bottom of the screen, reverse-video light blue.

---

## Config, Index, & Queue File I/O (Lines 2400–2491)

### Read Config (Lines 2400–2413)

```basic
2400 open 15,8,15
2403 open 4,8,4,"hamlog.cfg,s,r"
2404 input#15,en,em$,et$,es$
2405 if en<>0 then close 4:close 15:goto 2500
```
Open command channel (15) and config file. Check error channel — if file not found (`en<>0`), jump to setup wizard. The error channel returns 4 values: error number, message, track, sector.

```basic
2406–2411 (read 6 fields: server, port, callsign, baud, name, grid)
2412 close 4:close 15
```

### Write Config (Lines 2430–2439)

```basic
2430 open 15,8,15,"s0:hamlog.cfg":close 15
2431 open 4,8,4,"hamlog.cfg,s,w"
```
`"s0:hamlog.cfg"` scratches (deletes) the old file. Then opens for write and saves all fields.

### Read Index (Lines 2450–2461)

```basic
2454 input#4,rc
2455 input#4,li$
2456 if not(st and 64) then input#4,dc
2457 if not(st and 64) then input#4,mx
2458 if not(st and 64) then input#4,dn
2459 if not(st and 64) then input#4,dk
```
`ST AND 64` checks the status variable for end-of-file. This provides backwards compatibility — older index files with fewer fields won't cause errors. Each field is only read if EOF hasn't been reached.

### Count Queue (Lines 2480–2491)

```basic
2485 if st and 64 then 2490
2486 input#4,qc$,qb$,qm$,qf$,qd$,qt$,qs$,qr$,qo$,qn$
2487 if st and 64 then pq=pq+1:goto 2490
2488 pq=pq+1:goto 2485
```
Reads the queue file record by record just to count entries. The double EOF check (before and after INPUT#) handles the last-record edge case.

---

## Setup Wizard (Lines 2500–2588)

Runs on first boot when no HAMLOG.CFG exists. Prompts for callsign, optionally connects to server for QRZ lookup (name, grid), configures server IP/port, selects disk type (D81 or D64), saves config and creates empty index.

---

## Config Editor (Lines 2600–2655)

```basic
2615 print "  8. disk type: d";dk
2616 print:print "  disk #";dn;" | ";rc;"/";mx;" (";int(rc/mx*100);"%)"
2617 print " enter number to edit (0=done):"
2618 get w$:if w$="" then 2618
```
Numbered menu for editing all settings. Option 7 triggers archive disk creation. Option 8 toggles between D81 and D64 format (with safety check — can't switch to D64 if >600 records).

```basic
2627 if w$="8" then dk=145-dk:if dk=81 then mx=3500:goto 2600
```
Toggle trick: `145 - 81 = 64`, `145 - 64 = 81`. Alternates between D81 and D64.

---

## Archive Disk (Lines 2670–2701)

```basic
2690 td=dn+1:gosub 1830:if ef then return
2691 print:print " formatting..."
2692 open 15,8,15,"n:hamlog,hl":close 15
2693 dn=td:rc=0:dc=0:li$="0":pq=0:mx=3600:if dk=64 then mx=700
```
1. Mount next disk (or prompt for swap)
2. Format with CBM DOS NEW command (`"n:diskname,id"`)
3. Reset all counters, set capacity for new disk type
4. Save config + index
5. Create empty REL files by opening and immediately closing them

---

## Splash Screen & Morse Code (Lines 2710–2769)

```basic
2710–2733 (ASCII art antenna and branding)
2735 for i=0to149:read a:poke 49664+i,a:next
2736 poke 54276,0:poke 54296,15:poke 54272,212:poke 54273,44:poke 54277,0:poke 54278,240
2737 if peek(197)<>64 then 2737
2738 sys 49664:get w$
```
Loads the Morse code player ML routine into $C200 (49664). Configures SID voice 1:
- 54296 = volume 15 (max)
- 54272/54273 = frequency (middle pitch)
- 54277/54278 = attack/decay/sustain/release envelope (fast attack, long decay)

`PEEK(197)` reads the keyboard matrix — 64 means no key pressed. Waits for any held key to be released before starting Morse playback. `SYS 49664` runs the Morse player which plays "CQ" in Morse code while checking for keypress to abort.

### Morse DATA (Lines 2760–2769)

The DATA statements encode the Morse player machine language. The last few bytes encode the Morse patterns:
```
data 7,1,13,3,14,15,1,1,1,1,0
data 1,3,0,3,3,255
```
These encode dot/dash patterns for CQ with inter-character spacing. 255 = end marker.

---

## ACIA Baud Rate (Lines 2870–2875)

```basic
2870 br=val(bd$):bc=30:if br=300 then bc=22
2871 if br=1200 then bc=24
2872 if br=2400 then bc=26
2873 if br=4800 then bc=28
2874 if br=19200 then bc=31
2875 poke 56835,bc:return
```
Maps baud rate values to ACIA control register values. POKE to $DE03 (56835). Default `bc=30` = 9600 baud. The values are the 6551 ACIA baud rate divisor codes.

---

## RS232 I/O Subroutines (Lines 2880–2892)

### Send String (Lines 2880–2881)

```basic
2880 if hw=0 then print#2,s$;:return
2881 for qi=1tolen(s$):poke 49392,asc(mid$(s$,qi,1)):sys 49203:next:return
```
- **KERNAL** (`hw=0`): `PRINT#2` sends the string to device 2 (userport RS232)
- **SwiftLink** (`hw=1`): Send each byte individually: POKE the byte to the I/O location (49392 = $C0F0), then `SYS 49203` calls the ML SEND routine which writes to the ACIA data register and waits for TX ready

### Get Character (Lines 2890–2892)

```basic
2890 if hw=0 then get#2,a$:return
2891 sys 49217:a=peek(49392):a$="":if a>0 then a$=chr$(a)
2892 return
```
- **KERNAL**: `GET#2` reads one character from device 2
- **SwiftLink**: `SYS 49217` calls the ML GET routine which reads from the NMI ring buffer (NOT directly from the ACIA — that would cause race conditions with the NMI handler)

---

## Machine Language DATA (Lines 2900–2915)

### ACIA Driver — Lines 2900–2909 (146 bytes at $C000)

The ML driver provides three entry points:
- **INIT ($C000 / 49152)**: Saves old NMI vector, hooks custom NMI handler, initializes ring buffer pointers, sets ACIA command register to $09 (RX NMI enabled, TX IRQ disabled)
- **SEND ($C033 / 49203)**: Reads byte from $C0F0, waits for ACIA TX ready (bit 4 of status register), writes to ACIA data register
- **GET ($C041 / 49217)**: Checks if ring buffer has data (write pointer != read pointer), if so reads one byte from ring buffer into $C0F0, else writes 0

The NMI handler (at $C071): triggered by ACIA receive interrupt, reads the byte from ACIA data register ($DE00), stores in 256-byte ring buffer at $C100, advances write pointer.

**Critical**: Command register MUST be $09 (binary: 00001001). Setting bit 2 ($05) enables TX IRQ, which fires continuously when the transmit buffer is empty, causing an NMI storm that locks the machine.

### ML Readline — Lines 2910–2915 (83 bytes at $C300)

Reads complete lines from the NMI ring buffer into a separate buffer at $C200 (49664). Returns the line length at $C0F0 (49392). Handles CR/LF line endings, discards nulls. This is dramatically faster than the BASIC character-by-character approach because it avoids the ~180ms GOSUB overhead per character.

---

## Key Concepts & Gotchas

### 1. The 40-Column Rule
Never print exactly 40 characters on one line. The C64 screen is 40 columns, but printing 40 characters causes the VIC-II to treat it as a 2-row logical line. This shifts everything below it down by one row, corrupting the screen layout. Always limit to 39 characters.

### 2. REL File Two-Half Format
CBM DOS `INPUT#` reads until it hits a CR (carriage return), not until the record boundary. A 168-byte record would be read as one giant string, hitting the 255-character limit. Solution: store each record as two 83-byte halves, each terminated by CR. Read with two `INPUT#` calls. The two halves are seamlessly concatenated for field extraction.

### 3. INPUT# Strips Leading Spaces
A documented but often-forgotten C64 behavior. When the second half of a record starts with spaces (common for empty comment fields), `INPUT#` silently removes them. Fix: check the length and left-pad with spaces from `s9$`.

### 4. The POSITION Command
```basic
print#15,"p"+chr$(channel)+chr$(lo)+chr$(hi)+chr$(byte)
```
Sets the file pointer for REL file access. The record number is split into low byte (`rn AND 255`) and high byte (`INT(rn/256)`). **Do NOT add +1 to the high byte** — the 1581 DOS uses the value directly without subtracting.

### 5. GOSUB Stack Management
The C64 has a limited GOSUB return stack (~24 levels). Long-running operations (online/offline/sync) that are called from the main loop with `GOSUB` can accumulate stack entries through nested subroutine calls. Solution: use `GOTO` from the main loop for these operations, and `GOTO 102` to return to the main loop instead of `RETURN`.

### 6. Shared Array Hazard
The `fx()` array is used by BOTH the spot display (mapping filtered indices to spot array positions) AND the log display (mapping page positions to record numbers). Switching screens without rebuilding `fx()` causes subscript errors because log record numbers (e.g., 3500) are used as spot array indices (max 20).

### 7. RS232 Buffer Pre-allocation
Opening device 2 (RS232) allocates 512 bytes at the top of BASIC RAM. If done after DIM or variable assignment, this allocation overwrites existing data. The fix is absolute: line 1 of the program opens device 2 before anything else exists.

### 8. Variable Naming Discipline
With only 2-character variable names and global scope, naming collisions are a real danger. Loop counters are especially risky — the ML readline uses `qi` specifically to avoid conflicting with the `i` used by spot/log/sync loops. Temporary variables like `w$` are reused everywhere but only within non-overlapping scopes.

### 9. CHR$ Color Codes
| Code | Color |
|------|-------|
| CHR$(5) | White |
| CHR$(18) | Reverse On |
| CHR$(30) | Green |
| CHR$(146) | Reverse Off |
| CHR$(147) | Clear Screen |
| CHR$(151) | Dark Gray |
| CHR$(154) | Light Blue |
| CHR$(155) | Light Gray |
| CHR$(158) | Yellow |
| CHR$(159) | Cyan |

### 10. Device & Channel Numbers
| Device | Purpose |
|--------|---------|
| 2 | RS232 modem (userport KERNAL or SwiftLink ACIA) |
| 8 | Disk drive (1541/1571/1581/SD2IEC) |

| Channel | Purpose |
|---------|---------|
| 3 | DAT file (or SUM file in some routines) |
| 4 | Config / Index / Queue file |
| 5 | SUM file (when DAT is on channel 3) |
| 15 | Disk command channel (POSITION, scratch, format, CD) |

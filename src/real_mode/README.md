# Real Mode Stages (16-bit)

## Stage 1a - MBR Boot Sector (stage1a.S)

**Size:** Exactly 512 bytes  
**Location:** 0x7C00  
**Purpose:** Initial boot sector loaded by BIOS

### Responsibilities:
1. Initialize segment registers and stack
2. Enable A20 line (fast gate method for QEMU)
3. Load Stage 1b from disk (sector 1+) using INT 13h extended read
4. Jump to Stage 1b at 0x8000

### Key Features:
- Uses Disk Address Packet (DAP) for LBA addressing
- Dynamically calculates Stage 1b sector count via linker
- Ends with boot signature 0xAA55

## Stage 1b - Extended Real Mode (stage1b.S)

**Size:** Up to 4KB  
**Location:** 0x8000  
**Purpose:** Collect system information and transition to protected mode

### Implementation:

#### 1. Hello World Output
```
Uses BIOS INT 10h (teletype mode) to display:
"ArtInium Stage1b - Hello World!"
```
- Demonstrates BIOS services are working
- Provides visual feedback that Stage 1b loaded successfully
- Helper function `print_string` for easy text output

#### 2. VGA/VBE Framebuffer Setup
Queries VESA BIOS Extensions for graphics capabilities:
- **INT 10h, AX=4F00h** - Get VBE controller info
- **INT 10h, AX=4F01h** - Get mode info for 1024x768x16
- **INT 10h, AX=4F02h** - Set VBE mode with linear framebuffer

Stores information in `vbe_info_block` and `mode_info_block` for kernel use.

#### 3. E820 Memory Map
Collects complete system memory layout:
- Uses **INT 15h, EAX=E820h** with "SMAP" signature
- Iterates through all memory regions
- Stores up to 32 entries (24 bytes each)
- Counts valid entries in `memory_map_count`

Memory map format per entry:
```
Offset  Size  Description
0       8     Base address (64-bit)
8       8     Length (64-bit)
16      4     Type (1=usable, 2=reserved, etc.)
20      4     Extended attributes
```

#### 4. Protected Mode Transition

**GDT Setup:**
- Null descriptor (required)
- Code segment: 0x08, 4GB flat, executable, readable
- Data segment: 0x10, 4GB flat, writable

**Transition Steps:**
1. Disable interrupts (CLI)
2. Load GDT with LGDT instruction
3. Set CR0.PE bit (bit 0) to enable protected mode
4. Far jump to flush pipeline and load CS with code selector (0x08)
5. Set up all segment registers with data selector (0x10)
6. Restore stack pointer
7. Jump to Stage 2 at 0x10000

### Error Handling
- **vga_error:** VBE query or mode set failed
- **e820_error:** Memory map collection failed
- All errors halt with error message via BIOS

### Helper Functions

**print_string(SI = string pointer)**
- Null-terminated string output
- Uses INT 10h, AH=0Eh (teletype)

**print_hex16(AX = 16-bit value)**
- Displays hex value with newline
- Useful for debugging (e.g., memory entry count)

### Data Buffers
- `vbe_info_block` - 512 bytes for VBE controller info
- `mode_info_block` - 256 bytes for mode information
- `memory_map` - 768 bytes (32 × 24-byte entries)
- `memory_map_count` - Number of valid E820 entries

## Memory Layout

Real mode memory layout is defined in [linker_scripts](../../linker_scripts/README.md) readme.

```
0x7C00 - 0x7DFF   Stage 1a (512 bytes)
0x8000 - 0x8FFF   Stage 1b (up to 4KB)
0x9000 - 0x9FFF   Stack space
```

## Notes

- All code runs in **16-bit real mode** with BIOS services available
- Once in protected mode, BIOS interrupts are no longer accessible
- Stage 2 must implement its own drivers for screen, disk, etc.
- The GDT is minimal; Stage 2 can replace it if needed

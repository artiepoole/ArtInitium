# ArtInium

Custom x86_32 Bootloader for QEMU - A GRUB Replacement

Written for Academic Purposes in AT&T Assembly and Zig 0.15.2

## Overview

ArtInium is a multi-stage bootloader that replaces GRUB for x86_32 QEMU environments. It demonstrates the complete boot process from BIOS handoff to protected mode kernel loading.

## Architecture

### Stage 1a (512 bytes @ 0x7C00)
- MBR boot sector loaded by BIOS
- Enables A20 line for >1MB memory access
- Loads Stage 1b from disk using BIOS INT 13h
- Jumps to Stage 1b at 0x8000

### Stage 1b (up to 4KB @ 0x8000)
- **Hello World message** - Displays boot message via BIOS INT 10h
- **VGA/VBE detection** - Queries and sets up VBE framebuffer mode (1024x768x16)
- **E820 memory map** - Collects system memory layout from BIOS
- **Protected mode transition** - Sets up GDT and switches to 32-bit mode
- Jumps to Stage 2 at 0x10000

### Stage 2 (@ 0x10000 / 64KB)
- 32-bit protected mode code (written in Zig)
- Will contain storage drivers (IDE, AHCI, etc.)
- Loads and launches the kernel
- Currently: stub implementation

## Building

```bash
# Make sure Zig 0.15.2 is in PATH or use the test script
zig build build_all
```

This creates:
- `zig-out/bin/ArtInium.16` - Combined Stage 1a + 1b (16-bit real mode)
- `zig-out/bin/ArtInium.32` - Stage 2 (32-bit protected mode)

## Testing in QEMU

Use the provided test script:

```bash
./test-qemu.sh
```

This will:
1. Build all stages
2. Create a bootable disk image
3. Launch QEMU with the bootloader

Press `Ctrl+A` then `X` to exit QEMU.

## Memory Layout

```
0x00000000 - 0x000003FF   Interrupt Vector Table (IVT)
0x00000400 - 0x000004FF   BIOS Data Area (BDA)
0x00007C00 - 0x00007DFF   Stage 1a (MBR - 512 bytes)
0x00008000 - 0x00008FFF   Stage 1b (up to 4KB)
0x00009000 - 0x00009FFF   Stack space
0x00010000 - 0x000FFFFF   Stage 2 (32-bit protected mode)
0x00100000+               Kernel space (1MB+)
```

## Features Implemented

✅ MBR boot sector with A20 enable  
✅ Multi-sector Stage 1b loading  
✅ BIOS text output (Hello World)  
✅ VBE framebuffer detection and setup  
✅ E820 memory map collection  
✅ GDT setup and protected mode switch  
✅ Clean handoff to 32-bit Stage 2  

## TODO

- [ ] Implement Stage 2 disk drivers
- [ ] Add file system support (FAT32/ext2)
- [ ] Kernel loading and parsing
- [ ] Pass boot information structure to kernel
- [ ] Add error handling and recovery

## License

MIT License - See LICENSE file

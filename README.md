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
- **E820 memory map** - Collects system memory layout from BIOS
- **VGA/VBE detection** - Queries available VBE modes (doesn't set mode yet)
- **Boot info preparation** - Prepares structure with memory map and VBE mode info
- **Protected mode transition** - Sets up GDT and switches to 32-bit mode
- Jumps to Stage 2 at 0x10000

### Stage 2 (@ 0x10000 / 64KB)
- 32-bit protected mode code (written in Zig)
- **Video mode setup** - Uses Bochs VBE extensions to set graphics mode in protected mode
- Will contain storage drivers (IDE, AHCI, etc.)
- Loads and launches the kernel
- Currently: demonstrates video mode switching using boot info from Stage 1b

## Building

```bash
# Make sure Zig 0.15.2 is in PATH or use the test script
zig build build_all
```

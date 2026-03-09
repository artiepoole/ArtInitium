/* ArtInium - MultiArch Bootloader for qemu
 *
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Artie Poole */

OUTPUT_ARCH(i386)
/*OUTPUT_FORMAT("binary")*/

OUTPUT_FORMAT(elf32-i386)
ENTRY(Artinium_32_entry)

MEMORY
{
    USABLE_LOW : ORIGIN = 0x10000, LENGTH = 0x8fc00 /* 0x9fc00 */
}

SECTIONS {
    . = 0x10000; /* 64 KB */

    __stage2_start = .;
    
    /* Stage2 Header - must be first! */
    .stage2_header : {
        LONG(0x49545241);                    /* "ARTI" magic in little-endian */
        LONG(__stage2_file_end - __stage2_start); /* actual file size (excluding .bss) */
    } > USABLE_LOW
    . = 0x10010; /* 64 KB + 16 bytes for header */
    /* Entry point must be immediately after header */
    .text : ALIGN(1)
    {
        KEEP(*(.text.entry))   /* FORCE FIRST */
        *(.text*)
    } > USABLE_LOW
    .rodata : ALIGN(1) { *(.rodata*) } > USABLE_LOW
    .data : ALIGN(1) { *(.data*) } > USABLE_LOW

    __stage2_file_end = .;  /* End of actual file data */

    .bss : { *(.bss*) *(COMMON) } > USABLE_LOW
    __stage2_end = .;       /* End including .bss (for memory layout) */

    /* Assert Stage2 does not exceed 0x100000, i.e. doesn't bleed into kernel address space */
/*    ASSERT(__stage2_end < 0x100000, "Stage2 exceeds 1MB boundary")*/
}

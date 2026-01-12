/* ArtInium - Bootloader for x86_32 qemu
 *
 * SPDX-License-Identifier: MIT
 * Copyright (c) ${YEAR} Artie Poole */

OUTPUT_ARCH(i386)
OUTPUT_FORMAT("binary")
ENTRY(Artinium_32_entry)

SECTIONS {
    . = 0x10000; /* 64 KB */
    MAGIC = 0x49545241;                     /* "ARTI" in little-endian */
    STAGE2_SIZE  = __stage2_end - __stage2_start; /* dynamic size of 32-bit code */

    __stage2_start = .;
    .text : { *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    .bss : { *(.bss*) }
    __stage2_end = .;

    /* Assert Stage2 does not exceed 0x100000, i.e. doesn't bleed into kernel address space */
    ASSERT(__stage2_end < 0x100000, "")
}

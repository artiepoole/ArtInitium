/* ArtInitium - MultiArch Bootloader for qemu
 *
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Artie Poole */

OUTPUT_ARCH(aarch64)
OUTPUT_FORMAT("elf64-littleaarch64") /* ELF for arm64 */
ENTRY(arm64_start)

/* arbitrary start address - will aim to make it PIE eventually */
START_ADDR = 0x40080000;

SECTIONS
{
    /* Place .text at the custom start address */
    . = START_ADDR;
    .text :
    {
        *(.text .text.*)
    }

    .rodata :
    {
        *(.rodata .rodata.*)
    }

    .data :
    {
        *(.data .data.*)
    }

    .bss :
    {
        *(.bss .bss.* COMMON)
    }

    /* Discard unwanted sections */
    /DISCARD/ :
    {
        *(.note* .comment .eh_frame .gnu*)
    }
}

/* ArtInium - Bootloader for x86_32 qemu
 *
 * SPDX-License-Identifier: MIT
 * Copyright (c) ${YEAR} Artie Poole */

OUTPUT_ARCH(i386)
OUTPUT_FORMAT("binary")        /* produce a flat binary, not ELF */
ENTRY(__stage_1a_start)                  /* entry point symbol from boot.s */
SECTIONS
{
    /* origin: BIOS loads boot sector at 0x7C00 */
    . = 0x7C00;

    .stage1a : {
        *(.stage1a*)
    }
    ASSERT(. <= 0x7C00 + 512, "Stage1a too large! Exceeds 512B limit")


    . = 0x8000;                 /* 32 KB */
    __stage1b_start = .;
    .stage1b : { *(.stage1b*) }
    __stage1b_end = .;

    __stage1b_size = __stage1b_end - __stage1b_start;
    STAGE1B_SECTORS = (__stage1b_size + 511)/512;

    /* Assert Stage1b does not exceed 0x9000, i.e. doesn't bleed into 32-bit code space */
    ASSERT(__stage1b_end < 0x9000, "Stage1b too large! Exceeds 4 KB limit")
}

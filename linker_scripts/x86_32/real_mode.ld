/* ArtInitium - MultiArch Bootloader for qemu
 *
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Artie Poole */

OUTPUT_ARCH(i386)
OUTPUT_FORMAT(elf32-i386)      /* ELF output so objcopy can extract sections */
ENTRY(__stage_1a_start)                  /* entry point symbol from boot.s */

MEMORY
{
    BOOT : ORIGIN = 0x7C00, LENGTH = 512
    STAGE1B : ORIGIN = 0x8000, LENGTH = 31K /* Allow 1kb for stack */
}

SECTIONS
{
    .stage1a : ALIGN(1) {
        KEEP(*(.stage1a*))
    } > BOOT

    .stage1b : AT(.)  {
        KEEP(*(.stage1b.code*))
        KEEP(*(.stage1b.data*))
    } > STAGE1B

    __stage1b_start = 0x8000;
    __stage1b_end = __stage1b_start + SIZEOF(.stage1b);

    /* compute sectors as a constant */
    STAGE1B_SECTORS = (__stage1b_end - __stage1b_start + 511)/512;

}

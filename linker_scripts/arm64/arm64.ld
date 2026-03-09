OUTPUT_ARCH(arm64)
OUTPUT_FORMAT("binary")        /* produce a flat binary, not ELF */
ENTRY(arm64_start)                  /* entry point symbol from boot.s */

MEMORY
{
    /* I have no idea how this is laid out in qemu yet - is it defined by device tree? */
    BOOT : ORIGIN = 0x7C00, LENGTH = 512
    STAGE1B : ORIGIN = 0x8000, LENGTH = 31K /* Allow 1kb for stack */
    STAGE2 : ORIGIN = 0x10000, LENGTH = 0x8fc00 /* 0x9fc00 */
}
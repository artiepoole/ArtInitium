/* ArtInium - MultiArch Bootloader for qemu
 *
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Artie Poole */


#ifndef STAGE1B_SECTORS
#error STAGE1B_SECTORS not defined
#endif

.code16
.section .stage1a,"ax"
.global __stage_1a_start

.extern STAGE1B_SECTORS
.word STAGE1B_SECTORS

/* -------------------------------------------------
 * This stage1 bootloader just loads stage 1b and
 * enables A20. Loads 32*16kb - needs to be adjusted
 * ------------------------------------------------- */
_start:
__stage_1a_start:
    cli
    xor %ax, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss
    mov $0x7FFF, %sp
    sti


/* -------------------------------------------------
 * Enable A20 (Fast Gate, QEMU-compatible)
 * ------------------------------------------------- */
enable_a20:
    inb $0x92, %al
    orb $0x02, %al
    outb %al, $0x92


/* -------------------------------------------------
 * Load Stage 1b using INT 13h Extensions (LBA)
 * ------------------------------------------------- */
load_stage1b:
    /* Clear screen - set video mode 0x03 (80x25 color text) */
    mov $0x00, %ah
    mov $0x03, %al
    int $0x10

    /* Print 'L' to show we're loading */
    mov $0x0E, %ah
    mov $'L', %al
    int $0x10

    /* Set ES:BX to 0x0000:0x8000 (physical address 0x8000) */
    xor %ax, %ax
    mov %ax, %es
    mov $0x8000, %bx

    mov $0x42, %ah       /* INT 13h extended read */
    mov $0x80, %dl       /* boot drive */
    lea dap, %si
    int $0x13
    jc disk_error_carry

    /* Print 'R' to show read completed */
    mov $0x0E, %ah
    mov $'R', %al
    int $0x10

    /* Verify something was loaded at 0x0000:0x8000 */
    /* ES is already 0x0000 from earlier, BX is 0x8000 */
    mov %es:(%bx), %al
    cmp $0x00, %al
    je disk_error_zero        /* If first byte is 0, likely read failed */

    /* Print 'J' before jumping */
    push %ax
    mov $0x0E, %ah
    mov $'J', %al
    int $0x10
    pop %ax

/* -------------------------------------------------
 * Jump to Stage 1b
 * ------------------------------------------------- */
    ljmp $0x0000, $0x8000

disk_error_carry:
    mov $0x0E, %ah
    mov $'C', %al
    int $0x10
    jmp disk_error

disk_error_zero:
    mov $0x0E, %ah
    mov $'Z', %al
    int $0x10
    jmp disk_error

disk_error:
    cli
.hang:
    hlt
    jmp .hang

/* -------------------------------------------------
 * Disk Address Packet (DAP)
 * ------------------------------------------------- */

dap:
    .byte 0x10            /* size */
    .byte 0x00
    .word STAGE1B_SECTORS   /* number of sectors, linker computed */
    .word 0x8000          /* offset */
    .word 0x0000          /* segment */
    .quad 0x0000000000000001      /* starting LBA (8 bytes) */

/* -------------------------------------------------
 * Boot signature
 * ------------------------------------------------- */
.org 510
.word 0xAA55

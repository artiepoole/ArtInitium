/* ArtInium - Bootloader for x86_32 qemu
 *
 * SPDX-License-Identifier: MIT
 * Copyright (c) ${YEAR} Artie Poole */


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

__stage_1a_start:
    cli
    xor %ax, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss
    mov $0x7C00, %sp
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
    mov $0x8000, %bx
    mov %bx, %es
    xor %bx, %bx

    mov $0x42, %ah       /* INT 13h extended read */
    mov $0x80, %dl       /* boot drive */
    lea dap, %si
    int $0x13
    jc disk_error

/* -------------------------------------------------
 * Jump to Stage 1b
 * ------------------------------------------------- */
    ljmp $0x0000, $0x8000

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
    .word 0x0000          /* offset */
    .word 0x8000          /* segment */
    .long 0x00000001      /* starting LBA */

/* -------------------------------------------------
 * Boot signature
 * ------------------------------------------------- */
.org 510
.word 0xAA55

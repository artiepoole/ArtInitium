/* ArtInium - Bootloader for x86_32 qemu
 *
 * SPDX-License-Identifier: MIT
 * Copyright (c) ${YEAR} Artie Poole */

.section .stage1b,"ax"
.code16
.global stage1b_entry

/* -------------------------------------------------
 * Stage1b Entry Point (Stage 1a jumps here)
 * ------------------------------------------------- */
stage1b_entry:



/* -------------------------------------------------
 * Set the stack pointer
 * ------------------------------------------------- */
    xor %ax, %ax
    mov %ax, %ss
    mov $0x9FFF, %sp    /* new stack for Stage2 */




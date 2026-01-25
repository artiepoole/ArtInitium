/* ArtInium - Bootloader for x86_32 qemu
 *
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Artie Poole */

.section .stage1b,"ax"
.code16
.global stage1b_entry

/* -------------------------------------------------
 * Stage1b Entry Point (Stage 1a jumps here)
 * ------------------------------------------------- */
stage1b_entry:
    cli
    xor %ax, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %ss
    mov $0x9FFF, %sp    /* new stack for Stage2 */
    sti


    /* Print '1' immediately to show we reached stage1b */
    mov $0x0E, %ah
    mov $'1', %al
    int $0x10

    /* Print 'B' */
    mov $0x0E, %ah
    mov $'B', %al
    int $0x10

/* -------------------------------------------------
 * Print Hello World message
 * ------------------------------------------------- */
print_hello:
    mov $hello_msg, %si
    call print_string

/* -------------------------------------------------
 * Get VGA framebuffer information
 * Query VESA VBE for framebuffer details
 * ------------------------------------------------- */
get_vga_info:
    mov $vga_msg, %si
    call print_string
    /* Get VBE Controller Information */
    mov $0x4F00, %ax
    mov $vbe_info_block, %di
    int $0x10

    cmp $0x004F, %ax
    jne vga_error

    /* Get VBE Mode Information for mode 0x117 (1024x768x16) */
    mov $0x4F01, %ax
    mov $0x0117, %cx
    mov $mode_info_block, %di
    int $0x10

    cmp $0x004F, %ax
    jne vga_error


    /* Set VBE Mode */
    /*mov $0x4F02, %ax */
    /*mov $0x4117, %bx      /* mode 0x117 with LFB bit set */
    /*int $0x10 */

    cmp $0x004F, %ax
    jne vga_error

    mov $vga_ok_msg, %si
    call print_string

/* -------------------------------------------------
 * Get Memory Map (E820)
 * Query BIOS for memory regions
 * ------------------------------------------------- */
get_memory_map:
    mov $mem_msg, %si
    call print_string

    xor %ebx, %ebx
    mov $memory_map, %di
    xor %bp, %bp          /* entry count */

e820_loop:
    mov $0xE820, %eax
    mov $24, %ecx         /* buffer size */
    mov $0x534D4150, %edx /* "SMAP" signature */
    int $0x15

    jc e820_done          /* carry set = end of list or error */

    cmp $0x534D4150, %eax /* verify SMAP signature */
    jne e820_error

    cmp $0, %ecx          /* skip zero-length entries */
    je e820_skip

    /* Valid entry, increment counter and pointer */
    inc %bp
    add $24, %di

    cmp $32, %bp          /* limit to 32 entries */
    jge e820_done

e820_skip:
    test %ebx, %ebx       /* ebx=0 means end of list */
    jnz e820_loop

e820_done:
    mov %bp, (memory_map_count)

    /* Print entry count */
    mov $mem_ok_msg, %si
    call print_string

    mov %bp, %ax
    call print_hex16

/* -------------------------------------------------
 * Enable Protected Mode
 * ------------------------------------------------- */
enter_protected_mode:
    mov $pm_msg, %si
    call print_string

    cli

    /* Load GDT */
    lgdt gdt_descriptor

    /* Enable protected mode bit in CR0 */
    mov %cr0, %eax
    or $0x1, %eax
    mov %eax, %cr0

    /* Far jump to flush pipeline and load CS */
    ljmp $0x08, $protected_mode_entry

/* -------------------------------------------------
 * Error Handlers
 * ------------------------------------------------- */
vga_error:
    mov $vga_err_msg, %si
    call print_string
    jmp halt

e820_error:
    mov $mem_err_msg, %si
    call print_string
    jmp halt

halt:
    cli
.halt_loop:
    hlt
    jmp .halt_loop

/* -------------------------------------------------
 * Print String (SI = pointer to null-terminated string)
 * Uses BIOS INT 10h in 16-bit real mode
 * ------------------------------------------------- */
print_string:
    pusha
    mov $0x0E, %ah        /* BIOS teletype output */
.print_loop:
    lodsb                 /* load byte from [SI] into AL, increment SI */
    test %al, %al         /* check for null terminator */
    jz .print_done
    int $0x10             /* BIOS video interrupt */
    jmp .print_loop
.print_done:
    popa
    ret

/* -------------------------------------------------
 * Print 16-bit hex value in AX
 * ------------------------------------------------- */
print_hex16:
    pusha
    mov $4, %cx           /* 4 hex digits */
    mov %ax, %dx
.hex_loop:
    rol $4, %dx           /* rotate left 4 bits */
    mov %dl, %al
    and $0x0F, %al        /* get low nibble */
    add $'0', %al
    cmp $'9', %al
    jle .hex_print
    add $7, %al           /* A-F */
.hex_print:
    mov $0x0E, %ah
    int $0x10
    dec %cx
    jnz .hex_loop

    /* Print newline */
    mov $0x0E, %ah
    mov $'\r', %al
    int $0x10
    mov $'\n', %al
    int $0x10

    popa
    ret

/* -------------------------------------------------
 * 32-bit Protected Mode Entry Point
 * ------------------------------------------------- */
.code32
protected_mode_entry:
    /* Set up segment registers for 32-bit mode */
    mov $0x10, %ax        /* data segment selector */
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss

    mov $0x9FFF, %esp     /* restore stack in protected mode */

    /* TODO: Load Stage 2 from disk into 0x10000 */
    /* For now, just attempt to jump to Stage 2 */

    /* Jump to Stage 2 at 0x10000 */
    jmp $0x08, $0x10000

    /* Should never reach here */
    cli
.pm_halt:
    hlt
    jmp .pm_halt

/* -------------------------------------------------
 * Global Descriptor Table (GDT)
 * ------------------------------------------------- */
.align 8
gdt_start:
    /* Null descriptor */
    .quad 0x0000000000000000

    /* Code segment descriptor */
    .word 0xFFFF          /* limit low */
    .word 0x0000          /* base low */
    .byte 0x00            /* base middle */
    .byte 0x9A            /* access: present, ring 0, code, executable, readable */
    .byte 0xCF            /* flags + limit high: 4KB granularity, 32-bit */
    .byte 0x00            /* base high */

    /* Data segment descriptor */
    .word 0xFFFF          /* limit low */
    .word 0x0000          /* base low */
    .byte 0x00            /* base middle */
    .byte 0x92            /* access: present, ring 0, data, writable */
    .byte 0xCF            /* flags + limit high: 4KB granularity, 32-bit */
    .byte 0x00            /* base high */
gdt_end:

gdt_descriptor:
    .word gdt_end - gdt_start - 1    /* GDT size */
    .long gdt_start                   /* GDT base address */

/* -------------------------------------------------
 * Data Section - Strings and Buffers
 * ------------------------------------------------- */
hello_msg:
    .asciz "\r\nArtInium Stage1b - Hello World!\r\n"

vga_msg:
    .asciz "Querying VGA/VBE...\r\n"

vga_ok_msg:
    .asciz "VGA OK\r\n"

vga_err_msg:
    .asciz "VGA Error!\r\n"

mem_msg:
    .asciz "Getting memory map...\r\n"

mem_ok_msg:
    .asciz "Memory map OK - Entries: 0x"

mem_err_msg:
    .asciz "Memory map Error!\r\n"

pm_msg:
    .asciz "Entering protected mode...\r\n"

/* -------------------------------------------------
 * Memory buffers
 * ------------------------------------------------- */
.align 4
vbe_info_block:
    .skip 512

mode_info_block:
    .skip 256

memory_map:
    .skip 768             /* 32 entries * 24 bytes */

memory_map_count:
    .word 0




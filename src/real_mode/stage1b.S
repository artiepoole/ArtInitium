/* ArtInium - Bootloader for x86_32 qemu
 *
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Artie Poole */

.section .stage1b.code,"ax"
.code16
.global stage1b_entry

.extern STAGE1B_SECTORS
.word STAGE1B_SECTORS

/* -------------------------------------------------
 * Stage1b Entry Point (Stage 1a jumps here)
 * ------------------------------------------------- */
stage1b_entry:
    cli
    xor %ax, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %ss
    mov $0x9FFF, %sp    /* stack grows down from 0x9FFF (see linker script) */
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
 * Query VGA/VBE modes (don't set yet)
 * Queries multiple modes and stores info for Stage 2
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

    /* Query multiple common VBE modes */
    xor %bp, %bp              /* mode counter */
    mov $vbe_mode_list, %si   /* mode list pointer */
    mov $vbe_modes_info, %di  /* destination for mode info */

.query_mode_loop:
    lodsw                     /* load mode number into AX */
    cmp $0xFFFF, %ax          /* check for terminator */
    je .query_done

    mov %ax, %cx              /* mode number to CX */
    push %si                  /* save mode list pointer */
    push %di                  /* save destination pointer */

    mov $0x4F01, %ax          /* Get VBE Mode Info */
    int $0x10

    pop %di                   /* restore destination */
    pop %si                   /* restore mode list */

    cmp $0x004F, %ax          /* check if mode query succeeded */
    jne .next_mode

    inc %bp                   /* increment mode counter */
    add $256, %di             /* move to next mode info block */

    cmp $8, %bp               /* limit to 8 modes */
    jge .query_done

.next_mode:
    jmp .query_mode_loop

.query_done:
    mov %bp, (vbe_mode_count)

    /* Print success message with mode count */
    mov $vga_ok_msg, %si
    call print_string

    mov %bp, %ax
    call print_hex16

/* -------------------------------------------------
 * Prepare Boot Info Structure for Stage 2
 * ------------------------------------------------- */
prepare_boot_info:
    mov $bios_info_struct, %di

    /* Set magic number "ARTI" = 0x41525449 */
    movl $0x41525449, %es:(%di)
    add $4, %di

    /* Memory map count (16-bit) */
    mov (memory_map_count), %ax
    mov %ax, %es:(%di)
    add $2, %di

    /* VBE mode count (16-bit) */
    mov (vbe_mode_count), %ax
    mov %ax, %es:(%di)
    add $2, %di

    /* Memory map pointer (32-bit) */
    movl $memory_map, %eax
    movl %eax, %es:(%di)
    add $4, %di

    /* VBE info pointer (32-bit) */
    movl $vbe_info_block, %eax
    movl %eax, %es:(%di)
    add $4, %di

    /* VBE modes pointer (32-bit) */
    movl $vbe_modes_info, %eax
    movl %eax, %es:(%di)
    add $4, %di

/* -------------------------------------------------
 * Load Stage2 Header
 * ------------------------------------------------- */
load_stage2_header:
    mov $stage2_load_msg, %si
    call print_string

    mov $STAGE1B_SECTORS, %ax
    add $0x1, %ax               /* stage2 first sector = STAGE1B_SECTORS + BOOT_SECTORS (=1)*/
    mov %ax, stage2_dap + 8  /* starting LBA = STAGE1B_SECTORS */

    /* Load sector 17 (header) into 0x10000 using INT 13h Extended Read */
    mov $0x42, %ah            /* INT 13h extended read */
    mov $0x80, %dl            /* boot drive */
    lea stage2_dap, %si       /* DS:SI points to DAP */
    int $0x13
    jc disk_read_error        /* Jump if carry flag set (error) */

    /* Verify MAGIC bytes at 0x10000 */
    mov $0x1000, %ax
    mov %ax, %es
    xor %bx, %bx

    /* Check "ARTI" magic (0x49545241 in little-endian) */
    mov %es:(%bx), %eax
    cmp $0x49545241, %eax
    jne magic_error

    /* Read STAGE2_SIZE (4 bytes after magic) */
    mov %es:4(%bx), %eax
    /* Store size in a safe location for later use */
    movl %eax, stage2_size

    /* Restore ES to 0 */
    xor %ax, %ax
    mov %ax, %es

    mov $stage2_ok_msg, %si
    call print_string

/* -------------------------------------------------
 * Calculate sectors needed and load full Stage2
 * ------------------------------------------------- */
load_full_stage2:
    mov $stage2_loading_msg, %si
    call print_string

    /* Calculate number of sectors: (size + 511) / 512 */
    movl stage2_size, %eax
    add $511, %eax            /* Round up */
    shr $9, %eax              /* Divide by 512 (shift right 9 bits) */

    /* Print number of sectors */
    push %ax                  /* Save sector count */
    mov $sectors_msg, %si
    call print_string
    pop %ax                   /* Restore sector count */
    call print_hex16

    /* Store total sector count */
    mov %ax, %cx              /* CX = total sectors remaining */
    mov $STAGE1B_SECTORS, %bx              /* BX = current LBA, start after stage1b */
    add $0x1, %bx              /* Stage2 starts at sector STAGE1B_SECTORS + BOOT_SECTORS (=1) */
    mov $0x1000, %di          /* DI = current segment (0x1000 = 0x10000) */

.load_loop:
    /* Check if we're done */
    test %cx, %cx
    jz .load_done

    /* Determine how many sectors to read this iteration (max 127) */
    mov %cx, %ax
    cmp $127, %ax
    jle .read_sectors
    mov $127, %ax             /* Limit to 127 sectors per read */

.read_sectors:
    /* Update DAP with current values */
    mov %ax, stage2_dap + 2   /* sector count */
    mov %di, stage2_dap + 6   /* segment */
    movl %ebx, stage2_dap + 8 /* LBA (low 32 bits) */

    /* Read sectors */
    push %ax                  /* Save sector count for this read */
    push %bx                  /* Save current LBA */
    push %cx                  /* Save remaining sectors */
    push %di                  /* Save current segment */

    mov $0x42, %ah            /* INT 13h extended read */
    mov $0x80, %dl            /* boot drive */
    lea stage2_dap, %si       /* DS:SI points to DAP */
    int $0x13
    jc disk_read_error        /* Jump if carry flag set (error) */

    pop %di                   /* Restore current segment */
    pop %cx                   /* Restore remaining sectors */
    pop %bx                   /* Restore current LBA */
    pop %ax                   /* Restore sector count for this read */

    /* Update for next iteration */
    sub %ax, %cx              /* Subtract sectors read from remaining */
    add %ax, %bx              /* Advance LBA */

    /* Advance segment: each sector is 512 bytes = 0x200 bytes = 0x20 paragraphs */
    shl $5, %ax               /* sectors * 32 (0x20) = paragraphs */
    add %ax, %di              /* Advance segment */

    jmp .load_loop

.load_done:
    mov $stage2_loaded_msg, %si
    call print_string

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
disk_read_error:
    mov $disk_err_msg, %si
    call print_string
    jmp halt

magic_error:
    mov $magic_err_msg, %si
    call print_string
    jmp halt

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

    mov $0x9FFF, %esp     /* stack at 0x9fc00, end of usable address space */
    mov $0x9fc00, %esp
    /* Jump to Stage 2 at 0x10010 (skip 8-byte header + 8-byte padding) */
    /* Using indirect call through memory to ensure 32-bit addressing */
    push $bios_info_struct
    call 0x10010

    /* Should never reach here */
    mov $load_fail_msg, %si
    call print_string
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
.section .stage1b.data,"aw"

hello_msg:
    .asciz "\r\nArtInium Stage1b - Hello World!\r\n"

vga_msg:
    .asciz "Querying VGA/VBE modes...\r\n"

vga_ok_msg:
    .asciz "VGA modes queried - Count: 0x"

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

stage2_load_msg:
    .asciz "Loading Stage2 header...\r\n"

stage2_ok_msg:
    .asciz "Stage2 header verified (ARTI magic OK)\r\n"

stage2_loading_msg:
    .asciz "Loading full Stage2...\r\n"

sectors_msg:
    .asciz "Loading sectors: 0x"

stage2_loaded_msg:
    .asciz "Stage2 loaded successfully\r\n"

disk_err_msg:
    .asciz "Disk read error!\r\n"

magic_err_msg:
    .asciz "Stage2 magic verification failed!\r\n"

load_fail_msg:
    .asciz "Shit. Stage2 didn't load...\r\n"

/* -------------------------------------------------
 * Variables
 * ------------------------------------------------- */
stage2_size:
    .long 0

/* Disk Address Packet (DAP) for loading Stage2 */
.align 4
stage2_dap:
    .byte 0x10            /* size of DAP */
    .byte 0x00            /* reserved */
    .word 1               /* number of sectors (will be updated dynamically) */
    .word 0x0000          /* offset (0x10000 = 0x1000:0x0000) */
    .word 0x1000          /* segment */
    .quad 0              /* starting LBA */

/* -------------------------------------------------
 * Memory buffers
 * ------------------------------------------------- */

/* Boot Info Structure for Stage 2 */
.align 4
bios_info_struct:
    .skip 96              /* BootInfo structure + padding */

.align 4
vbe_info_block:
    .skip 512

/* List of VBE modes to query */
.align 4
vbe_mode_list:
    .word 0x0117          /* 1024x768x16 */
    .word 0x0118          /* 1024x768x24 */
    .word 0x011A          /* 1024x768x32 */
    .word 0x011B          /* 1280x1024x16 */
    .word 0x011C          /* 1280x1024x24 */
    .word 0x011E          /* 1280x1024x32 */
    .word 0x0105          /* 1024x768x8 */
    .word 0x0107          /* 1280x1024x8 */
    .word 0xFFFF          /* terminator */

/* Storage for mode info blocks (256 bytes each, 8 modes max) */
.align 4
vbe_modes_info:
    .skip 2048            /* 256 * 8 modes */

.align 4
vbe_mode_count:
    .word 0

/* Legacy single mode info block - kept for compatibility */
.align 4
mode_info_block:
    .skip 256

.align 4
memory_map:
    .skip 768             /* 32 entries * 24 bytes */

.align 4
memory_map_count:
    .word 0




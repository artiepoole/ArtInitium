// ArtInium - Bootloader for x86_32 qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
//
const lib = @import("artlib");

const LOAD_MSG: []const u8 = "Loading 32-bit protected mode bootloader...\n";


pub export fn Artinium_32_entry() linksection(".text.entry") callconv(.c) noreturn
{
    // Write magic marker to VGA memory to verify we got here
    // VGA text mode buffer at 0xB8000
    asm volatile (
        \\ mov $0xB8000, %%edi
        \\ movw $0x4F32, (%%edi)
        \\ movw $0x0F32, (%edi)    /* '2' white on black */
        \\ movw $0x0F33, 2(%edi)   /* '3' white on black */
        \\ movw $0x0F34, 4(%edi)   /* '4' white on black */
        ::: .{ .edi = true });

    // TODO: implement Stage 2 bootloader
    // - Load kernel from disk
    // - Parse kernel headers
    // - Set up paging if needed
    // - Jump to kernel

    // For now, just halt
    while (true) {
        asm volatile ("hlt");
    }
}

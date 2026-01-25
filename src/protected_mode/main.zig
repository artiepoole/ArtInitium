// ArtInium - Bootloader for x86_32 qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
//
const lib = @import("artlib");

pub export fn Artinium_32_entry() noreturn {
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

// ArtInium - Bootloader for x86_32 qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

//
pub const BiosInfoHeader = extern struct {
    magic: u32,
    mmap_count: u16,
    vbe_mode_count: u16,
    mmap_ptr: u32, // call @ptrFromInt to get pointer
    vbe_info_ptr: u32, // call @ptrFromInt to get pointer
    vbe_modes_ptr: u32,
    _padding: [82]u8,
};


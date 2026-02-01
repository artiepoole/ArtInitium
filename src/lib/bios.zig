// ArtInium - Bootloader for x86_32 qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
//

pub const BiosHeaderMagic: u32 = 0x41525449; // ARTI boot info magic
//
pub const BiosInfoHeader = packed struct {
    magic: u32,
    mmap_count: u16,
    vbe_mode_count: u16,
    mmap_ptr: *MMapEntry,
    vbe_info_ptr: *VBEInfoBlock,
    vbe_modes_ptr: u32,
    // _padding: [82]u8,
};

pub const MMapEntry = packed struct {
    size: u32,
    base_addr: u64,
    length: u64,
    entry_type: u32,
};

pub const VBEInfoBlock = packed struct {
    signature: u32, // [4]u8 'VESA'
    version: u16,
    oem_string_ptr: u32,
    // capabilities: [4]u8,
    video_mode_ptr: u32,
    total_memory: u16,
    // _padding: [236]u8,
};

pub fn validate(boot_info: *const BiosInfoHeader) bool {
    return (boot_info.magic == BiosHeaderMagic);
}

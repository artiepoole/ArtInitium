// ArtInium - Bootloader for x86_32 qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
//

pub const BiosHeaderMagic: u32 = 0x41525449; // ARTI boot info magic
//
pub const BiosInfo = packed struct {
    magic: u32,
    flags: u32,
    checksum: u32,
    header_addr: u32,
    load_addr: u32,
    load_end_addr: u32,
    bss_end_addr: u32,
    entry_addr: u32,
};

pub fn validate(boot_info: *const BiosInfo) bool {
    return (boot_info.magic == BiosHeaderMagic);
}

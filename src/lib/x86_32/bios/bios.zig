// ArtInium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
//

pub const header = @import("bios_header.zig");
pub const mmap = @import("MMap.zig");
pub const vbe = @import("VBE.zig");
pub const log = @import("../../common/log.zig");

const BiosHeaderMagic: u32 = 0x41525449; // ARTI boot info magic

fn validate(boot_info: *const header.BiosInfoHeader) !void {
    try log.Logger.debug("Bios info structure at address: 0x{x}\n", .{@intFromPtr(boot_info)});
    if (!(boot_info.magic == BiosHeaderMagic)){
        return error.InvalidBiosHeaderMagic;
    }
}

pub fn parse_bios_headers(boot_info: *const header.BiosInfoHeader) !void {
    try validate(boot_info);
    try log.Logger.print("Parsing bios headers... ", .{});
    try mmap.parse_mmap_entries(boot_info.mmap_ptr, boot_info.mmap_count);
    try vbe.parse_vbe_entries(boot_info.vbe_info_ptr, boot_info.vbe_modes_ptr);
    try log.Logger.print("done\n", .{});
}
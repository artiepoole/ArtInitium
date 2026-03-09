// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

const std = @import("std");
const log = @import("../../common/log.zig");

pub const VBEInfoBlock = extern struct {
    signature: [4]u8, // e.g. VESA
    version: u16,
    oem_string_ptr_offset: u16,
    oem_string_ptr_segment: u16,
    capabilities: [4]u8,
    video_mode_ptr_offset: u16,
    video_mode_ptr_segment: u16,
    total_memory: u16,
    _padding: [236]u8,
};

pub const VideoModeInfo = extern struct {
    mode_attributes: u16,
    win_a_attributes: u8,
    win_b_attributes: u8,
    win_granularity: u16,
    win_size: u16,
    win_a_segment: u16,
    win_b_segment: u16,
    win_func_ptr: u32,
    bytes_per_scanline: u16,

    // VBE 1.2+
    x_resolution: u16,
    y_resolution: u16,
    x_char_size: u8,
    y_char_size: u8,
    number_of_planes: u8,
    bits_per_pixel: u8,
    number_of_banks: u8,
    memory_model: u8,
    bank_size: u8,
    number_of_image_pages: u8,
    reserved1: u8,

    // Direct Color fields (required for direct/6 and YUV/7 memory models)
    red_mask_size: u8,
    red_field_position: u8,
    green_mask_size: u8,
    green_field_position: u8,
    blue_mask_size: u8,
    blue_field_position: u8,
    reserved_mask_size: u8,
    reserved_field_position: u8,
    direct_color_mode_info: u8,

    // VBE 2.0+
    phys_base_ptr: u32,
    off_screen_mem_offset: u32,
    off_screen_mem_size: u16,

    // VBE 3.0+
    reserved2: [206]u8,
};

pub fn parse_vbe_entries(vbe_info_ptr: u32, vbe_modes_ptr: u32) !void {
    const vbe_header: *const VBEInfoBlock = @ptrFromInt(vbe_info_ptr);
    if (!std.mem.eql(u8, &vbe_header.signature, "VESA")) {
        try log.Logger.debug("Invalid VBE signature: {s}\n", .{vbe_header.signature});
        return error.InvalidVBESignature;
    }
    const video_mode_ptr: u32 = (vbe_header.video_mode_ptr_segment << 4) + vbe_header.video_mode_ptr_offset;
    const mode_list: [*]const u16 = @ptrFromInt(video_mode_ptr);
    var mode_count: usize = 0;
    while (mode_list[mode_count] != 0xFFFF) : (mode_count += 1) {
        try log.Logger.trace("VBE mode found - mode ID: 0x{x}\n", .{mode_list[mode_count]});
    }
    try log.Logger.debug("VBE found {d} modes - exploring {d} of them\n", .{mode_count, @min(mode_count,8)});
    const vbe_modes_ptr_typed: [*]const VideoModeInfo = @ptrFromInt(vbe_modes_ptr);
    const vbe_modes = vbe_modes_ptr_typed[0..mode_count];
    // go until count or 8 modes, whichever is smaller
    for (vbe_modes[0..@min(mode_count,8)], 0..@min(mode_count,8)) |mode_info, i| {
        try log.Logger.debug("VBE Mode {d}: Resolution: {d}x{d}, BPP: {d}\n", .{
            i,
            mode_info.x_resolution,
            mode_info.y_resolution,
            mode_info.bits_per_pixel,
        });
    }
}

// ArtInium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
const std = @import("std");

const display_mode = struct{
    width: u16,
    height: u16,
    pixel_format: pixel_format,
};

const pixel_colour_order = enum{
    RGB,
    BGR,
};

const pixel_format = struct {
    ascii_token: [4]u8,
    bpp: u8,
    order: pixel_colour_order,
} ;


const framebuffer_formats = enum(pixel_format){
    RGB3  = .{ .ascii_token = "RG24", .bpp = 24, .order = pixel_colour_order.RGB},
    BGR3  = .{ .ascii_token = "BR24", .bpp = 24, .order = pixel_colour_order.BGR},
    RGBA4 = .{ .ascii_token = "AR32", .bpp = 32, .order = pixel_colour_order.RGB},
    BGRA4 = .{ .ascii_token = "AB32", .bpp = 32, .order = pixel_colour_order.BGR},
    RGB5  = .{ .ascii_token = "XR16", .bpp = 16, .order = pixel_colour_order.RGB},
    BGR5  = .{ .ascii_token = "XB16", .bpp = 16, .order = pixel_colour_order.BGR},
    RGB8  = .{ .ascii_token = "XR24", .bpp = 24, .order = pixel_colour_order.RGB},
    BGR8  = .{ .ascii_token = "XB24", .bpp = 24, .order = pixel_colour_order.BGR},
};


// pub fn set_display_mode(mode: display_mode) void {
//     // Set the BGA display mode using I/O ports
//     ports.outw(ports.Port.BGA.INDEX, 0x0001); // Set the index to the mode register
//     const mode_value: u16 = compute_mode_value(mode);
//     ports.outw(ports.Port.BGA.DATA, mode_value); // Write the mode value
// }
// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

const std = @import("std");

pub const DeviceKind = enum { Uart, Display, Storage };

pub const StorageError = error{
    Io,
    OutOfRange,
    Unsupported,
};

pub const DeviceOps = extern struct {
    // UART:
    putc: ?fn (ctx: usize, byte: u8) void,
    puts: ?fn (ctx: usize, data: []const u8) void,

    // Display (simple-framebuffer):
    framebuffer_info: ?fn (ctx: usize) ?*const FramebufferInfo, // read-only info

    // Storage:
    read_blocks: ?fn (ctx: usize, lba: u64, count: usize, buf: []u8) StorageError!void,
};

pub const Device = struct {
    kind: DeviceKind,
    name: []const u8,
    ops: *const DeviceOps,
    ctx: usize, // opaque driver state pointer (cast to usize)
};

// Framebuffer info shared type
pub const FramebufferInfo = extern struct {
    phys_base: usize,
    width: u32,
    height: u32,
    stride: u32,
    format: []const u8,
};

// Global fixed-size device store (bootloader-friendly)
pub const MAX_DEVICES = 16;
var device_store: [MAX_DEVICES]Device = undefined;
var device_count: usize = 0;

pub fn register_device(d: Device) !void {
    if (device_count >= MAX_DEVICES) return error.OutOfSpace;
    device_store[device_count] = d;
    device_count += 1;
}

pub fn get_devices() []Device {
    return device_store[0..device_count];
}

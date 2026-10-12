// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

/// Property decoders for commonly needed DTB nodes.
/// These extract the specific fields needed to initialise hardware.

const std = @import("std");
const node = @import("node.zig");
const Property = node.Property;

comptime { _ = std; }

/// Decoded `memory@...` node: RAM base and size.
pub const Memory = struct {
    base: u64,
    size: u64,
};

/// Decoded `simple-framebuffer` node.
pub const Framebuffer = struct {
    base: u64,
    width: u32,
    height: u32,
    stride: u32, // bytes per row
    format: []const u8, // e.g. "a8r8g8b8", "r5g6b5"
};

/// Decoded `chosen` node.
pub const Chosen = struct {
    stdout_path: ?[]const u8,
    bootargs: ?[]const u8,
};

/// Decode a `reg` property into a (base, size) pair given parent's
/// #address-cells and #size-cells (both typically 2 on a 64-bit virt machine).
pub fn decode_reg(prop: Property, addr_cells: u32, size_cells: u32) ?struct { base: u64, size: u64 } {
    _ = prop;
    _ = addr_cells;
    _ = size_cells;
    @panic("unimplemented");
}

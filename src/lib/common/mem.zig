// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
const builtin = @import("builtin");
const std = @import("std");

pub const heap_range = blk: {
    const heap = switch (builtin.cpu.arch) {
        .x86 => @import("../x86_32/mem/heap.zig"),
        .arm64 => @import("../arm64/mem/heap.zig"),
        else => @compileError("Unsupported architecture for heap"),
    };

    break :blk heap.heap_range;
};

pub var heap_buffer: []u8 = @as(
    [*]u8,
    @ptrFromInt(heap_range.start),
)[0..heap_range.size];


var fba: std.heap.FixedBufferAllocator = .init(heap_buffer);

pub fn allocator() std.mem.Allocator {
    return fba.allocator();
}
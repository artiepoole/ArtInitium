// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
const builtin = @import("builtin");
const std = @import("std");

extern var __heap_start: u8;
extern var __heap_end: u8;

const heap_start: usize = @intFromPtr(&__heap_start);
const heap_end: usize = @intFromPtr(&__heap_end);

const heap_size = heap_end - heap_start;

pub var heap_buffer: []u8 = @as(
    [*]u8,
    @ptrFromInt(heap_start),
)[0..heap_size];

var fba: std.heap.FixedBufferAllocator = .init(heap_buffer);

pub fn allocator() std.mem.Allocator {
    return fba.allocator();
}

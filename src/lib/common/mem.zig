// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
const builtin = @import("builtin");
const std = @import("std");

extern var __heap_start: u8;
extern var __heap_end: u8;

var initialized = false;
var fba: std.heap.FixedBufferAllocator = undefined;

pub fn allocator() std.mem.Allocator {
    if (!initialized) {
        const heap_start = @intFromPtr(&__heap_start);
        const heap_end = @intFromPtr(&__heap_end);
        const heap_size = heap_end - heap_start;

        const heap_buffer = @as(
            [*]u8,
            @ptrFromInt(heap_start),
        )[0..heap_size];

        fba = .init(heap_buffer);
        initialized = true;
    }

    return fba.allocator();
}
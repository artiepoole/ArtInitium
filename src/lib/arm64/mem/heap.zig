// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
const mem = @import("../../common/mem.zig");


extern var __heap_start: u8;
extern var __heap_end: u8;

const heap_start: usize = @intFromPtr(&__heap_start);
const heap_end: usize = @intFromPtr(&__heap_end);

const heap_size = heap_end - heap_start;

pub const heap_range = mem.HeapRange  {
    .start = heap_start,
    .size = heap_size,
};
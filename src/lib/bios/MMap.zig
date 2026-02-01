// ArtInium - Bootloader for x86_32 qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

const debug = @import("../debug.zig");

pub const MMapEntry = extern struct {
    base_addr: u64,
    length: u64,
    entry_type: u32,
    extended_attr: u32,
};

pub fn parse_mmap_entries(mmap_ptr: u32, mmap_count: u16) !void {
    const ptr: [*]const MMapEntry = @ptrFromInt(mmap_ptr);
    if (mmap_ptr == 0) {
        return error.NullMMapPointer;
    }

    const entries = ptr[0..mmap_count];
    for (entries, 0..) |entry, i| {
        switch (entry.entry_type) {
            1 => |_| {
                try debug.Debug.print("MMap Entry {d}: Usable Memory - Base: 0x{x}, Length: 0x{x}\n", .{ i, entry.base_addr, entry.length });
            },
            2 => |_| {
                try debug.Debug.print("MMap Entry {d}: Reserved Memory - Base: 0x{x}, Length: 0x{x}\n", .{ i, entry.base_addr, entry.length });
            },
            3 => |_| {
                try debug.Debug.print("MMap Entry {d}: ACPI Reclaimable Memory - Base: 0x{x}, Length: 0x{x}\n", .{ i, entry.base_addr, entry.length });
            },
            4 => |_| {
                try debug.Debug.print("MMap Entry {d}: Non Volatile Storage - Base: 0x{x}, Length: 0x{x}\n", .{ i, entry.base_addr, entry.length });
            },
            5 => |_| {
                try debug.Debug.print("MMap Entry {d}: Bad RAM area - Base: 0x{x}, Length: 0x{x}\n", .{ i, entry.base_addr, entry.length });
            },
            else => |_| {
                try debug.Debug.print("ERROR: MMap Entry {d}: Unknown Type {d} - Base: 0x{x}, Length: 0x{x}\n", .{ i, entry.entry_type, entry.base_addr, entry.length });
                return error.MMAPEntryUnknownType;
            },
        }
    }
}

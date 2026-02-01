// ArtInium - Bootloader for x86_32 qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

// src/lib/mem/buffered_list.zig
const std = @import("std");

/// A self-contained ArrayList with flexible buffer management.
/// - capacity = null: uses external buffer (pass to init)
/// - capacity = N: uses internal buffer of size N
pub fn BufferedList(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();
        const buffer_size = capacity * @sizeOf(T) + 128;

        buffer: [buffer_size]u8 = undefined,
        fba: std.heap.FixedBufferAllocator = undefined,
        list: std.ArrayListUnmanaged(T) = .{},
        initialized: bool = false,

        /// Initialize with internal buffer (only available if capacity was specified)
        pub fn init(self: *Self) void {
            @memset(self.buffer[0..], 0);
            self.fba = std.heap.FixedBufferAllocator.init(&self.buffer);
            self.initialized = true;
        }

        pub fn append(self: *Self, item: T) !void {
            if (!self.initialized) {
                self.init();
            }
            try self.list.append(self.fba.allocator(), item);
        }

        pub fn items(self: *const Self) []const T {
            return self.list.items;
        }

        pub fn clearRetainingCapacity(self: *Self) void {
            self.list.clearRetainingCapacity();
        }

        pub fn deinit(self: *Self) void {
            self.list.deinit(self.fba.allocator());
        }
    };
}

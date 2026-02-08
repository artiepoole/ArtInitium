// ArtInium - Bootloader for x86_32 qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
//
//
const std = @import("std");
const serial = @import("serial.zig");
const buffered_list = @import("mem/buffered_list.zig");

const WriterType = std.io.AnyWriter;

pub const Debug = struct {
    const print_buffer_size = 1024;
    var print_buffer: [1024]u8 = [_]u8{0} ** 1024;
    // var writer_buffer: [8]WriterType = undefined;
    // var writers = std.ArrayListUnmanaged(WriterType).initBuffer(&writer_buffer);
    var writers = buffered_list.BufferedList(WriterType, 8){};

    var initialized: bool = false;

    fn init() !void {
        writers.init();
        initialized = true;
    }

    pub fn register_writer(new_writer: WriterType, name:[]const u8) !void {
        if (!initialized) {
            try init();
        }

        if (writers.append(new_writer)) |_| {
            try print("Debug: Registered new writer: {s}\n", .{name});
            return;
        } else |err| {
            return err;
        }
    }

    pub fn write(data: []const u8) !void {
        for (writers.items()) |writer| {
            _ = try writer.write(data);
        }
    }

    pub fn print(comptime fmt: []const u8, args: anytype) !void {
        var buffer_writer = BufferedWriter{};
        try std.fmt.format(buffer_writer.writer(), fmt, args);
        try buffer_writer.flush();
    }

    const BufferedWriter = struct {
        pos: usize = 0,

        pub fn writer(self: *BufferedWriter) std.io.GenericWriter(
            *BufferedWriter,
            error{WriteFailed},
            writeInternal,
        ) {
            return .{ .context = self };
        }

        fn writeInternal(self: *BufferedWriter, data: []const u8) error{WriteFailed}!usize {
            var written: usize = 0;
            while (written < data.len) {
                const available = print_buffer.len - self.pos;
                const to_copy = @min(available, data.len - written);

                @memcpy(print_buffer[self.pos..][0..to_copy], data[written..][0..to_copy]);
                self.pos += to_copy;
                written += to_copy;

                if (self.pos >= print_buffer.len) {
                    write(print_buffer[0..self.pos]) catch return error.WriteFailed;
                    self.pos = 0;
                }
            }
            return written;
        }

        fn flush(self: *BufferedWriter) !void {
            if (self.pos > 0) {
                try write(print_buffer[0..self.pos]);
                self.pos = 0;
            }
        }
    };
};

test "test long write" {
    var test_output_buffer: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&test_output_buffer);
    const test_writer = fbs.writer().any();

    try Debug.register_writer(test_writer);
    defer Debug.writers.clearRetainingCapacity();

    const very_long_string = "A" ** 2000;
    // @breakpoint();
    try Debug.print("Test: {s}", .{very_long_string});

    try std.testing.expect(fbs.pos == very_long_string.len + 6); // "Test: " + content

    // Test multiple calls
    fbs.reset();
    try Debug.print("Short message", .{});
    try Debug.print("Another short: {d}", .{42});

    // Test exactly buffer size
    fbs.reset();
    const exact_size = "B" ** (Debug.print_buffer_size - 10);
    try Debug.print("Exact: {s}", .{exact_size});
}

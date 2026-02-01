// ArtInium - Bootloader for x86_32 qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
//
//
const std = @import("std");
const serial = @import("serial.zig");

const WriterType = std.io.AnyWriter;

pub const Debug = struct {
    const print_buffer_size = 1024;
    var print_buffer: [1024]u8 = [_]u8{0} ** 1024;
    // var writer_buffer: [8]WriterType = undefined;
    // var writers = std.ArrayListUnmanaged(WriterType).initBuffer(&writer_buffer);

    var writer_buffer: [8 * @sizeOf(WriterType)]u8 = undefined;
    var writer_fba: std.heap.FixedBufferAllocator = undefined;
    var writers = std.ArrayListUnmanaged(WriterType){};
    var initialized: bool = false;

    fn init() void {
        writer_fba = std.heap.FixedBufferAllocator.init(&writer_buffer);
        initialized = true;
    }

    pub fn register_writer(new_writer: WriterType) !void {
        if (!initialized) init();
        try writers.append(writer_fba.allocator(), new_writer);
    }

    pub fn write(data: []const u8) !void {
        for (writers.items) |writer| {
            _ = try writer.write(data);
        }
    }

    pub fn print(comptime fmt: []const u8, args: anytype) !void {
        var buffer_offset: usize = 0;

        while (buffer_offset < print_buffer.len) {
            const remaining_buffer = print_buffer[buffer_offset..];
            const formatted = std.fmt.bufPrint(remaining_buffer, fmt, args) catch |fmt_err| {
                if (fmt_err == error.NoSpaceLeft) {
                    // Write what we have so far
                    write(print_buffer[0..print_buffer.len]) catch |prnt_err| {
                        return prnt_err;
                    };
                    // serial.Serial.write(print_buffer[0..print_buffer.len]);
                    buffer_offset = 0;
                    continue;
                } else {
                    return fmt_err;
                }
            };

            // Successfully formatted, write it
            // serial.Serial.write(formatted);
            write(formatted) catch |prnt_err| {
                return prnt_err;
            };
        }
    }
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

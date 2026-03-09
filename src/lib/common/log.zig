// ArtInium - Bootloader for x86_32 qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
const std = @import("std");
const builtin = @import("builtin");
pub const serial = switch (builtin.cpu.arch) {
    .x86 => @import("../x86_32/serial.zig"),
    // .x86_64 => @import("x86_64/serial.zig"),
    // .arm, .armeb => @import("arm32/serial.zig"),
    // .aarch64, .aarch64_be => @import("arm64/serial.zig"),
    else => @compileError("Unsupported architecture for serial"),
};
const buffered_list = @import("data_types/buffered_list.zig");

pub const LoggerLevel = enum(usize) {
    Trace = 0,
    Debug = 1,
    Info = 2,
    Warning = 3,
    Error = 4,
    Critical = 5,
};

const WriterType = std.io.AnyWriter;
const LoggerMethod = struct {
    writer: std.io.AnyWriter,
    level: LoggerLevel,
};

pub const Logger = struct {
    var current_level = LoggerLevel.Trace;
    const print_buffer_size = 1024;
    var print_buffer: [1024]u8 = [_]u8{0} ** 1024;
    // var writer_buffer: [8]WriterType = undefined;
    // var writers = std.ArrayListUnmanaged(WriterType).initBuffer(&writer_buffer);
    var writers = buffered_list.BufferedList(LoggerMethod, 8){};

    var initialized: bool = false;

    fn init() !void {
        writers.init();
        initialized = true;
    }

    pub fn register_writer(new_writer: WriterType, name: []const u8, level: LoggerLevel) !void {
        if (!initialized) {
            try init();
        }

        if (writers.append(LoggerMethod{ .level = level, .writer = new_writer })) |_| {
            try print("Logger: Registered new writer: {s}\n", .{name});
            return;
        } else |err| {
            return err;
        }
    }

    pub fn write(data: []const u8) !void {
        for (writers.items()) |writer| {
            if (@intFromEnum(current_level) >= @intFromEnum(writer.level)) {
                _ = try writer.writer.write(data);
            }
        }
    }

    pub fn print(comptime fmt: []const u8, args: anytype) !void {
        current_level = LoggerLevel.Critical;
        var buffer_writer = BufferedWriter{};
        try std.fmt.format(buffer_writer.writer(), fmt, args);
        try buffer_writer.flush();
        current_level = LoggerLevel.Critical;
    }

    pub fn trace(comptime fmt: []const u8, args: anytype) !void {
        current_level = LoggerLevel.Trace;
        var buffer_writer = BufferedWriter{};
        try std.fmt.format(buffer_writer.writer(), fmt, args);
        try buffer_writer.flush();
        current_level = LoggerLevel.Critical;
    }

    pub fn debug(comptime fmt: []const u8, args: anytype) !void {
        current_level = LoggerLevel.Debug;
        var buffer_writer = BufferedWriter{};
        try std.fmt.format(buffer_writer.writer(), fmt, args);
        try buffer_writer.flush();
        current_level = LoggerLevel.Critical;
    }

    pub fn info(comptime fmt: []const u8, args: anytype) !void {
        current_level = LoggerLevel.Info;
        var buffer_writer = BufferedWriter{};
        try std.fmt.format(buffer_writer.writer(), fmt, args);
        try buffer_writer.flush();
        current_level = LoggerLevel.Never;
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

    try Logger.register_writer(test_writer);
    defer Logger.writers.clearRetainingCapacity();

    const very_long_string = "A" ** 2000;
    // @breakpoint();
    try Logger.print("Test: {s}", .{very_long_string});

    try std.testing.expect(fbs.pos == very_long_string.len + 6); // "Test: " + content

    // Test multiple calls
    fbs.reset();
    try Logger.print("Short message", .{});
    try Logger.print("Another short: {d}", .{42});

    // Test exactly buffer size
    fbs.reset();
    const exact_size = "B" ** (Logger.print_buffer_size - 10);
    try Logger.print("Exact: {s}", .{exact_size});
}

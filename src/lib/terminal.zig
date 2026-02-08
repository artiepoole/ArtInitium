// ArtInium - Bootloader for x86_32 qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

const std = @import("std");

pub const TerminalImpl = struct {
    initialised: bool = false,
    row: usize = 0,
    col: usize = 0,
    color: u8 = 0x0F, // White on black

    const VGA_WIDTH = 80;
    const VGA_HEIGHT = 25;
    const VGA_MEMORY: [*]volatile u16 = @ptrFromInt(0xB8000);

    fn initInternal(self: *TerminalImpl) !void {
        self.initialised = true;
        self.clear();
    }

    fn clear(self: *TerminalImpl) void {
        const blank = @as(u16, ' ') | (@as(u16, self.color) << 8);
        var i: usize = 0;
        while (i < VGA_WIDTH * VGA_HEIGHT) : (i += 1) {
            VGA_MEMORY[i] = blank;
        }
        self.row = 0;
        self.col = 0;
    }

    fn putCharAt(self: *TerminalImpl, c: u8, row: usize, col: usize) void {
        const index = row * VGA_WIDTH + col;
        VGA_MEMORY[index] = @as(u16, c) | (@as(u16, self.color) << 8);
    }

    fn scroll(self: *TerminalImpl) void {
        var row: usize = 1;
        while (row < VGA_HEIGHT) : (row += 1) {
            var col: usize = 0;
            while (col < VGA_WIDTH) : (col += 1) {
                const src = row * VGA_WIDTH + col;
                const dst = (row - 1) * VGA_WIDTH + col;
                VGA_MEMORY[dst] = VGA_MEMORY[src];
            }
        }
        // Clear last line
        const blank = @as(u16, ' ') | (@as(u16, self.color) << 8);
        var col: usize = 0;
        while (col < VGA_WIDTH) : (col += 1) {
            VGA_MEMORY[(VGA_HEIGHT - 1) * VGA_WIDTH + col] = blank;
        }
        self.row = VGA_HEIGHT - 1;
    }

    pub fn writeBytes(self: *TerminalImpl, data: []const u8) !void {
        if (!self.initialised) {
            try self.initInternal();
        }

        for (data) |byte| {
            if (byte == '\n') {
                self.col = 0;
                self.row += 1;
                if (self.row >= VGA_HEIGHT) {
                    self.scroll();
                }
            } else if (byte == '\r') {
                self.col = 0;
            } else {
                self.putCharAt(byte, self.row, self.col);
                self.col += 1;
                if (self.col >= VGA_WIDTH) {
                    self.col = 0;
                    self.row += 1;
                    if (self.row >= VGA_HEIGHT) {
                        self.scroll();
                    }
                }
            }
        }
    }

    fn writeBytesFn(context: *const anyopaque, bytes: []const u8) anyerror!usize {
        const self: *TerminalImpl = @constCast(@alignCast(@ptrCast(context)));
        try self.writeBytes(bytes);
        return bytes.len;
    }

    pub fn writer(self: *TerminalImpl) std.io.AnyWriter {
        return .{
            .context = self,
            .writeFn = writeBytesFn,
        };
    }
};

pub var Terminal: TerminalImpl = .{};

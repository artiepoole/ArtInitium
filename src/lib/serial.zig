// ArtInium - Bootloader for x86_32 qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

const std = @import("std");
const cpu = @import("cpu.zig");
const debug = @import("debug.zig");


const SerialError = error{
    InitFailed,
    UnsupportedHardware,
};

var coms: [4]Serial = .{
    Serial{ .com = cpu.COM.init(cpu.port_ids.Serial.COM1) },
    Serial{ .com = cpu.COM.init(cpu.port_ids.Serial.COM2) },
    Serial{ .com = cpu.COM.init(cpu.port_ids.Serial.COM3) },
    Serial{ .com = cpu.COM.init(cpu.port_ids.Serial.COM4) },
};

pub const Serial = struct {
    initialised: bool = false,
    com: cpu.COM,

    /// call with "cpu.port_ids.Serial.COMX" to get the corresponding instance
    /// where X = 1..4
    pub fn get(port: u16) !*Serial {
        const idx: usize = switch (port) {
            cpu.port_ids.Serial.COM1 => 0,
            cpu.port_ids.Serial.COM2 => 1,
            cpu.port_ids.Serial.COM3 => 2,
            cpu.port_ids.Serial.COM4 => 3,
            else => return error.UnsupportedHardware,
        };
        const serial = &coms[idx];
        if (!serial.initialised) {
            try serial.initInternal();
        }
        return serial;
    }

    fn initInternal(self: *Serial) !void {
        self.com.IER.outb(0x00); // disable interrupts
        self.com.LCR.outb(0x80); // enable DLAB
        self.com.DATA.outb(0x03); // divisor low (38400 baud)
        self.com.IER.outb(0x00); // divisor high
        self.com.LCR.outb(0x03); // 8N1
        self.com.IIR.outb(0xC7); // FIFO
        self.com.MCR.outb(0x0B); // IRQs, RTS/DSR

        // loopback test
        self.com.MCR.outb(0x1E);
        self.com.DATA.outb(0xAE);

        if (self.com.DATA.inb() != 0xAE) {
            return error.InitFailed;
        }

        // exit loopback
        self.com.MCR.outb(0x0F);
        self.initialised = true;
    }

    pub fn writeBytes(self: *Serial, data: []const u8) void {
        if (!self.initialised) {
            return;
        }
        for (data) |byte| {
            self.com.DATA.outb(byte);
        }
    }

    fn writeBytesFn(context: *const anyopaque, bytes: []const u8) anyerror!usize {
        const self: *Serial = @constCast(@alignCast(@ptrCast(context)));
        if (!self.initialised) {
            return 0;
        }
        for (bytes) |byte| {
            self.com.DATA.outb(byte);
        }
        return bytes.len;
    }

    pub fn Writer(self: *Serial) std.io.AnyWriter {
        return .{
            .context = self,
            .writeFn = writeBytesFn,
        };
    }
};

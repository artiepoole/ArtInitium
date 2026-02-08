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
pub const Serial = struct {
    initialised: bool = false,
    com: cpu.COM,

    // Static singleton instance for COM1
    var com1_instance: Serial = Serial{
        .initialised = false,
        .com = cpu.COM.init(0x3F8),
    };

    pub fn get_com1() !*Serial {
        if (!com1_instance.initialised){
            try com1_instance.initInternal();
        }
        return &com1_instance;
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

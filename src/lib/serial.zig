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

    var instances: [4]?*Serial = [_]?*Serial{null} ** 4;
    var storage: [4]Serial = undefined;  // Backing storage

    pub fn get(comptime port_base: u16) !*Serial {
        // Map port base address to array index
        const com_index: u3 = switch (port_base) {
            0x3F8 => 0, // COM1
            0x2F8 => 1, // COM2
            0x3E8 => 2, // COM3
            0x2E8 => 3, // COM4
            else => return error.UnsupportedHardware,
        };

        if (instances[com_index] == null) {
            storage[com_index] = Serial{
                .initialised = false,
                .com = cpu.COM.init(port_base),
            };
            instances[com_index] = &storage[com_index];
            try instances[com_index].?.initInternal();
        }
        return instances[com_index].?;
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
        self.com.DATA.outb('x'); // test byte

        debug.Debug.register_writer(self.writer().any()) catch {
            self.writeBytes("Serial port registration failed\n");
        };
    }

    pub fn writeBytes(self: *Serial,data: []const u8) void {
        if (!self.initialised) {
            return;
        }
        for (data) |byte| {
            self.com.DATA.outb(byte);
        }
    }

    fn writeBytesFn(context: *Serial, bytes: []const u8) error{}!usize {
        if (!context.initialised) {
            return 0;
        }
        for (bytes) |byte| {
            context.com.DATA.outb(byte);
        }
        return bytes.len;
    }

    pub fn writer(self: *Serial) std.io.GenericWriter(*Serial, error{}, writeBytesFn) {
        return .{ .context = self };
    }
};

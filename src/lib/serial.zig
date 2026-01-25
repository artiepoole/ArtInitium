// ArtInium - Bootloader for x86_32 qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
const cpu = @import("cpu.zig");


const SerialError = error{
InitFailed,
UnsupportedHardware,
};


pub const Serial = struct {
    var _port: u16 = undefined;
    pub fn init(port: u16) !void {
        _port = port;

        cpu.outb(port + 1, 0x00); // disable interrupts
        cpu.outb(port + 3, 0x80); // enable DLAB
        cpu.outb(port + 0, 0x03); // divisor low (38400 baud)
        cpu.outb(port + 1, 0x00); // divisor high
        cpu.outb(port + 3, 0x03); // 8N1
        cpu.outb(port + 2, 0xC7); // FIFO
        cpu.outb(port + 4, 0x0B); // IRQs, RTS/DSR

        // loopback test
        cpu.outb(port + 4, 0x1E);
        cpu.outb(port + 0, 0xAE);

        if (cpu.inb(port + 0) != 0xAE) {
            return error.InitFailed; // UART not present
        }

        // exit loopback
        cpu.outb(port + 4, 0x0F);

    }
    pub fn write(data: []const u8) void {
        for (data) |byte| {
            cpu.outb(_port, byte);
        }
    }
};


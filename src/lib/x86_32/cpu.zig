// ArtInium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

const io = @import("./io/io.zig");

pub const COM = struct {
   DATA: io.port.Port,
   IER:  io.port.Port,
   IIR:  io.port.Port,
   LCR:  io.port.Port,
   MCR:  io.port.Port,
   LSR:  io.port.Port,
   MSR:  io.port.Port,
   SCR:  io.port.Port,

    pub fn init(port_base: u16) COM {
        return COM{
            .DATA = io.port.Port.init(port_base + 0),
            .IER  = io.port.Port.init(port_base + 1),
            .IIR  = io.port.Port.init(port_base + 2),
            .LCR  = io.port.Port.init(port_base + 3),
            .MCR  = io.port.Port.init(port_base + 4),
            .LSR  = io.port.Port.init(port_base + 5),
            .MSR  = io.port.Port.init(port_base + 6),
            .SCR  = io.port.Port.init(port_base + 7),
        };
    }
};
/// I/O Port addresses organized by device type
pub const port_ids = enum {
    /// Serial ports (COM1)
    pub const Serial = enum {
        pub const COM1 = 0x3f8;
        pub const COM2 = 0x2f8;
        pub const COM3 = 0x3e8;
        pub const COM4 = 0x2e8;
    };

    pub const BGA = enum {
        pub const INDEX = 0x01ce;
        pub const DATA = 0x01cf;
    };
};

pub fn halt() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}
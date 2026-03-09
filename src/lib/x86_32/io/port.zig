// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

pub const Port = struct {
    port: u16 = undefined,

    pub fn init(port: u16) Port {
        return .{ .port = port };
    }

    /// Write a single byte to an I/O port
    pub fn outb(self: Port, data: u8) void {
        asm volatile ("outb %[data], %[port]"
            :
            : [data] "{al}" (data),
              [port] "N{dx}" (self.port),
        );
    }

    /// Write a word (16-bit) to an I/O port
    pub fn outw(self: Port, data: u16) void {
        asm volatile ("outw %[data], %[port]"
            :
            : [data] "{ax}" (data),
              [port] "N{dx}" (self.port),
        );
    }

    /// Write a double word (32-bit) to an I/O port
    pub fn outl(self: Port, data: u32) void {
        asm volatile ("outl %[data], %[port]"
            :
            : [data] "{eax}" (data),
              [port] "N{dx}" (self.port),
        );
    }

    /// Read a single byte from an I/O port
    pub fn inb(self: Port) u8 {
        return asm volatile ("inb %[port], %[result]"
            : [result] "={al}" (-> u8),
            : [port] "N{dx}" (self.port),
        );
    }

    /// Read a word (16-bit) from an I/O port
    pub fn inw(self: Port) u16 {
        return asm volatile ("inw %[port], %[result]"
            : [result] "={ax}" (-> u16),
            : [port] "N{dx}" (self.port),
        );
    }

    /// Read a double word (32-bit) from an I/O port
    pub fn inl(self: Port) u32 {
        return asm volatile ("inl %[port], %[result]"
            : [result] "={eax}" (-> u32),
            : [port] "N{dx}" (self.port),
        );
    }
};

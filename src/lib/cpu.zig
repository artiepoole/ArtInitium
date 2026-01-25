// ArtInium - Bootloader for x86_32 qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

/// I/O Port addresses organized by device type
pub const Port = struct {
    /// Serial ports (COM1-4)
    pub const Serial = struct {
        pub const COM1: u16 = 0x3F8;
        pub const COM2: u16 = 0x2F8;
        pub const COM3: u16 = 0x3E8;
        pub const COM4: u16 = 0x2E8;
    };
};

/// Write a single byte to an I/O port
pub fn outb(port: u16, data: u8) void {
    asm volatile ("outb %[data], %[port]"
        :
        : [data] "{al}" (data),
          [port] "N{dx}" (port),
    );
}

/// Write a word (16-bit) to an I/O port
pub fn outw(port: u16, data: u16) void {
    asm volatile ("outw %[data], %[port]"
        :
        : [data] "{ax}" (data),
          [port] "N{dx}" (port),
    );
}

/// Write a double word (32-bit) to an I/O port
pub fn outl(port: u16, data: u32) void {
    asm volatile ("outl %[data], %[port]"
        :
        : [data] "{eax}" (data),
          [port] "N{dx}" (port),
    );
}

/// Read a single byte from an I/O port
pub fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "N{dx}" (port),
    );
}

/// Read a word (16-bit) from an I/O port
pub fn inw(port: u16) u16 {
    return asm volatile ("inw %[port], %[result]"
        : [result] "={ax}" (-> u16),
        : [port] "N{dx}" (port),
    );
}

/// Read a double word (32-bit) from an I/O port
pub fn inl(port: u16) u32 {
    return asm volatile ("inl %[port], %[result]"
        : [result] "={eax}" (-> u32),
        : [port] "N{dx}" (port),
    );
}

/// Write multiple bytes to a serial port
pub fn write_serial(port: u16, data: []const u8) void {
    for (data) |byte| {
        outb(port, byte);
    }
}

pub fn init_serial(port: u16) void {
    // Disable all interrupts
    outb(port + 1, 0x00);
    // Enable DLAB (set baud rate divisor)
    outb(port + 3, 0x80);
    // Set divisor to 3 (lo byte) 38400 baud
    outb(port + 0, 0x03);
    //                  (hi byte)
    outb(port + 1, 0x00);
    // 8 bits, no parity, one stop bit
    outb(port + 3, 0x03);
    // Enable FIFO, clear them, with 14-byte threshold
    outb(port + 2, 0xC7);
}



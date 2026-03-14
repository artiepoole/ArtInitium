// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

/// PL011 UART driver for ARM64 (QEMU virt machine)
/// Base address from DTS: pl011@9000000
/// Ref: ARM PrimeCell UART (PL011) Technical Reference Manual

const PL011_BASE: usize = 0x9000000;

/// PL011 MMIO register layout (offsets in bytes)
pub const PL011 = struct {
    base: usize,

    // Register offsets
    const DR_OFFSET: usize = 0x000; // Data Register (TX/RX)
    const FR_OFFSET: usize = 0x018; // Flag Register
    const IBRD_OFFSET: usize = 0x024; // Integer Baud Rate Divisor
    const FBRD_OFFSET: usize = 0x028; // Fractional Baud Rate Divisor
    const LCR_H_OFFSET: usize = 0x02C; // Line Control Register
    const CR_OFFSET: usize = 0x030; // Control Register
    const IMSC_OFFSET: usize = 0x038; // Interrupt Mask Set/Clear

    // Flag Register bits
    const FR_TXFF: u32 = 1 << 5; // TX FIFO full
    const FR_BUSY: u32 = 1 << 3; // UART busy transmitting

    // Control Register bits
    const CR_UARTEN: u32 = 1 << 0; // UART enable
    const CR_TXE: u32 = 1 << 8; // TX enable
    const CR_RXE: u32 = 1 << 9; // RX enable

    // Line Control Register bits
    const LCR_H_FEN: u32 = 1 << 4; // FIFO enable
    const LCR_H_WLEN_8: u32 = 0b11 << 5; // 8-bit word length

    pub fn init(base: usize) PL011 {
        return .{ .base = base };
    }

    inline fn reg(self: PL011, offset: usize) *volatile u32 {
        return @ptrFromInt(self.base + offset);
    }

    inline fn read(self: PL011, offset: usize) u32 {
        return self.reg(offset).*;
    }

    inline fn write(self: PL011, offset: usize, value: u32) void {
        self.reg(offset).* = value;
    }

    /// Disable UART, configure baud rate / line control, re-enable.
    /// Clock assumed to be 24 MHz (QEMU virt default for pl011).
    /// Target baud: 115200  =>  IBRD=13, FBRD=1  (24000000 / (16 * 115200) = 13.02)
    pub fn setup(self: PL011) void {
        // Disable UART before reconfiguring
        self.write(CR_OFFSET, 0);

        // Wait for any ongoing transmission to finish
        while (self.read(FR_OFFSET) & FR_BUSY != 0) {}

        // Flush TX FIFO by disabling it (clear FEN)
        self.write(LCR_H_OFFSET, 0);

        // Set baud rate: 115200 @ 24 MHz reference clock
        // IBRD = 13, FBRD = 1
        self.write(IBRD_OFFSET, 13);
        self.write(FBRD_OFFSET, 1);

        // 8-bit, no parity, 1 stop bit, FIFO enabled
        self.write(LCR_H_OFFSET, LCR_H_WLEN_8 | LCR_H_FEN);

        // Mask all interrupts
        self.write(IMSC_OFFSET, 0);

        // Enable UART, TX and RX
        self.write(CR_OFFSET, CR_UARTEN | CR_TXE | CR_RXE);
    }

    /// Block until the TX FIFO has space, then write one byte.
    pub fn putc(self: PL011, c: u8) void {
        // Spin while TX FIFO is full
        while (self.read(FR_OFFSET) & FR_TXFF != 0) {
            asm volatile ("yield");
        }
        self.write(DR_OFFSET, c);
    }

    /// Write a slice of bytes to the UART.
    pub fn puts(self: PL011, data: []const u8) void {
        for (data) |c| {
            self.putc(c);
        }
    }
};

/// The single early-boot UART instance.
var uart: PL011 = PL011.init(PL011_BASE);

pub fn early_init() !void {
    uart.setup();
}

pub fn early_write(data: []const u8) !void {
    uart.puts(data);
}

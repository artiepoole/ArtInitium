// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

/// PL011 UART driver for ARM64 (QEMU virt machine)
/// Base address from DTS: pl011@9000000
/// Ref: ARM PrimeCell UART (PL011) Technical Reference Manual
/// https://developer.arm.com/documentation/ddi0183/latest/

const PL011_BASE: usize = 0x9000000;

/// PL011 register map, laid out exactly as the hardware MMIO space.
/// Each field is at its correct byte offset per the PL011 TRM.
/// Cast the base address to *volatile Registers to get direct field access:
///   regs.dr = 'A';   // transmit
///   _ = regs.fr;     // read flags
const PrimeCellRegisters = extern struct {
    dr: u32,        // 0x000 Data Register
    rsr: u32,       // 0x004 Receive Status / Error Clear
    _pad0: [4]u32,  // 0x008-0x014 reserved
    fr: u32,        // 0x018 Flag Register
    _pad1: u32,     // 0x01C reserved
    ilpr: u32,      // 0x020 IrDA Low-Power Counter
    ibrd: u32,      // 0x024 Integer Baud Rate Divisor
    fbrd: u32,      // 0x028 Fractional Baud Rate Divisor
    lcr_h: u32,     // 0x02C Line Control Register
    cr: u32,        // 0x030 Control Register
    ifls: u32,      // 0x034 Interrupt FIFO Level Select
    imsc: u32,      // 0x038 Interrupt Mask Set/Clear
};

// Flag Register bits
const FR_TXFF: u32 = 1 << 5; // TX FIFO full
const FR_BUSY: u32 = 1 << 3; // UART busy transmitting

// Control Register bits
const CR_UARTEN: u32 = 1 << 0; // UART enable
const CR_TXE: u32 = 1 << 8;    // TX enable
const CR_RXE: u32 = 1 << 9;    // RX enable

// Line Control Register bits
const LCR_H_FEN: u32 = 1 << 4;     // FIFO enable
const LCR_H_WLEN_8: u32 = 0b11 << 5; // 8-bit word length

/// PL011 UART driver. Holds a volatile pointer to the MMIO register block.
pub const PrimeCell = struct {
    regs: *volatile PrimeCellRegisters,

    pub fn init(base: usize) PrimeCell {
        return .{ .regs = @ptrFromInt(base) };
    }

    /// Disable UART, configure baud rate / line control, re-enable.
    /// Clock assumed to be 24 MHz (QEMU virt default for pl011).
    /// Target baud: 115200  =>  IBRD=13, FBRD=1  (24000000 / (16 * 115200) = 13.02)
    pub fn setup(self: PrimeCell) void {
        // Disable UART before reconfiguring
        self.regs.cr = 0;

        // Wait for any ongoing transmission to finish
        while (self.regs.fr & FR_BUSY != 0) {}

        // Flush TX FIFO by clearing FEN
        self.regs.lcr_h = 0;

        // Set baud rate: 115200 @ 24 MHz reference clock
        self.regs.ibrd = 13;
        self.regs.fbrd = 1;

        // 8-bit, no parity, 1 stop bit, FIFO enabled
        self.regs.lcr_h = LCR_H_WLEN_8 | LCR_H_FEN;

        // Mask all interrupts
        self.regs.imsc = 0;

        // Enable UART, TX and RX
        self.regs.cr = CR_UARTEN | CR_TXE | CR_RXE;
    }

    /// Block until the TX FIFO has space, then write one byte.
    pub fn putc(self: PrimeCell, c: u8) void {
        while (self.regs.fr & FR_TXFF != 0) {
            asm volatile ("yield");
        }
        self.regs.dr = c;
    }

    /// Write a slice of bytes to the UART.
    pub fn puts(self: PrimeCell, data: []const u8) void {
        for (data) |c| {
            self.putc(c);
        }
    }
};

/// The single early-boot UART instance.
var uart: PrimeCell = PrimeCell.init(PL011_BASE);

pub fn early_init() !void {
    uart.setup();
}

pub fn early_write(data: []const u8) !void {
    uart.puts(data);
}

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
    dr: u32, // 0x000 Data Register
    rsr: u32, // 0x004 Receive Status / Error Clear
    _pad0: [4]u32, // 0x008-0x014 reserved
    fr: u32, // 0x018 Flag Register
    _pad1: u32, // 0x01C reserved
    ilpr: u32, // 0x020 IrDA Low-Power Counter
    ibrd: u32, // 0x024 Integer Baud Rate Divisor
    fbrd: u32, // 0x028 Fractional Baud Rate Divisor
    lcr_h: u32, // 0x02C Line Control Register
    cr: u32, // 0x030 Control Register
    ifls: u32, // 0x034 Interrupt FIFO Level Select
    imsc: u32, // 0x038 Interrupt Mask Set/Clear
};

/// Register bit definitions, grouped by register.
/// Use as: FR.BUSY, CR.TXE, LCR_H.FEN, etc.
/// Flag Register (FR) bits
const FR = struct {
    const TXFF: u32 = 1 << 5; // TX FIFO full
    const BUSY: u32 = 1 << 3; // UART busy transmitting
};

/// Control Register (CR) bits
const CR = struct {
    const UARTEN: u32 = 1 << 0; // UART enable
    const TXE: u32 = 1 << 8; // TX enable
    const RXE: u32 = 1 << 9; // RX enable
};

/// Line Control Register (LCR_H) bits
const LCR_H = struct {
    const FEN: u32 = 1 << 4; // FIFO enable
    const WLEN_8: u32 = 0b11 << 5; // 8-bit word length for ascii
};

/// Interrupt Mask Set/Clear (IMSC) bits
const IMSC = struct {
    const RXIM: u32 = 1 << 4; // RX interrupt mask
    const TXIM: u32 = 1 << 5; // TX interrupt mask
};

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
        while (self.regs.fr & FR.BUSY != 0) {}

        // Flush TX FIFO by clearing FEN
        self.regs.lcr_h = 0;

        // Set baud rate: 115200 @ 24 MHz reference clock
        self.regs.ibrd = 13;
        self.regs.fbrd = 1;

        // 8-bit words, no parity, 1 stop bit, FIFO enabled
        self.regs.lcr_h = LCR_H.WLEN_8 | LCR_H.FEN;

        // Mask all interrupts
        self.regs.imsc = 0;

        // Enable UART, TX and RX (RX does nothing if serial is a file - works for stdio)
        self.regs.cr = CR.UARTEN | CR.TXE | CR.RXE;
    }

    /// Block until the TX FIFO has space, then write one byte.
    pub fn putc(self: PrimeCell, c: u8) void {
        while (self.regs.fr & FR.TXFF != 0) {
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

    /// Register the RX interrupt handler.
    ///
    /// TODO: wire `handler` into the GIC (Generic Interrupt Controller):
    ///   1. Configure GIC distributor to enable UART SPI (IRQ 33 on QEMU virt).
    ///   2. Configure GIC CPU interface to accept the priority.
    ///   3. Install `handler` into the exception vector table (EL1 IRQ entry).
    ///   4. Enable IRQs at the CPU: `msr daifclr, #2`
    ///
    /// Note: the handler signature is a placeholder. It will likely
    /// receive a slice, as the interrupt handler should drain the full RX FIFO.
    pub fn register_rx_handler(self: PrimeCell, handler: *const fn (byte: []const u8) void) void {
        _ = self;
        _ = handler; // TODO: register with GIC / exception vector table
    }

    /// Unmask the RX interrupt. Call register_rx_handler first.
    pub fn enable_rx_interrupt(self: PrimeCell) void {
        self.regs.imsc = self.regs.imsc | IMSC.RXIM;
    }

    /// Mask the RX interrupt without deregistering the handler.
    pub fn disable_rx_interrupt(self: PrimeCell) void {
        self.regs.imsc = self.regs.imsc & ~IMSC.RXIM;
    }
};

/// The single early-boot UART instance.
var uart: PrimeCell = PrimeCell.init(PL011_BASE);

/// Early init function to set up the UART for use by ArtInitium's early print macros.
/// The UART will be reconfigured later during driving probing/initialisation
pub fn early_init() !void {
    uart.setup();
}

/// Early write function for ArtInitium's early print macros. Writes the given data to the UART.
/// Note that later writes could use DMA, but this is unlikely to be worth the complexity for a
///  simple bootloader, and the PL011 doesn't support it anyway.
pub fn early_write(data: []const u8) !void {
    uart.puts(data);
}

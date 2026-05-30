// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
const std = @import("std");
const serial = @import("artlib").serial;
const cpu = @import("artlib").cpu;
const dtb = @import("artlib").dtb;

fn enableFpSimd() void {
    asm volatile (
        \\mrs x0, CPACR_EL1
        \\orr x0, x0, #(3 << 20)
        \\msr CPACR_EL1, x0
        \\isb
        ::: .{ .x0 = true, .memory = true });
}

pub fn init(dtb_addr: usize) noreturn {
    // zig's return for structs or optionals uses memcpyfast which requires simd hence
    enableFpSimd();
    serial.early_init() catch {};

    const d = dtb.Dtb.init(dtb_addr) catch |err| {
        // print diagnostic and halt (noreturn)
        serial.early_write("DTB init failed: ") catch {};
        switch (err) {
            dtb.Error.InvalidMagic => serial.early_write("Invalid DTB magic") catch {},
            dtb.Error.InvalidVersion => serial.early_write("Unsupported DTB version") catch {},
            dtb.Error.UnexpectedToken => serial.early_write("Unexpected token") catch {},
            dtb.Error.Truncated => serial.early_write("Truncated DTB") catch {},
        }
        serial.early_write("\n") catch {};
        cpu.halt(); // noreturn
    };
    _ = d;

    cpu.halt();
}

// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
const std = @import("std");
const serial = @import("artlib").serial;
const cpu = @import("artlib").cpu;

const init_dtb = @import("init_dtb.zig");

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
    // enable uart blindly
    serial.early_init() catch {};

    // parse the dtb and create devices off of it?
    init_dtb.initialise_device_tree(dtb_addr) catch {};

    // end execution
    cpu.halt();
}

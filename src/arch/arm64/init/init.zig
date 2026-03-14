// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
const std = @import("std");
const serial = @import("artlib").serial;
const cpu = @import("artlib").cpu;

pub fn init(arg: usize) noreturn {
    _ = arg;
    serial.early_init() catch {
        // If UART init fails, just carry on, and hope late init works
    };
    serial.early_write("Early Serial Test") catch {
        // If UART write fails, just carry on, and hope late init works
    };

    cpu.halt();
}

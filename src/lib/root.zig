// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

const builtin = @import("builtin");

pub const bios = switch (builtin.cpu.arch) {
    .x86 => @import("x86_32/bios/bios.zig"),
    else => @compileError("Unsupported architecture for bios"),
};

pub const cpu = switch (builtin.cpu.arch) {
    .x86 => @import("x86_32/cpu.zig"),
    .aarch64, .aarch64_be => @import("arm64/cpu.zig"),
    else => @compileError("Unsupported architecture for cpu"),
};

/// Optional: compile error on use if unsupported
pub const dtb = switch (builtin.cpu.arch) {
    .aarch64, .aarch64_be => @import("arm64/dtb/dtb.zig"),
    else => @compileError("dtb is not available on this architecture"),
};

pub const io = switch (builtin.cpu.arch) {
    .x86 => @import("x86_32/io/io.zig"),
    else => @compileError("Unsupported architecture for io"),
};

pub const log = @import("common/log.zig");

pub const mem = @import("common/data_types/data_types.zig");

pub const serial = switch (builtin.cpu.arch) {
    .x86 => @import("x86_32/serial.zig"),
    .aarch64, .aarch64_be => @import("arm64/uart.zig"),
    else => @compileError("Unsupported architecture for serial"),
};

pub const terminal = switch (builtin.cpu.arch) {
    .x86 => @import("x86_32/terminal.zig"),
    else => @compileError("Unsupported architecture for terminal"),
};

pub const video = switch (builtin.cpu.arch) {
    .x86 => @import("x86_32/video/video.zig"),
    else => @compileError("Unsupported architecture for video"),
};

test {
    @import("std").testing.refAllDecls(@This());
}

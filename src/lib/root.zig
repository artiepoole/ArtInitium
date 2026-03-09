const builtin = @import("builtin");

// Common modules available on all architectures
pub const log = @import("common/log.zig");
pub const mem = @import("common/data_types/data_types.zig");

// Architecture-specific modules
pub const cpu = switch (builtin.cpu.arch) {
    .x86 => @import("x86_32/cpu.zig"),
    // .x86_64 => @import("x86_64/cpu.zig"),
    // .arm, .armeb => @import("arm32/cpu.zig"),
    // .aarch64, .aarch64_be => @import("arm64/cpu.zig"),
    else => @compileError("Unsupported architecture for cpu"),
};

pub const serial = switch (builtin.cpu.arch) {
    .x86 => @import("x86_32/serial.zig"),
    // .x86_64 => @import("x86_64/serial.zig"),
    // .arm, .armeb => @import("arm32/serial.zig"),
    // .aarch64, .aarch64_be => @import("arm64/serial.zig"),
    else => @compileError("Unsupported architecture for serial"),
};

pub const terminal = switch (builtin.cpu.arch) {
    .x86 => @import("x86_32/terminal.zig"),
    // .x86_64 => @import("x86_64/terminal.zig"),
    // .arm, .armeb => @import("arm32/terminal.zig"),
    // .aarch64, .aarch64_be => @import("arm64/terminal.zig"),
    else => @compileError("Unsupported architecture for terminal"),
};

pub const io = switch (builtin.cpu.arch) {
    .x86 => @import("x86_32/io/io.zig"),
    // .x86_64 => @import("x86_64/io/io.zig"),
    // .arm, .armeb => @import("arm32/io/io.zig"),
    // .aarch64, .aarch64_be => @import("arm64/io/io.zig"),
    else => @compileError("Unsupported architecture for io"),
};

// Architecture-specific modules
pub const bios = switch (builtin.cpu.arch) {
    .x86 => @import("x86_32/bios/bios.zig"),
    // .x86_64 => @import("x86_64/bios/bios.zig"),
    // .arm, .armeb => @import("arm32/bios/bios.zig"),
    // .aarch64, .aarch64_be => @import("arm64/bios/bios.zig"),
    else => @compileError("Unsupported architecture for bios"),
};

pub const video = switch (builtin.cpu.arch) {
    .x86 => @import("x86_32/video/video.zig"),
    // .x86_64 => @import("x86_64/video/video.zig"),
    // .arm, .armeb => @import("arm32/video.zig"),
    // .aarch64, .aarch64_be => @import("arm64/video.zig"),
    else => @compileError("Unsupported architecture for video"),
};

test {
    @import("std").testing.refAllDecls(@This());
}

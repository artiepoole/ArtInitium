// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

const builtin = @import("builtin");
const std = @import("std");

pub const init = switch (builtin.cpu.arch) {
    .x86 => @import("arch/x86_32/init/init.zig"),
    // .x86_64 => @import("x86_64/terminal.zig"),
    // .arm, .armeb => @import("arm32/terminal.zig"),
    // .aarch64, .aarch64_be => @import("arm64/terminal.zig"),
    else => @compileError("Unsupported architecture for terminal"),
};

pub export fn Artinitium_32_entry(arg: usize) linksection(".text.entry") callconv(.c) noreturn {
    init.init(arg);
}

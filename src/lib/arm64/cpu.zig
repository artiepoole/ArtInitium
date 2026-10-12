// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
const std = @import("std");

pub fn halt() noreturn {
    while (true) {
        asm volatile ("wfi");
    }
}
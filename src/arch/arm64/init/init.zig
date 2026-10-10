// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
const std = @import("std");
const serial = @import("artlib").serial;
const cpu = @import("artlib").cpu;
const mem = @import("artlib").mem;

const init_dtb = @import("init_dtb.zig");

fn enableFpSimd() void {
    asm volatile (
        \\mrs x0, CPACR_EL1
        \\orr x0, x0, #(3 << 20)
        \\msr CPACR_EL1, x0
        \\isb
        ::: .{ .x0 = true, .memory = true });
}

pub fn testAllocator(alloc: std.mem.Allocator) void {

    serial.early_write("Allocator test: start\n") catch {} ;

    // Test 1: Allocate and write bytes.
    const buffer = alloc.alloc(u8, 64) catch {
        serial.early_write("FAIL: byte allocation\n") catch {} ;
        return;
    };
    defer alloc.free(buffer);

    for (buffer, 0..) |*byte, i| {
        byte.* = @truncate(i);
    }

    for (buffer, 0..) |byte, i| {
        if (byte != @as(u8, @truncate(i))) {
            serial.early_write("FAIL: byte verification\n") catch {} ;
            return;
        }
    }
    serial.early_write("PASS: byte allocation and verification\n") catch {} ;

    // Test 2: Allocate a second block while the first is live.
    const values = alloc.alloc(u64, 8) catch {
        serial.early_write("FAIL: u64 allocation\n") catch {} ;
        return;
    };
    defer alloc.free(values);

    @memset(values, 0xDEADBEEF);

    for (values) |value| {
        if (value != 0xDEADBEEF) {
            serial.early_write("FAIL: u64 verification\n") catch {} ;
            return;
        }
    }
    serial.early_write("PASS: simultaneous allocations and verification\n") catch {} ;

    serial.early_write("PASS: allocator test completed\n") catch {} ;
}


pub fn init(dtb_addr: usize) noreturn {
    // zig's return for structs or optionals uses memcpyfast which requires simd hence
    enableFpSimd();
    // enable uart blindly
    serial.early_init() catch {};

    // use memory allocator
    const alloc = mem.allocator();
    testAllocator(alloc);
    // parse the dtb and create devices off of it?
    init_dtb.initialise_device_tree(dtb_addr) catch {};

    // end execution
    cpu.halt();
}

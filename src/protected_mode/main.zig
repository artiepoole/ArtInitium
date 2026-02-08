// ArtInium - Bootloader for x86_32 qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
//
const std = @import("std");
const cpu = @import("artlib").cpu;
const serial = @import("artlib").serial;
const bios = @import("artlib").bios;
const debug = @import("artlib").debug;
const video = @import("artlib").video;

const LOAD_MSG: []const u8 = "Loading 32-bit protected mode bootloader...\n";
const BIOS_INVALID_MSG: []const u8 = "Invalid BIOS boot info\n";

// extern const bios_info_struct: bios.BiosInfo;
fn halt() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

pub export fn Artinium_32_entry(bios_info_struct: *bios.header.BiosInfoHeader) linksection(".text.entry") callconv(.c) noreturn {
    // TODO: implement Stage 2 bootloader
    // - Load kernel from disk
    // - Parse kernel headers
    // - Set up paging if needed
    // - Jump to kernel

    const com1 = serial.Serial.get_com1() catch {halt();}; // Initialize COM1
    debug.Debug.register_writer(com1.Writer(), "com1") catch {halt();};
    debug.Debug.print(LOAD_MSG, .{}) catch {halt();};

    bios.parse_bios_headers(bios_info_struct) catch {
        debug.Debug.print(BIOS_INVALID_MSG, .{}) catch {halt();};
        halt();
    };


    halt();
}



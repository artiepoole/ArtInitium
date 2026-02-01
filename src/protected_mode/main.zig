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

const LOAD_MSG: []const u8 = "Loading 32-bit protected mode bootloader...\n";
const BIOS_INVALID_MSG: []const u8 = "Invalid BIOS boot info structure magic\n";

// extern const bios_info_struct: bios.BiosInfo;
fn halt() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

pub export fn Artinium_32_entry(bios_info_struct: *bios.BiosInfoHeader) linksection(".text.entry") callconv(.c) noreturn {
    // Write magic marker to VGA memory to verify we got here
    // VGA text mode buffer at 0xB8000
    asm volatile (
        \\ mov $0xB8000, %%edi
        \\ movw $0x4F32, (%%edi)
        \\ movw $0x0F32, (%edi)    /* '2' white on black */
        \\ movw $0x0F33, 2(%edi)   /* '3' white on black */
        \\ movw $0x0F34, 4(%edi)   /* '4' white on black */
        ::: .{ .edi = true });

    // TODO: implement Stage 2 bootloader
    // - Load kernel from disk
    // - Parse kernel headers
    // - Set up paging if needed
    // - Jump to kernel

    serial.Serial.init(cpu.Port.Serial.COM1) catch {halt();};
    debug.Debug.print(LOAD_MSG, .{}) catch {halt();};

    if (!bios.validate(bios_info_struct)) {
        debug.Debug.print(BIOS_INVALID_MSG, .{}) catch {halt();};
    } else {
        debug.Debug.print("Bios info structure at address: 0x{x}\n", .{@intFromPtr(bios_info_struct)})  catch {halt();};
    }
    halt();
}



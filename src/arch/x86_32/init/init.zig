// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
const std = @import("std");
const cpu = @import("artlib").cpu;
const serial = @import("artlib").serial;
const bios = @import("artlib").bios;
const log = @import("artlib").log;
const video = @import("artlib").video;
const terminal = @import("artlib").terminal;

const LOAD_MSG: []const u8 = "Loading 32-bit protected mode bootloader...\n";
const BIOS_INVALID_MSG: []const u8 = "Invalid BIOS boot info\n";


// extern const bios_info_struct: bios.header.BiosInfoHeader;

pub fn init(arg: usize ) noreturn  {
    const bios_info_struct : *bios.header.BiosInfoHeader = @ptrFromInt(arg);
    // TODO: implement Stage 2 bootloader
    // - Load kernel from disk
    // - Parse kernel headers
    // - Set up paging if needed
    // - Jump to kernel

    const com1 = serial.Serial.get(cpu.port_ids.Serial.COM1) catch {
        cpu.halt();
    }; // Initialize COM1 - qemu file logging - serial.log
    log.Logger.register_writer(com1.Writer(), "com1", log.LoggerLevel.Trace) catch {
        cpu.halt();
    };
    const com2 = serial.Serial.get(cpu.port_ids.Serial.COM2) catch {
        cpu.halt();
    }; // Initialize COM2 - qemu stdio logging
    log.Logger.register_writer(com2.Writer(), "com2", log.LoggerLevel.Debug) catch {
        cpu.halt();
    };


    log.Logger.register_writer(terminal.Terminal.writer(), "terminal", log.LoggerLevel.Info) catch {
        cpu.halt();
    };

    log.Logger.print(LOAD_MSG, .{}) catch {
        cpu.halt();
    };

    bios.parse_bios_headers(bios_info_struct) catch {
        log.Logger.print(BIOS_INVALID_MSG, .{}) catch {
            cpu.halt();
        };
        cpu.halt();
    };

    cpu.halt();
}

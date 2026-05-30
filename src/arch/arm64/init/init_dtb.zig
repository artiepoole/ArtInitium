// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
const std = @import("std");
const serial = @import("artlib").serial;
const dtb = @import("artlib").dtb;

// Helper: print "node: {node_name}, property: {prop_name}\n"
fn print_node_prop(node_name: []const u8, prop_name: []const u8) void {
    // print node label
    serial.early_write("node: ") catch {};

    // print node name (may be empty)
    if (node_name.len == 0) {
        serial.early_write("<unnamed>") catch {};
    } else {
        serial.early_write(node_name) catch {};
    }

    // print separator and property name
    serial.early_write(", property: ") catch {};
    if (prop_name.len == 0) {
        serial.early_write("<unnamed>") catch {};
    } else {
        serial.early_write(prop_name) catch {};
    }

    // newline
    serial.early_write("\n") catch {};
}

pub fn initialise_device_tree(dtb_addr: usize) dtb.Error!void {
    const d = dtb.Dtb.init(dtb_addr) catch |err| {
        // print diagnostic and halt (noreturn)
        serial.early_write("DTB init failed: ") catch {};
        switch (err) {
            dtb.Error.InvalidMagic => serial.early_write("Invalid DTB magic") catch {},
            dtb.Error.InvalidVersion => serial.early_write("Unsupported DTB version") catch {},
            dtb.Error.UnexpectedToken => serial.early_write("Unexpected token") catch {},
            dtb.Error.Truncated => serial.early_write("Truncated DTB") catch {},
        }
        serial.early_write("\n") catch {};
        return err;
    };
    var w = d.walker();
    const n = w.next_node();
    _ = n;
    // while (w.next_node()) |n| {
    //     while (w.next_prop()) |p| {
    //         print_node_prop(n.name, p.name);
    //     }
    // }
}

// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
const std = @import("std");
const serial = @import("artlib").serial;
const dtb = @import("artlib").dtb;

const BeginItem = std.meta.TagPayload(dtb.Item, .begin);
const PropertyItem = std.meta.TagPayload(dtb.Item, .property);

fn write_indent(depth: usize) void {
    var i: usize = 0;
    while (i < depth) : (i += 1) {
        serial.early_write("  ") catch {};
    }
}

fn print_node(n: BeginItem, depth: usize) void {
    write_indent(depth);
    // print node label
    serial.early_write("Begin node: ") catch {};

    // print node name (may be empty)
    if (n.name.len == 0) {
        serial.early_write("<unnamed>") catch {};
    } else {
        serial.early_write(n.name) catch {};
    }
    serial.early_write("\n") catch {};
}

// Helper: print "node: {node_name}, property: {prop_name}\n"
fn print_prop(p: PropertyItem, depth: usize) void {
    write_indent(depth);
    // print node label
    serial.early_write("Property: ") catch {};

    // print node name (may be empty)
    if (p.name.len == 0) {
        serial.early_write("") catch {};
    } else {
        serial.early_write(p.name) catch {};
    }
    serial.early_write("\n") catch {};
}

const device_ids = enum {
    pl011,
    pl031,
    pcie,
    memory,
    other,
};

fn device_type(id: []const u8) device_ids {
    if (std.mem.eql(u8, id, "pl011")) return .pl011;
    if (std.mem.eql(u8, id, "pl031")) return .pl031;
    if (std.mem.eql(u8, id, "pcie")) return .pcie;
    if (std.mem.eql(u8, id, "memory")) return .memory;
    return .other;
}

fn consume_node(w: *dtb.Walker, n: BeginItem) dtb.Error!void {
    const node_depth = n.resulting_depth - 1;
    print_node(n, node_depth);

    const at = std.mem.indexOfScalar(u8, n.name, '@');
    const id = if (at) |i| n.name[0..i] else n.name;
    const addr = if (at) |i| n.name[i + 1 ..] else "";

    switch (device_type(id)) {
        .pl011 => {
            const addr_usize = std.fmt.parseInt(usize, addr, 16) catch {
                return dtb.Error.BadHex;
            };
            const prime = serial.PrimeCell.init(addr_usize);
            _ = prime;
        },
        .pl031 => {},
        .pcie => {},
        .memory => {},
        .other => {},
    }

    while (true) {
        const item = try w.next();
        switch (item) {
            .begin => |child| try consume_node(w, child),
            .property => |p| print_prop(p, n.resulting_depth),
            .nop => {},
            .end_node => return,
            .end => return dtb.Error.UnexpectedToken,
        }
    }
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
            dtb.Error.InvalidPropertyName => {
                serial.early_write("Property Name appears to exceed max length of 512. Probable address mistake") catch {};
            },
            dtb.Error.InvalidNodeToken => {
                serial.early_write("Invalid Token") catch {};
            },
            dtb.Error.BadHex => {
                serial.early_write("bad hex in address") catch {};
            },
        }
        serial.early_write("\n") catch {};
        return err;
    };
    var w = d.walker();
    while (true) {
        const item = try w.next();
        switch (item) {
            .begin => |n| {
                try consume_node(&w, n);
            },
            .property => |p| {
                print_prop(p, 0);
            },
            .nop => {},
            .end_node => {},
            .end => {
                serial.early_write("End tree\n") catch {};
                break;
            },
        }
    }
}

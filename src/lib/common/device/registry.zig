// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole
const std = @import("std");
const node = @import("arm64/dtb/node.zig"); // adjust import path to match your tree
const props = @import("arm64/dtb/properties.zig");
const device = @import("device.zig");

pub const DriverProbeFn = fn (n: node.Node) ?device.Device;

// List of compatible strings and a runtime probe function.
pub const DriverDesc = struct {
    compatibles: []const []const u8, // e.g. &["arm,pl011"], &["simple-framebuffer"]
    probe: DriverProbeFn,
};

// Example array built at compile-time; append driver descriptors here.
pub const drivers = [_]DriverDesc{
    .{ .compatibles = &[_][]const u8{"arm,pl011"}, .probe = pl011_probe },
    .{ .compatibles = &[_][]const u8{"simple-framebuffer"}, .probe = simple_framebuffer_probe },
    .{ .compatibles = &[_][]const u8{"virtio,mmio"}, .probe = virtio_blk_probe },
};

// Called by your DTB walk: try each driver for this node.
pub fn try_probe_node(n: node.Node) void {
    // If node has status == "disabled": skip (implement using n's properties).
    for (drivers) |drv| {
        // cheap compatible matching: check node.compatible property and each string
        for (drv.compatibles) |c| {
            if (node_compatible_contains(n, c)) {
                if (drv.probe(n)) |dev| {
                    // register_device from device.zig
                    _ = register_device(dev); // handle errors as you please
                    return; // stop at first successful probe (or continue to allow multiple)
                }
            }
        }
    }
}
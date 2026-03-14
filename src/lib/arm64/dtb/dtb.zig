// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

/// DTB parser entry point.
/// Validates the FDT header and provides a Walker for iterating nodes
/// and properties in the structure block.
/// Ref: Devicetree Specifications
/// https://devicetree-specification.readthedocs.io/en/stable/flattened-format.html
/// https://github.com/devicetree-org/devicetree-specification/releases/download/v0.4/devicetree-specification-v0.4.pdf

const std = @import("std");
pub const fdt = @import("fdt.zig");
pub const node = @import("node.zig");
pub const props = @import("properties.zig");

const Token = fdt.Token;
const PropHeader = fdt.PropHeader;
const Property = node.Property;

comptime {
    _ = std;
    _ = PropHeader;
}

pub const Error = error{
    InvalidMagic,
    InvalidVersion,
    UnexpectedToken,
    Truncated,
};

/// Validated DTB blob. Create with `Dtb.init(addr)`.
pub const Dtb = struct {
    base: usize,
    header: fdt.HeaderNative,

    pub fn init(addr: usize) Error!Dtb {
        _ = addr;
        @panic("unimplemented");
    }

    /// Returns a Walker over the structure block.
    pub fn walk(self: Dtb) Walker {
        _ = self;
        @panic("unimplemented");
    }
};

/// Iterates the FDT structure block token-by-token.
/// Usage:
///   var w = dtb.walk();
///   while (w.next_node()) |n| {
///       while (w.next_prop()) |p| { ... }
///   }
pub const Walker = struct {


    fn init(base: usize, header: fdt.HeaderNative) Walker {
        const struct_base = base + header.off_dt_struct;
        _ = struct_base;
        @panic("unimplemented");
    }

    /// Advance to the next BEGIN_NODE token.
    /// Returns the node name and depth, or null at end of tree.
    pub fn next_node(self: *Walker) ?node.Node {
        _ = self;
        @panic("unimplemented");
    }

    /// Read the next PROP token at the current cursor position.
    /// Must be called immediately after next_node() or a previous next_prop().
    /// Returns null when the current node's properties are exhausted.
    pub fn next_prop(self: *Walker) ?Property {
        _ = self;
        @panic("unimplemented");
    }

    // ---- private helpers ----

    fn read_token(self: *Walker) ?Token {
        _ = self;
        @panic("unimplemented");
    }

    fn read_name(self: *Walker) []const u8 {
        _ = self;
        @panic("unimplemented");
    }

    fn read_prop(self: *Walker) Property {
        _ = self;
        @panic("unimplemented");
    }

    fn skip_prop(self: *Walker) void {
        _ = self;
    }

    fn read_string(addr: usize) []const u8 {
        _ = addr;
        @panic("unimplemented");
    }
};

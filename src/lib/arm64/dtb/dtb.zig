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
const Node = node.Node;
const NodeToken = node.NodeToken;
const Property = node.Property;

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
        const hdr_ptr = fdt.Header.from_ptr(addr);

        if (!hdr_ptr.magic_valid()) {
            return Error.InvalidMagic;
        }
        if (!hdr_ptr.version_valid()) {
            return Error.InvalidVersion;
        }

        return Dtb{
            .base = addr,
            .header = hdr_ptr.native(),
        };
    }

    /// Returns a Walker over the structure block.
    pub fn walker(self: Dtb) Walker {
        return Walker.init(self.base, self.header.off_dt_struct, self.header.off_dt_strings);
    }
};

/// Iterates the FDT structure block token-by-token.
/// Usage:
///   var w = dtb.walk();
///   while (w.next_node()) |n| {
///       while (w.next_prop()) |p| { ... }
///   }
pub const Walker = struct {
    working_addr: usize,
    struct_base: usize,
    string_base: usize,

    fn init(base: usize, struct_offs: usize, string_offs: usize) Walker {
        const struct_base = base + struct_offs;
        const string_base = base + string_offs;
        return Walker{
            .struct_base = struct_base,
            .working_addr = struct_base,
            .string_base = string_base,
        };
    }

    /// Advance to the next BEGIN_NODE token.
    /// Returns the node name and depth, or null at end of tree.
    //
    // pub fn next_node(self: *Walker) Error|node.NodeToken {
    //     const t = NodeToken.init(self.working_addr) catch {};
    //     return t;
    // }

    pub fn first_node(self: *Walker) node.Token {
        return NodeToken.init(self.working_addr) catch node.Token.end_node;
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

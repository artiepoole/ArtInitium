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

const Token = node.Token;
const PropHeader = fdt.PropHeader;
const Node = node.Node;
const NodeToken = node.NodeToken;
const Property = node.Property;

pub const Error = error{
    InvalidMagic,
    InvalidVersion,
    UnexpectedToken,
    Truncated,
    InvalidPropertyName,
    InvalidNodeToken,
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
    working_addr: [*]const u8,
    struct_base: [*]const u8,
    string_base: [*]const u8,
    working_depth: usize,

    fn init(base: usize, struct_offs: usize, string_offs: usize) Walker {
        const struct_base = base + struct_offs;
        const string_base = base + string_offs;
        return Walker{
            .struct_base = @ptrFromInt(struct_base),
            .working_addr = @ptrFromInt(struct_base),
            .string_base = @ptrFromInt(string_base),
            .working_depth = 0,
        };
    }

    /// Advance to the next BEGIN_NODE token.
    /// Returns the node name and depth, or null at end of tree.
    pub fn next_node(self: *Walker) Error!?node.Node {
        const t: Token = NodeToken.init(self.working_addr) catch |err| {
            switch (err) {
                error.InvalidToken => {
                    return Error.InvalidNodeToken;
                },
            }
        };

        switch (t) {
            .begin_node => {
                // TODO factor out shared logic between node types
                var cur: [*]const u8 = @ptrCast(self.working_addr);
                cur += @sizeOf(u32);
                const name_loc = cur;

                var name_len: usize = 0;
                while (name_len < 32 and cur[name_len] != 0) : (name_len += 1) {}

                // If we hit the limit and still no NUL, name is invalid.
                if (name_len == 32 and cur[name_len] != 0) {
                    return Error.InvalidPropertyName;
                }

                const name: []const u8 = name_loc[0..name_len];
                cur += name_len + 1; // skip bytes of name + terminating NUL

                const addr = @intFromPtr(cur);
                const aligned_addr = std.mem.alignForward(usize, addr, @sizeOf(u32));
                cur = @ptrFromInt(aligned_addr);
                self.working_addr = @ptrCast(@constCast(cur));
                return Node{ ._prop_start = self.working_addr, .depth = self.working_depth, .name = name, .len = name_len };
            },

            .prop => {
                // todo advance working addr
                self.working_depth += 1;
                var cur: [*]const u8 = @ptrCast(self.working_addr);
                cur += @sizeOf(u32);
                const len: u32 = std.mem.readInt(u32, cur[0..4], .big);
                cur += @sizeOf(u32);
                const nameoff: u32 = std.mem.readInt(u32, cur[0..4], .big);
                const name_start: [*] const u8 = @ptrCast(&self.string_base[nameoff]);
                var name_len: usize = 0;
                while ((name_start[name_len] != 0 and name_len < 32)) {
                    name_len += 1;
                }


                cur += @sizeOf(u32);
                const prop_data: [*] const u32 = @alignCast(@ptrCast(cur));
                _ = prop_data;
                cur += len;
                const addr = @intFromPtr(cur);
                const aligned_addr = std.mem.alignForward(usize, addr, @sizeOf(u32));
                cur = @ptrFromInt(aligned_addr);
                self.working_addr = @ptrCast(@constCast(cur));

                return Node{ ._prop_start = self.working_addr, .depth = self.working_depth, .name = name_start[0..name_len], .len = len };
            },
            .nop => {
                self.working_addr += @sizeOf(u32);
                self.working_depth -|= 1;
                return Node{ ._prop_start = self.working_addr, .depth = self.working_depth, .name = "", .len = 0 };
            },
            .end_node => {
                self.working_addr += @sizeOf(u32);
                self.working_depth -|= 1;
                return Node{ ._prop_start = self.working_addr, .depth = self.working_depth, .name = "", .len = 0 };
            },
            .end => {
                // todo advance working addr
                return null;
            },
        }
        // todo: use this token to create a node like
        // A single decoded DTB node, as yielded by the Walker.
        // pub const Node = struct { init(addr, node_token) -> maps node tokens to real node types, and then converts them into Node type for convenience and printing)
        //
        return Error.UnexpectedToken;
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

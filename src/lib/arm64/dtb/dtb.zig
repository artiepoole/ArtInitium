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
    BadHex,
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

pub const Item = union(enum) {
    begin: struct {
        start: usize,
        token: Token,
        name: []const u8,
        name_len: usize,
        resulting_depth: usize,
    },
    property: struct {
        name: []const u8,
        name_len: usize,
        data: []const u8,
        data_len: usize,
    },
    nop: struct {
        start: usize,
    },
    end_node: struct {
        start: usize,
        resulting_depth: usize,
    },
    end,
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

    fn restart(self: *Walker) void {
        self.working_addr = self.struct_base;
        self.working_depth = 0;
    }

    /// Advance to the next BEGIN_NODE token.
    /// Returns the node name and depth, or null at end of tree.
    pub fn next(self: *Walker) Error!Item {
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
                self.working_depth += 1;
                const start = @intFromPtr(self.working_addr);
                var cur: [*]const u8 = @ptrCast(self.working_addr);
                cur += @sizeOf(u32);
                const name_loc = cur;

                var name_len: usize = 0;
                while (name_len < 32 and cur[name_len] != 0) : (name_len += 1) {}

                // If we hit the limit and still no NUL, name is invalid.
                if (name_len == 32 and cur[name_len] != 0) {
                    return Error.InvalidPropertyName;
                }
                cur += name_len + 1; // skip bytes of name + terminating NUL
                const name = name_loc[0..name_len];
                const addr = @intFromPtr(cur);
                const aligned_addr = std.mem.alignForward(usize, addr, @sizeOf(u32));
                cur = @ptrFromInt(aligned_addr);
                self.working_addr = cur;
                return Item{ .begin = .{
                    .start = start,
                    .token = t,
                    .resulting_depth = self.working_depth,
                    .name = name,
                    .name_len = name_len,
                } };
            },

            .prop => {
                var cur: [*]const u8 = @ptrCast(self.working_addr);
                cur += @sizeOf(u32);
                const len: u32 = std.mem.readInt(u32, cur[0..4], .big);
                cur += @sizeOf(u32);
                const nameoff: u32 = std.mem.readInt(u32, cur[0..4], .big);
                const name_start: [*]const u8 = @ptrCast(&self.string_base[@as(usize, nameoff)]);
                var name_len: usize = 0;
                while ((name_start[name_len] != 0 and name_len < 32)) {
                    name_len += 1;
                }
                const name = name_start[0..name_len];

                cur += @sizeOf(u32);
                const data_len: usize = @as(usize, len);
                const data: []const u8 = cur[0..data_len];
                cur += data_len;
                const addr = @intFromPtr(cur);
                const aligned_addr = std.mem.alignForward(usize, addr, @sizeOf(u32));
                cur = @ptrFromInt(aligned_addr);
                self.working_addr = cur;

                return Item{ .property = .{
                    .name = name,
                    .name_len = name_len,
                    .data = data,
                    .data_len = data_len,
                } };
            },
            .nop => {
                const start = @intFromPtr(self.working_addr);
                self.working_addr += @sizeOf(u32);
                return Item{ .nop = .{
                    .start = start,
                } };
            },
            .end_node => {
                const start = @intFromPtr(self.working_addr);
                self.working_addr += @sizeOf(u32);
                self.working_depth -|= 1;
                return Item{ .end_node = .{
                    .start = start,
                    .resulting_depth = self.working_depth,
                } };
            },
            .end => {
                return Item.end;
            },
        }
        return Error.UnexpectedToken;
    }
};

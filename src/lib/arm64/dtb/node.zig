// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

/// Decoded property value from a DTB node.
/// Properties are untyped byte arrays in the FDT — the meaning depends on
/// the property name and the node's compatible string.

const std = @import("std");

pub const Error = error{
InvalidToken,
};

/// FDT structure block token types.
pub const Token = enum(u32) {
    begin_node = 0x00000001, // Start of a node; followed by null-terminated name
    end_node = 0x00000002, // End of a node
    prop = 0x00000003, // Property; followed by PropHeader then data
    nop = 0x00000004, // No-op, skip
    end = 0x00000009, // End of structure block
};

pub const Property = struct {
    name: []const u8,
    data: []const u8,

    /// Decode as a single big-endian u32 (e.g. #address-cells, #size-cells).
    pub fn as_u32(self: Property) ?u32 {
        _ = self;
        @panic("unimplemented");
    }

    /// Decode as a single big-endian u64 (e.g. reg base addresses).
    pub fn as_u64(self: Property) ?u64 {
        _ = self;
        @panic("unimplemented");
    }

    /// Decode as a null-terminated string (e.g. compatible, status).
    pub fn as_str(self: Property) []const u8 {
        _ = self;
        @panic("unimplemented");
    }

    /// Check if a compatible property contains a given string.
    /// compatible is a list of null-separated strings.
    pub fn compatible_contains(self: Property, needle: []const u8) bool {
        _ = self;
        _ = needle;
        @panic("unimplemented");
    }
};

pub const NodeToken = struct {
    token: u32,

    pub fn init(addr: usize) Error!Token {
        // Form a pointer to the 32-bit big-endian word at `addr`.
        const p: *u32 = @ptrFromInt(addr);

        // Read the big-endian value and convert to native endian.
        const be_val: u32 = p.*;
        const v: u32 = std.mem.bigToNative(u32, be_val);

        // Match numeric token values to the Token enum.
        // Use @enumToInt to avoid hard-coding numbers.
        switch (v) {
            @intFromEnum(Token.begin_node) => return Token.begin_node,
            @intFromEnum(Token.end_node) => return Token.end_node,
            @intFromEnum(Token.prop) => return Token.prop,
            @intFromEnum(Token.nop) => return Token.nop,
            @intFromEnum(Token.end) => return Token.end,
            else => return Error.InvalidToken,
        }
    }

};

/// A single decoded DTB node, as yielded by the Walker.
pub const Node = struct {
    /// Node name (may include unit address, e.g. "pl011@9000000")
    name: []const u8,
    /// Nesting depth, 0 = root
    depth: u32,
    /// Raw byte slice of the property data region for this node.
    /// Iterate with Walker to extract individual properties.
    _prop_start: usize,
};

comptime { _ = std; }

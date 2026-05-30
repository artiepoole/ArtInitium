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

pub const NodeToken = struct {
    token: u32,

    pub fn init(addr: [*]const u8) Error!Token {
        // Form a pointer to the 32-bit big-endian word at `addr`.
        const p: [*]const u32 = @alignCast(@ptrCast(addr));

        // Read the big-endian value and convert to native endian.
        const be_val: u32 = p[0];
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

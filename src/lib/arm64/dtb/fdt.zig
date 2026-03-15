// ArtInitium - MultiArch Bootloader qemu
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Artie Poole

/// Raw FDT (Flattened Device Tree) structures and token definitions.
/// Ref: Devicetree Specification v0.4
/// https://devicetree-specification.readthedocs.io/en/latest/chapter5-flattened-format.html

const std = @import("std");

comptime { _ = std; }

pub const MAGIC: u32 = 0xd00dfeed;

/// FDT structure block token types.
pub const Token = enum(u32) {
    begin_node = 0x00000001, // Start of a node; followed by null-terminated name
    end_node   = 0x00000002, // End of a node
    prop       = 0x00000003, // Property; followed by PropHeader then data
    nop        = 0x00000004, // No-op, skip
    end        = 0x00000009, // End of structure block
};


/// Header preceding each FDT_PROP token's data in the structure block.
/// All fields are big-endian.
pub const PropHeader = extern struct {
    len: u32,      // Length of property data in bytes
    nameoff: u32,  // Offset into strings block for property name
};


/// Raw FDT header layout as it exists in memory — big-endian, no padding.
/// Safe to pointer-cast directly from the DTB blob address.
pub const HeaderRaw = extern struct {
    magic: u32,
    totalsize: u32,
    off_dt_struct: u32,
    off_dt_strings: u32,
    off_mem_rsvmap: u32,
    version: u32,
    last_comp_version: u32,
    boot_cpuid_phys: u32,
    size_dt_strings: u32,
    size_dt_struct: u32,
};

/// FDT header wrapper. Cast from a DTB blob address with `Header.from_ptr(addr)`.
/// Provides validation and conversion to native-endian `HeaderNative`.
pub const Header = struct {
    raw: *const HeaderRaw,

    /// Cast a raw memory address to a Header.
    pub fn from_ptr(addr: usize) Header {
        return .{ .raw = @ptrFromInt(addr) };
    }

    pub fn magic_valid(self: Header) bool {
        return std.mem.bigToNative(u32, self.raw.magic) == MAGIC;
    }

    pub fn native(self: Header) HeaderNative {
        return .{
            .totalsize         = std.mem.bigToNative(u32, self.raw.totalsize),
            .off_dt_struct     = std.mem.bigToNative(u32, self.raw.off_dt_struct),
            .off_dt_strings    = std.mem.bigToNative(u32, self.raw.off_dt_strings),
            .off_mem_rsvmap    = std.mem.bigToNative(u32, self.raw.off_mem_rsvmap),
            .version           = std.mem.bigToNative(u32, self.raw.version),
            .last_comp_version = std.mem.bigToNative(u32, self.raw.last_comp_version),
            .boot_cpuid_phys   = std.mem.bigToNative(u32, self.raw.boot_cpuid_phys),
            .size_dt_strings   = std.mem.bigToNative(u32, self.raw.size_dt_strings),
            .size_dt_struct    = std.mem.bigToNative(u32, self.raw.size_dt_struct),
        };
    }
};

/// Native-endian copy of the header fields for convenient use.
pub const HeaderNative = struct {
    totalsize: u32,
    off_dt_struct: u32,
    off_dt_strings: u32,
    off_mem_rsvmap: u32,
    version: u32,
    last_comp_version: u32,
    boot_cpuid_phys: u32,
    size_dt_strings: u32,
    size_dt_struct: u32,
};



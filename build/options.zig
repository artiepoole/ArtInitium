const std = @import("std");

pub const ArchOptions = struct {
    x86_32: bool,
    arm64: bool,

    pub fn parse(opt: []const u8) ArchOptions {
        var result = ArchOptions{ .x86_32 = false, .arm64 = false };
        var it = std.mem.splitScalar(u8, opt, ',');
        while (it.next()) |token| {
            const trimmed = std.mem.trim(u8, token, " ");
            if (std.mem.eql(u8, trimmed, "all")) {
                result.x86_32 = true;
                result.arm64 = true;
            } else if (std.mem.eql(u8, trimmed, "x86_32")) {
                result.x86_32 = true;
            } else if (std.mem.eql(u8, trimmed, "arm64")) {
                result.arm64 = true;
            } else if (std.mem.eql(u8, trimmed, "none")) {
                // Explicitly do nothing - keep all false
            }
        }
        return result;
    }
};

pub const OutOptions = struct {
    bin: bool,
    elf: bool,
    img: bool,
    dtb: bool,

    pub fn parse(opt: []const u8) OutOptions {
        var result = OutOptions{ .bin = false, .elf = false, .img = false, .dtb = false };
        var it = std.mem.splitScalar(u8, opt, ',');
        while (it.next()) |token| {
            const trimmed = std.mem.trim(u8, token, " ");
            if (std.mem.eql(u8, trimmed, "all")) {
                result.bin = true;
                result.elf = true;
                result.img = true;
                result.dtb = true;
            } else if (std.mem.eql(u8, trimmed, "bin")) {
                result.bin = true;
            } else if (std.mem.eql(u8, trimmed, "elf")) {
                result.elf = true;
            } else if (std.mem.eql(u8, trimmed, "img")) {
                result.img = true;
            } else if (std.mem.eql(u8, trimmed, "dtb")) {
                result.dtb = true;
            } else if (std.mem.eql(u8, trimmed, "none")) {
                // Explicitly do nothing - keep all false
            }
        }
        return result;
    }
};

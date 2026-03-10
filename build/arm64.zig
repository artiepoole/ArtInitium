const std = @import("std");
const options = @import("options.zig");

/// Build all ARM64 targets (currently a placeholder)
pub fn build(b: *std.Build, optimise: std.builtin.OptimizeMode, output_types: options.OutOptions) void {
    std.debug.print("We cannot build for arm64 yet, sorry.\n", .{});
    _ = b;
    _ = optimise;
    _ = output_types;
    return;
}

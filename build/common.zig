const std = @import("std");

/// Setup common build utilities like clean
pub fn setupCommonSteps(b: *std.Build) void {
    // Add clean step to remove build outputs
    const clean_step = b.addRemoveDirTree(b.path("zig-out"));
    const clean_cache = b.addRemoveDirTree(b.path(".zig-cache"));
    const clean = b.step("clean", "Remove build outputs");
    clean.dependOn(&clean_step.step);
    clean.dependOn(&clean_cache.step);
}

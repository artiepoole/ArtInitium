const std = @import("std");
const builtin = @import("builtin");

// Import build modules
const options = @import("build/options.zig");
const x86_32_build = @import("build/x86_32.zig");
const arm64_build = @import("build/arm64.zig");

pub fn build(b: *std.Build) void {
    const optimise = b.standardOptimizeOption(.{});

    const architectures_option = b.option(
        []const u8,
        "architectures",
        "Target architectures: x86_32, arm64, or 'all' (default: x86_32)",
    ) orelse "all";

    const architectures = options.ArchOptions.parse(architectures_option);

    const output_types_option = b.option(
        []const u8,
        "output_types",
        "Output types: bin, elf, img or 'all' (default: all)",
    ) orelse "all";

    const output_types = options.OutOptions.parse(output_types_option);

    const arm64_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .freestanding,
    });

    // just use it to avoid "unused variable" compile error for now, since we can't build arm64 yet
    _ = arm64_target;

    // Build x86_32 if requested
    if (architectures.x86_32) {
        x86_32_build.build(b, optimise, output_types);
        x86_32_build.buildTests(b);
    }

    // Build ARM64 if requested
    if (architectures.arm64) {
        arm64_build.build(b, optimise, output_types);
    }
}

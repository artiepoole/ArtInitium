const std = @import("std");
const builtin = @import("builtin");

// Import build modules
const options = @import("build/options.zig");
const common = @import("build/common.zig");
const x86_32_build = @import("build/x86_32.zig");
const arm64_build = @import("build/arm64.zig");

pub fn build(b: *std.Build) void {
    const optimise = b.standardOptimizeOption(.{});

    const architectures_option = b.option(
        []const u8,
        "architectures",
        "Target architectures: x86_32, arm64, all, or none (default: none)",
    ) orelse "none";

    const architectures = options.ArchOptions.parse(architectures_option);

    const output_types_option = b.option(
        []const u8,
        "outputs",
        "Output types: bin, elf, img, all, or none (default: none)",
    ) orelse "none";

    const output_types = options.OutOptions.parse(output_types_option);

    // Allow overriding the binman binary path, defaulting to the pipx install location.
    // Override with e.g. -Dbinman=/usr/bin/binman
    const binman = b.option(
        []const u8,
        "binman",
        "Path to the binman executable (default: ~/.local/bin/binman)",
    ) orelse (std.fs.path.join(b.allocator, &.{ b.graph.env_map.get("HOME") orelse "/root", ".local/bin/binman" }) catch @panic("OOM"));

    const build_selected = b.step("build_selected", "Build all requested architectures");

    // Build x86_32 if requested
    if (architectures.x86_32) {
        const step = x86_32_build.build(b, optimise, output_types, binman);
        x86_32_build.buildTests(b);
        build_selected.dependOn(step);
    }

    // Build ARM64 if requested
    if (architectures.arm64) {
        const step = arm64_build.build(b, optimise, output_types, binman);
        build_selected.dependOn(step);
    }

    b.default_step = build_selected;

    // Setup common build steps (clean, etc.)
    common.setupCommonSteps(b);
}

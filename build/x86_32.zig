const std = @import("std");
const options = @import("options.zig");

const RealModeArtifacts = struct {
    real_mode_exe: *std.Build.Step.Compile,
    stage1a_bin: std.Build.LazyPath,
    stage1b_bin: std.Build.LazyPath,
    binary_16_output: std.Build.LazyPath,
};
const ProtectedModeArtifacts = struct {
    elf_32_exe: *std.Build.Step.Compile,
    binary_32_output: std.Build.LazyPath,
};
const InstallSteps = struct {
    install_binary_16: ?*std.Build.Step.InstallFile,
    install_elf_16: ?*std.Build.Step.InstallArtifact,
    install_stage1a: ?*std.Build.Step.InstallFile,
    install_stage1b: ?*std.Build.Step.InstallFile,
    install_elf_32: ?*std.Build.Step.InstallArtifact,
    install_binary_32: ?*std.Build.Step.InstallFile,
    install_image: ?*std.Build.Step.InstallFile,
};

/// Build all x86_32 targets including 16-bit and 32-bit binaries and optionally the disk image
///
/// Tree for build_x86_32 target:
/// build_x86_32
/// ├── step_16
/// │   ├── install_binary_16
/// │   ├── install_elf_16
/// │   ├── install_stage1a
/// │   └── install_stage1b
/// ├── elf_32
/// │   └── install_elf_32
/// ├── step_32
/// │   └── install_binary_32
/// └── install_image
///     └── binman
///         ├── dtc
///         ├── stage1a_bin (dirname)
///         ├── stage1b_bin (dirname)
///         └── binary_32_output (dirname)
pub fn build(b: *std.Build, optimise: std.builtin.OptimizeMode, output_types: options.OutOptions) void {
    const out_bin = output_types.bin;
    const out_elf = output_types.elf;
    const out_img = output_types.img;

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.x86.cpu.i386 },
    });

    // ---------------------------------------------------------------
    // Build 16-bit binary
    // ---------------------------------------------------------------
    const real_mode_artifacts = build16BitBinaries(b, optimise, target);

    const install_stage1a = if (out_bin) b.addInstallFile(real_mode_artifacts.stage1a_bin, "bin/ArtInitium.16.x86_32.a") else null;
    const install_stage1b = if (out_bin) b.addInstallFile(real_mode_artifacts.stage1b_bin, "bin/ArtInitium.16.x86_32.b") else null;
    const install_binary_16 = if (out_bin) b.addInstallFile(real_mode_artifacts.binary_16_output, "bin/ArtInitium.16.x86_32") else null;
    const install_elf_16 = if (out_elf) b.addInstallArtifact(real_mode_artifacts.real_mode_exe, .{ .dest_dir = .{ .override = .{ .custom = "elf" } } }) else null;

    // ---------------------------------------------------------------
    // Build 32-bit binaries
    // ---------------------------------------------------------------
    const protected_mode_artifacts = build32BitBinaries(b, optimise, target);

    const install_elf_32 = if (out_elf) b.addInstallArtifact(protected_mode_artifacts.elf_32_exe, .{ .dest_dir = .{ .override = .{ .custom = "elf" } } }) else null;
    const install_binary_32 = if (out_bin) b.addInstallFile(protected_mode_artifacts.binary_32_output, "bin/ArtInitium.32.x86_32") else null;

    // ---------------------------------------------------------------
    // Assemble disk image using dtc + binman
    // ---------------------------------------------------------------
    const image_file = buildDiskImage(
        b,
        real_mode_artifacts.stage1a_bin,
        real_mode_artifacts.stage1b_bin,
        protected_mode_artifacts.binary_32_output,
    );
    const install_image = if (out_img) b.addInstallFile(image_file, "img/artinitium.x86_32.img") else null;

    // ---------------------------------------------------------------
    // Define `zig build [target]` targets
    // ---------------------------------------------------------------
    setupBuildSteps(b, .{
        .install_binary_16 = install_binary_16,
        .install_elf_16 = install_elf_16,
        .install_stage1a = install_stage1a,
        .install_stage1b = install_stage1b,
        .install_elf_32 = install_elf_32,
        .install_binary_32 = install_binary_32,
        .install_image = install_image,
    });
}



/// Build 16-bit real mode binaries (stage1a MBR, stage1b loader)
fn build16BitBinaries(
    b: *std.Build,
    optimise: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
) RealModeArtifacts {
    // Define the custom AS calls and their output object files
    const assemble_stage1a = b.addSystemCommand(&.{
        "as",
        "--32",
        "src/real_mode/x86_32/stage1a.S",
        "-o",
    });
    const assemble_stage1b = b.addSystemCommand(&.{
        "as",
        "--32",
        "src/real_mode/x86_32/stage1b.S",
        "-o",
    });
    const stage1a_obj = assemble_stage1a.addOutputFileArg("stage1a.o");
    const stage1b_obj = assemble_stage1b.addOutputFileArg("stage1b.o");

    // Define the executable as a linked target which zig should build
    const real_mode_module = b.createModule(.{ .target = target, .optimize = optimise });
    const real_mode_exe = b.addExecutable(.{ .name = "ArtInitium.16.x86_32.elf", .root_module = real_mode_module });
    real_mode_exe.setLinkerScript(b.path("linker_scripts/x86_32/real_mode.ld"));
    real_mode_exe.addObjectFile(stage1a_obj);
    real_mode_exe.addObjectFile(stage1b_obj);

    // Extract stage1a (MBR, first 512 bytes) from the linked ELF by section
    const objcopy_stage1a = b.addSystemCommand(&.{
        "objcopy", "--only-section=.stage1a", "-O", "binary",
    });
    objcopy_stage1a.addArtifactArg(real_mode_exe);
    const stage1a_bin = objcopy_stage1a.addOutputFileArg("ArtInitium.16.x86_32.a");

    // Extract stage1b (real-mode loader) from the linked ELF by section
    const objcopy_stage1b = b.addSystemCommand(&.{
        "objcopy", "--only-section=.stage1b", "-O", "binary",
    });
    objcopy_stage1b.addArtifactArg(real_mode_exe);
    const stage1b_bin = objcopy_stage1b.addOutputFileArg("ArtInitium.16.x86_32.b");

    // Also produce the combined flat binary (stage1a + stage1b) for reference
    const objcopy_16 = b.addSystemCommand(&.{
        "objcopy", "-O", "binary",
    });
    objcopy_16.addArtifactArg(real_mode_exe);
    const binary_16_output = objcopy_16.addOutputFileArg("ArtInitium.16.x86_32");

    return .{
        .real_mode_exe = real_mode_exe,
        .stage1a_bin = stage1a_bin,
        .stage1b_bin = stage1b_bin,
        .binary_16_output = binary_16_output,
    };
}



/// Build 32-bit protected mode binaries
fn build32BitBinaries(
    b: *std.Build,
    optimise: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
) ProtectedModeArtifacts {
    // Define the library module which contains all shared code
    const artlib_mod = b.addModule("artlib", .{
        .root_source_file = b.path("src/lib/root.zig"),
        .target = target,
    });

    // Define the protected mode executable elf file
    const elf_32_mod = b.createModule(
        .{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimise,
            .imports = &.{
                .{
                    .name = "artlib",
                    .module = artlib_mod,
                },
            },
        },
    );
    const elf_32_exe = b.addExecutable(
        .{
            .name = "ArtInitium.32.x86_32.elf",
            .root_module = elf_32_mod,
        },
    );

    // Use the custom linker script to load in at 64KB
    elf_32_exe.linker_script = b.path("linker_scripts/x86_32/protected_mode.ld");

    // Extract the binary executable from the elf for use in the image
    const objcopy_32 = b.addSystemCommand(&.{
        "objcopy",
        "-O",
        "binary",
    });
    objcopy_32.addArtifactArg(elf_32_exe);
    const binary_32_output = objcopy_32.addOutputFileArg("ArtInitium.32.x86_32");

    return .{
        .elf_32_exe = elf_32_exe,
        .binary_32_output = binary_32_output,
    };
}

/// Build disk image using dtc and binman
fn buildDiskImage(
    b: *std.Build,
    stage1a_bin: std.Build.LazyPath,
    stage1b_bin: std.Build.LazyPath,
    binary_32_output: std.Build.LazyPath,
) std.Build.LazyPath {
    // Compile the .its to a .dtb
    const dtc = b.addSystemCommand(&.{
        "dtc",
        "-I", "dts",
        "-O", "dtb",
        "-o",
    });
    const dtb_output = dtc.addOutputFileArg("artinium_x86_32.dtb");
    dtc.addArg("image_layouts/artinium_x86_32.its");

    // Run binman with the compiled .dtb, passing zig-tracked artifact dirs as inputs
    const binman = b.addSystemCommand(&.{ "binman", "build", "-d" });
    binman.addFileArg(dtb_output);
    // Pass the directories containing each artifact as -I so binman can find them by filename
    binman.addArg("-I");
    binman.addDirectoryArg(stage1a_bin.dirname());
    binman.addArg("-I");
    binman.addDirectoryArg(stage1b_bin.dirname());
    binman.addArg("-I");
    binman.addDirectoryArg(binary_32_output.dirname());
    // Capture output directory as a zig-tracked path
    binman.addArg("-O");
    const image_out_dir = binman.addOutputDirectoryArg("binman_out");

    // Reference the image file within the tracked output directory
    return image_out_dir.path(b, "artinitium.x86_32.img");
}



/// Setup all build step targets
fn setupBuildSteps(b: *std.Build, steps: InstallSteps) void {
    const step_16 = b.step("ArtInitium.16", "Build 16-bit binary");
    if (steps.install_binary_16) |s| step_16.dependOn(&s.step);
    if (steps.install_elf_16) |s| step_16.dependOn(&s.step);
    if (steps.install_stage1a) |s| step_16.dependOn(&s.step);
    if (steps.install_stage1b) |s| step_16.dependOn(&s.step);

    // Build the 32-bit executable as an elf file so that we can use it for debugging purposes.
    const elf_32 = b.step("ArtInitium.32.elf", "Build 32-bit binary");
    if (steps.install_elf_32) |s| elf_32.dependOn(&s.step);

    const step_32 = b.step("ArtInitium.32", "Build 32-bit raw binary");
    if (steps.install_binary_32) |s| step_32.dependOn(&s.step);

    // Default to build all x86_32 targets
    const build_x86_32 = b.step("build_x86_32", "Build all x86_32 binaries");
    b.default_step = build_x86_32;

    build_x86_32.dependOn(step_16);
    build_x86_32.dependOn(elf_32);
    build_x86_32.dependOn(step_32);
    if (steps.install_image) |s| build_x86_32.dependOn(&s.step);

    const make_image = b.step("make_image", "Assemble disk image using binman");
    make_image.dependOn(build_x86_32);
}

/// Create test target to run library unit tests on host
pub fn buildTests(b: *std.Build) void {
    const host_target = b.standardTargetOptions(.{});
    const artlib_test_mod = b.createModule(.{
        .root_source_file = b.path("src/lib/root.zig"),
        .target = host_target,
    });

    const mod_tests = b.addTest(.{
        .root_module = artlib_test_mod,
        .use_llvm = true,
        .use_lld = true,
    });

    const install_mod_tests = b.addInstallArtifact(
        mod_tests,
        .{
            .dest_dir = .{
                .override = .{
                    .custom = "test_artlib",
                },
            },
        },
    );

    const mod_tests_step = b.step("test_artlib", "Create test binaries for debugging 'root'");
    mod_tests_step.dependOn(&install_mod_tests.step);
}

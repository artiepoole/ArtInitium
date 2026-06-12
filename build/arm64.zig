const std = @import("std");
const options = @import("options.zig");

const Arm64Artifacts = struct {
    elf_exe: *std.Build.Step.Compile,
    bin: std.Build.LazyPath,
};

const InstallSteps = struct {
    install_elf: *std.Build.Step.InstallArtifact,
    install_bin: *std.Build.Step.InstallFile,
    install_dtb: *std.Build.Step.InstallFile,
    install_image: *std.Build.Step.InstallFile,
};

/// Build all ARM64 targets: ELF, raw binary, DTB and a flat QEMU image
///
/// The ARM64 build is simpler than x86_32 — there is only a single binary
/// (no real-mode stage), so the pipeline is:
///
///   1. Compile src/arch/arm64/start.zig + src/main.zig → ELF (via zig)
///   2. objcopy ELF → raw flat binary
///   3. dtc dts/qemu-virt-arm64.dts → qemu-virt-arm64.dtb
///   4. binman assembles binary → ArtInitium.arm64.img
///
/// Note: The DTB is NOT bundled in the image. QEMU generates its own DTB at
/// runtime and passes it in x0, or you can pass the compiled reference DTB
/// via `-dtb zig-out/dtb/qemu-virt-arm64.dtb` on the QEMU command line.
///
/// Tree for build_arm64 target:
/// build_arm64
/// ├── ArtInitium.arm64.elf (elf_arm64)
/// │   └── install_elf
/// ├── ArtInitium.arm64 (step_bin)
/// │   └── install_bin
/// ├── ArtInitium.arm64.dtb (step_dtb)
/// │   └── install_dtb
/// ├── make_image_arm64
/// └── install_image
///     └── binman
///         ├── dtc (image layout)
///         └── bin (dirname)
pub fn build(b: *std.Build, optimise: std.builtin.OptimizeMode, output_types: options.OutOptions, binman: []const u8) *std.Build.Step {
    const out_bin = output_types.bin;
    const out_elf = output_types.elf;
    const out_img = output_types.img;
    const out_dtb = output_types.dtb;

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.aarch64.cpu.cortex_a57 },
    });

    // ---------------------------------------------------------------
    // Build ARM64 ELF and raw binary
    // ---------------------------------------------------------------
    const arm64_artifacts = buildArm64Binaries(b, optimise, target);

    // Always create install steps so named steps (e.g. `zig build ArtInitium.arm64.elf`)
    // always work. The out_* flags only control whether the top-level `build_arm64` step
    // pulls them in automatically.
    const install_elf = b.addInstallArtifact(arm64_artifacts.elf_exe, .{
        .dest_dir = .{ .override = .{ .custom = "elf" } },
    });

    const install_bin = b.addInstallFile(arm64_artifacts.bin, "bin/ArtInitium.arm64");

    // ---------------------------------------------------------------
    // Compile DTS → DTB
    // ---------------------------------------------------------------
    const dtb = buildDtb(b);

    const install_dtb = b.addInstallFile(dtb, "dtb/qemu-virt-arm64.dtb");

    // ---------------------------------------------------------------
    // Assemble flat image using dtc + binman
    // ---------------------------------------------------------------
    const image_file = buildImage(b, binman, arm64_artifacts.bin);

    const install_image = b.addInstallFile(image_file, "img/ArtInitium.arm64.img");

    // ---------------------------------------------------------------
    // Define `zig build [target]` targets
    // ---------------------------------------------------------------
    return setupBuildSteps(
        b,
        out_bin,
        out_elf,
        out_img,
        out_dtb,
        .{
            .install_elf = install_elf,
            .install_bin = install_bin,
            .install_dtb = install_dtb,
            .install_image = install_image,
        },
    );
}

/// Compile the ARM64 ELF and extract a raw flat binary via objcopy
fn buildArm64Binaries(
    b: *std.Build,
    optimise: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
) Arm64Artifacts {
    // Shared library module
    const artlib_mod = b.addModule("artlib", .{
        .root_source_file = b.path("src/lib/root.zig"),
        .target = target,
    });

    // ARM64 executable module rooted at main.zig
    const elf_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimise,
        .imports = &.{
            .{
                .name = "artlib",
                .module = artlib_mod,
            },
        },
    });
    const elf_exe = b.addExecutable(.{
        .name = "ArtInitium.arm64.elf",
        .root_module = elf_mod,
    });
    elf_exe.linker_script = b.path("linker_scripts/arm64/arm64.ld");

    // Compile start.zig as a separate object so _start is always linked first
    const start_mod = b.createModule(.{
        .root_source_file = b.path("src/arch/arm64/start/start.zig"),
        .target = target,
        .optimize = optimise,
    });
    const start_obj = b.addObject(.{
        .name = "start",
        .root_module = start_mod,
    });
    elf_exe.addObject(start_obj);

    // Extract raw binary from the ELF using Zig's bundled `zig objcopy` — no external
    // tools required, works cross-architecture, and lets us control the output filename
    // so binman can find it by the name declared in the .its file.
    const objcopy = b.addSystemCommand(&.{
        b.graph.zig_exe, "objcopy", "-O", "binary",
    });
    objcopy.addArtifactArg(elf_exe);
    const bin = objcopy.addOutputFileArg("ArtInitium.arm64");

    return .{
        .elf_exe = elf_exe,
        .bin = bin,
    };
}

/// Compile the reference DTS into a DTB using dtc
fn buildDtb(b: *std.Build) std.Build.LazyPath {
    const dtc = b.addSystemCommand(&.{
        "dtc",
        "-I", "dts",
        "-O", "dtb",
        "-o",
    });
    const dtb = dtc.addOutputFileArg("qemu-virt-arm64.dtb");
    dtc.addArg("dts/qemu-virt-arm64.dts");
    return dtb;
}

/// Compile an image layout .its file into a .dtb for consumption by binman
fn buildImageLayout(b: *std.Build) std.Build.LazyPath {
    const dtc = b.addSystemCommand(&.{
        "dtc",
        "-I", "dts",
        "-O", "dtb",
        "-o",
    });
    const layout_dtb = dtc.addOutputFileArg("ArtInitium.arm64.dtb");
    dtc.addArg("image_layouts/ArtInitium.arm64.its");
    return layout_dtb;
}

/// Build the flat QEMU image using binman
fn buildImage(
    b: *std.Build,
    binman: []const u8,
    bin: std.Build.LazyPath,
) std.Build.LazyPath {
    const layout_dtb = buildImageLayout(b);

    // Run binman with zig-tracked artifact directories as inputs
    const binman_cmd = b.addSystemCommand(&[_][]const u8{ binman, "build", "-d" });
    binman_cmd.addFileArg(layout_dtb);
    binman_cmd.addArg("-I");
    binman_cmd.addDirectoryArg(bin.dirname());
    binman_cmd.addArg("-O");
    const image_out_dir = binman_cmd.addOutputDirectoryArg("binman_out");

    return image_out_dir.path(b, "artinitium.arm64.img");
}

/// Setup all build step targets
fn setupBuildSteps(b: *std.Build, out_bin: bool, out_elf: bool, out_img: bool, out_dtb: bool, steps: InstallSteps) *std.Build.Step {
    // Named steps always install their own artifact regardless of out_* flags
    const elf_step = b.step("ArtInitium.arm64.elf", "Build ARM64 ELF binary");
    elf_step.dependOn(&steps.install_elf.step);

    const bin_step = b.step("ArtInitium.arm64", "Build ARM64 raw binary");
    bin_step.dependOn(&steps.install_bin.step);

    const dtb_step = b.step("ArtInitium.arm64.dtb", "Compile ARM64 reference DTB");
    dtb_step.dependOn(&steps.install_dtb.step);

    const make_image = b.step("make_image_arm64", "Assemble ARM64 QEMU image using binman");
    make_image.dependOn(&steps.install_image.step);

    // Top-level step only pulls in what the out_* flags request
    const build_arm64 = b.step("build_arm64", "Build all ARM64 binaries and image");
    if (out_elf) build_arm64.dependOn(elf_step);
    if (out_bin) build_arm64.dependOn(bin_step);
    if (out_dtb) build_arm64.dependOn(dtb_step);
    if (out_img) build_arm64.dependOn(make_image);

    return build_arm64;
}

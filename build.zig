const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const t = target.result;
    const is_x86 = t.cpu.arch.isX86();
    const is_x86_64 = t.cpu.arch == .x86_64;
    const is_aarch64 = t.cpu.arch.isAARCH64();
    const is_arm = t.cpu.arch == .arm or t.cpu.arch == .armeb;

    const lib = b.addLibrary(.{
        .name = "x264",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = .static,
    });

    const x264_config = .{
        .X264_GPL = true,
        .X264_INTERLACED = true,
        .X264_BIT_DEPTH = 8,
        .X264_CHROMA_FORMAT = 0,
        .X264_BUILD = 164,
        .HAVE_GPL = true,
        .HAVE_INTERLACED = true,
        .HAVE_THREAD = true,
    };

    const config_h = .{
        .HAVE_THREAD = true,
        .HAVE_STDC_PURE_C = true,
        .ARCH_X86 = is_x86,
        .ARCH_X86_64 = is_x86_64,
        .ARCH_ARM = is_arm,
        .ARCH_AARCH64 = is_aarch64,
        .HAVE_MMX = have_x86_feat(t, .mmx),
        .HAVE_MMXEXT = have_x86_feat(t, .mmx),
        .HAVE_SSE = have_x86_feat(t, .sse),
        .HAVE_SSE2 = have_x86_feat(t, .sse2),
        .HAVE_SSE3 = have_x86_feat(t, .sse3),
        .HAVE_SSSE3 = have_x86_feat(t, .ssse3),
        .HAVE_SSE4 = have_x86_feat(t, .sse4_1),
        .HAVE_SSE42 = have_x86_feat(t, .sse4_2),
        .HAVE_AVX = have_x86_feat(t, .avx),
        .HAVE_AVX2 = have_x86_feat(t, .avx2),
        .HAVE_FMA3 = have_x86_feat(t, .fma),
        .HAVE_NEON = have_aarch64_feat(t, .neon) or have_arm_feat(t, .neon),
        .HAVE_BITDEPTH8 = true,
        .HIGH_BIT_DEPTH = false,
        .BIT_DEPTH = 8,
    };

    lib.root_module.addConfigHeader(b.addConfigHeader(.{ .style = .blank, .include_path = "x264_config.h" }, x264_config));
    lib.root_module.addConfigHeader(b.addConfigHeader(.{ .style = .blank, .include_path = "config.h" }, config_h));
    lib.root_module.addIncludePath(b.path("."));

    const flags = &.{
        "-DHAVE_CONFIG_H",
        "-DX264_VERSION=164",
        "-Wno-attributes",
        "-D__nonnull(x)=",
    };
    lib.root_module.addCSourceFiles(.{
        .files = &.{
            "common/osdep.c",
            "common/base.c",
            "common/cpu.c",
            "common/tables.c",
            "common/mc.c",
            "common/predict.c",
            "common/pixel.c",
            "common/macroblock.c",
            "common/frame.c",
            "common/dct.c",
            "common/cabac.c",
            "common/common.c",
            "common/rectangle.c",
            "common/set.c",
            "common/quant.c",
            "common/deblock.c",
            "common/vlc.c",
            "common/mvpred.c",
            "common/bitstream.c",
            "encoder/api.c",
            "encoder/analyse.c",
            "encoder/me.c",
            "encoder/ratecontrol.c",
            "encoder/set.c",
            "encoder/macroblock.c",
            "encoder/cabac.c",
            "encoder/cavlc.c",
            "encoder/encoder.c",
            "encoder/lookahead.c",
        },
        .flags = flags,
    });
    lib.root_module.addCSourceFiles(.{
        .files = if (t.os.tag == .windows) &.{"common/win32thread.c"} else &.{"common/threadpool.c"},
        .flags = flags,
    });

    if (is_x86) {
        lib.root_module.addCSourceFiles(.{
            .files = &.{ "common/x86/mc-c.c", "common/x86/predict-c.c" },
            .flags = flags,
        });
        const nasm = b.dependency("nasm", .{ .optimize = optimize }).artifact("nasm");
        inline for (&[_][]const u8{
            "common/x86/cpu-a.asm",
            "common/x86/bitstream-a.asm",
            "common/x86/const-a.asm",
            "common/x86/cabac-a.asm",
            "common/x86/dct-a.asm",
            "common/x86/deblock-a.asm",
            "common/x86/mc-a.asm",
            "common/x86/mc-a2.asm",
            "common/x86/pixel-a.asm",
            "common/x86/predict-a.asm",
            "common/x86/quant-a.asm",
            "common/x86/dct-32.asm",
            "common/x86/dct-64.asm",
        }) |asm_file| {
            const nasm_run = b.addRunArtifact(nasm);
            nasm_run.addArgs(&.{ "-f", "elf64" });
            nasm_run.addArgs(&.{ "-d", "ARCH_X86_64=1" });
            nasm_run.addArgs(&.{ "-d", "ARCH_X86=1" });
            nasm_run.addArgs(&.{ "-d", "HAVE_MMX=1" });
            nasm_run.addArgs(&.{ "-d", "HAVE_MMX2=1" });
            nasm_run.addArgs(&.{ "-d", "HAVE_SSE=1" });
            nasm_run.addArgs(&.{ "-d", "HAVE_SSE2=1" });
            if (have_x86_feat(t, .sse3)) nasm_run.addArgs(&.{ "-d", "HAVE_SSE3=1" });
            if (have_x86_feat(t, .ssse3)) nasm_run.addArgs(&.{ "-d", "HAVE_SSSE3=1" });
            if (have_x86_feat(t, .sse4_1)) nasm_run.addArgs(&.{ "-d", "HAVE_SSE4=1" });
            if (have_x86_feat(t, .avx)) nasm_run.addArgs(&.{ "-d", "HAVE_AVX=1" });
            if (have_x86_feat(t, .avx2)) nasm_run.addArgs(&.{ "-d", "HAVE_AVX2=1" });
            if (have_x86_feat(t, .fma)) nasm_run.addArgs(&.{ "-d", "HAVE_FMA3=1" });
            nasm_run.addArgs(&.{ "-d", "HAVE_BITDEPTH8=1" });
            nasm_run.addArgs(&.{ "-d", "HIGH_BIT_DEPTH=0" });
            nasm_run.addArgs(&.{ "-d", "BIT_DEPTH=8" });
            nasm_run.addArgs(&.{ "-d", "X264_VERSION=164" });
            nasm_run.addArgs(&.{ "-I", b.path("common/x86/").getPath(b) });
            nasm_run.addArgs(&.{ "-o", b.fmt("zig-out/lib/{s}.o", .{std.fs.path.basename(asm_file)}) });
            nasm_run.addFileArg(b.path(asm_file));
        }
    } else if (is_aarch64) {
        lib.root_module.addCSourceFiles(.{ .files = &.{
            "common/aarch64/mc-c.c",
            "common/aarch64/predict-c.c",
            "common/aarch64/asm-offsets.c",
        }, .flags = flags });
        lib.root_module.addAssemblyFile(b.path("common/aarch64/bitstream-a.S"));
        lib.root_module.addAssemblyFile(b.path("common/aarch64/cabac-a.S"));
        lib.root_module.addAssemblyFile(b.path("common/aarch64/dct-a.S"));
        lib.root_module.addAssemblyFile(b.path("common/aarch64/deblock-a.S"));
        lib.root_module.addAssemblyFile(b.path("common/aarch64/mc-a.S"));
        lib.root_module.addAssemblyFile(b.path("common/aarch64/pixel-a.S"));
        lib.root_module.addAssemblyFile(b.path("common/aarch64/predict-a.S"));
        lib.root_module.addAssemblyFile(b.path("common/aarch64/quant-a.S"));
    }

    b.installArtifact(lib);
}

fn have_x86_feat(t: std.Target, f: std.Target.x86.Feature) bool {
    return switch (t.cpu.arch) {
        .x86, .x86_64 => std.Target.x86.featureSetHas(t.cpu.features, f),
        else => false,
    };
}
fn have_aarch64_feat(t: std.Target, f: std.Target.aarch64.Feature) bool {
    return switch (t.cpu.arch) {
        .aarch64, .aarch64_be => std.Target.aarch64.featureSetHas(t.cpu.features, f),
        else => false,
    };
}
fn have_arm_feat(t: std.Target, f: std.Target.arm.Feature) bool {
    return switch (t.cpu.arch) {
        .arm, .armeb => std.Target.arm.featureSetHas(t.cpu.features, f),
        else => false,
    };
}

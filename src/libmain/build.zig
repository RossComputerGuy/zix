const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const linkage = b.option(std.builtin.LinkMode, "linkage", "The link mode of binaries");
    const fsys_libutil = b.systemIntegrationOption("nix-util", .{});
    const fsys_libstore = b.systemIntegrationOption("nix-store", .{});
    const use_meson_libs = std.mem.eql(u8, b.graph.env_map.get("USE_MESON_LIBS") orelse "0", "1");

    const config = b.addConfigHeader(.{
        .include_path = "config-main.hh",
    }, .{
        .HAVE_PUBSETBUF = 1,
    });

    const libmain = std.Build.Step.Compile.create(b, .{
        .name = "nixmain",
        .kind = .lib,
        .linkage = linkage,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });

    libmain.addConfigHeader(config);
    libmain.addIncludePath(b.path("."));

    libmain.root_module.addCMacro("SYSTEM", b.fmt("\"{s}-{s}\"", .{
        @tagName(target.result.cpu.arch),
        @tagName(target.result.os.tag),
    }));

    libmain.addCSourceFiles(.{
        .files = &.{
            "common-args.cc",
            "loggers.cc",
            "plugin.cc",
            "progress-bar.cc",
            "shared.cc",
        },
        .flags = &.{
            "--std=c++2a",
            b.fmt("-I{s}", .{std.mem.trimRight(u8, b.run(&.{ "pkg-config", "--variable=includedir", "boost" }), "\n")}),
        },
    });

    if (target.result.os.tag == .windows) {
        libmain.addCSourceFile(.{
            .file = b.path("unix/stack.cc"),
            .flags = &.{
                "--std=c++2a",
                b.fmt("-I{s}", .{std.mem.trimRight(u8, b.run(&.{ "pkg-config", "--variable=includedir", "boost" }), "\n")}),
            },
        });
    }

    libmain.installHeader(config.getOutput(), "nix/config-main.hh");

    if (fsys_libutil) {
        if (use_meson_libs) {
            libmain.linkSystemLibrary("nixutil");

            for (b.search_prefixes.items) |prefix| {
                const path = b.pathJoin(&.{ prefix, "include", "nix" });

                var dir = std.fs.cwd().openDir(path, .{}) catch continue;
                defer dir.close();

                libmain.root_module.addSystemIncludePath(.{ .cwd_relative = path });
            }

            libmain.linkSystemLibrary("libarchive");
            libmain.linkSystemLibrary("boost");
            libmain.linkSystemLibrary("nlohmann_json");
        } else {
            libmain.linkSystemLibrary("nix-util");
        }
    } else {
        const libutil = b.dependency("nix-util", .{
            .target = target,
            .optimize = optimize,
            .linkage = linkage orelse .static,
        });

        libmain.linkLibrary(libutil.artifact("nixutil"));

        for (libutil.artifact("nixutil").root_module.include_dirs.items) |hdr| {
            libmain.root_module.include_dirs.append(b.allocator, hdr) catch @panic("OOM");
        }

        libmain.linkSystemLibrary("libarchive");
        libmain.linkSystemLibrary("boost");
        libmain.linkSystemLibrary("nlohmann_json");
    }

    if (fsys_libstore) {
        if (use_meson_libs) {
            libmain.linkSystemLibrary("nixstore");

            for (b.search_prefixes.items) |prefix| {
                const path = b.pathJoin(&.{ prefix, "include", "nix" });

                var dir = std.fs.cwd().openDir(path, .{}) catch continue;
                defer dir.close();

                libmain.root_module.addSystemIncludePath(.{ .cwd_relative = path });
            }
        } else {
            libmain.linkSystemLibrary("nix-store");
        }
    } else {
        const libstore = b.dependency("nix-store", .{
            .target = target,
            .optimize = optimize,
            .linkage = linkage orelse .static,
        });

        libmain.linkLibrary(libstore.artifact("nixstore"));

        for (libstore.artifact("nixstore").root_module.include_dirs.items) |hdr| {
            libmain.root_module.include_dirs.append(b.allocator, hdr) catch @panic("OOM");
        }
    }

    inline for (&.{
        "common-args.hh",
        "loggers.hh",
        "plugin.hh",
        "progress-bar.hh",
        "shared.hh",
    }) |hdr| {
        libmain.installHeader(b.path(hdr), "nix/" ++ hdr);
    }

    b.installArtifact(libmain);

    b.getInstallStep().dependOn(&b.addInstallFileWithDir(b.addWriteFile("nix-main.pc", b.fmt(
        \\prefix={s}
        \\libdir={s}
        \\includedir={s}
        \\
        \\Name: Nix
        \\Description: Nix Package Manager
        \\Version: 0.1.0
        \\Cflags: -I${{includedir}}/nix -std=c++2a
        \\Libs: -L${{libdir}} -lnixmain
    , .{
        b.getInstallPath(.prefix, ""),
        b.getInstallPath(.lib, ""),
        b.getInstallPath(.header, ""),
    })).getDirectory().path(b, "nix-main.pc"), .lib, "pkgconfig/nix-main.pc").step);
}

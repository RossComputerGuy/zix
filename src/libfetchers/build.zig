const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const linkage = b.option(std.builtin.LinkMode, "linkage", "The link mode of binaries");
    const fsys_libutil = b.systemIntegrationOption("nix-util", .{});
    const fsys_libstore = b.systemIntegrationOption("nix-store", .{});
    const use_meson_libs = std.mem.eql(u8, b.graph.env_map.get("USE_MESON_LIBS") orelse "0", "1");

    const libfetchers = std.Build.Step.Compile.create(b, .{
        .name = "nixfetchers",
        .kind = .lib,
        .linkage = linkage,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });

    libfetchers.root_module.addCMacro("SYSTEM", b.fmt("\"{s}-{s}\"", .{
        @tagName(target.result.cpu.arch),
        @tagName(target.result.os.tag),
    }));

    libfetchers.addIncludePath(b.path("."));

    libfetchers.addCSourceFiles(.{
        .files = &.{
            "attrs.cc",
            "cache.cc",
            "fetch-settings.cc",
            "fetch-to-store.cc",
            "fetchers.cc",
            "filtering-source-accessor.cc",
            "git-lfs-fetch.cc",
            "git-utils.cc",
            "git.cc",
            "github.cc",
            "indirect.cc",
            "mercurial.cc",
            "path.cc",
            "registry.cc",
            "store-path-accessor.cc",
            "tarball.cc",
        },
        .flags = &.{
            "--std=c++2a",
            b.fmt("-I{s}", .{std.mem.trimRight(u8, b.run(&.{ "pkg-config", "--variable=includedir", "boost" }), "\n")}),
        },
    });

    libfetchers.linkSystemLibrary("nlohmann_json");
    libfetchers.linkSystemLibrary("libgit2");

    if (fsys_libutil) {
        if (use_meson_libs) {
            libfetchers.linkSystemLibrary("nixutil");

            for (b.search_prefixes.items) |prefix| {
                const path = b.pathJoin(&.{ prefix, "include", "nix" });

                var dir = std.fs.cwd().openDir(path, .{}) catch continue;
                defer dir.close();

                libfetchers.root_module.addSystemIncludePath(.{ .cwd_relative = path });
            }

            libfetchers.linkSystemLibrary("libarchive");
            libfetchers.linkSystemLibrary("boost");
            libfetchers.linkSystemLibrary("nlohmann_json");
        } else {
            libfetchers.linkSystemLibrary("nix-util");
        }
    } else {
        const libutil = b.dependency("nix-util", .{
            .target = target,
            .optimize = optimize,
            .linkage = linkage orelse .static,
        });

        libfetchers.linkLibrary(libutil.artifact("nixutil"));

        for (libutil.artifact("nixutil").root_module.include_dirs.items) |hdr| {
            libfetchers.root_module.include_dirs.append(b.allocator, hdr) catch @panic("OOM");
        }

        libfetchers.linkSystemLibrary("libarchive");
        libfetchers.linkSystemLibrary("boost");
        libfetchers.linkSystemLibrary("nlohmann_json");
    }

    if (fsys_libstore) {
        if (use_meson_libs) {
            libfetchers.linkSystemLibrary("nixstore");

            for (b.search_prefixes.items) |prefix| {
                const path = b.pathJoin(&.{ prefix, "include", "nix" });

                var dir = std.fs.cwd().openDir(path, .{}) catch continue;
                defer dir.close();

                libfetchers.root_module.addSystemIncludePath(.{ .cwd_relative = path });
            }
        } else {
            libfetchers.linkSystemLibrary("nix-store");
        }
    } else {
        const libstore = b.dependency("nix-store", .{
            .target = target,
            .optimize = optimize,
            .linkage = linkage orelse .static,
        });

        libfetchers.linkLibrary(libstore.artifact("nixstore"));

        for (libstore.artifact("nixstore").root_module.include_dirs.items) |hdr| {
            libfetchers.root_module.include_dirs.append(b.allocator, hdr) catch @panic("OOM");
        }
    }

    inline for (&.{
        "attrs.hh",
        "cache.hh",
        "fetch-settings.hh",
        "fetch-to-store.hh",
        "fetchers.hh",
        "filtering-source-accessor.hh",
        "git-lfs-fetch.hh",
        "git-utils.hh",
        "registry.hh",
        "store-path-accessor.hh",
        "tarball.hh",
    }) |hdr| {
        libfetchers.installHeader(b.path(hdr), "nix/" ++ hdr);
    }

    b.installArtifact(libfetchers);

    b.getInstallStep().dependOn(&b.addInstallFileWithDir(b.addWriteFile("nix-fetchers.pc", b.fmt(
        \\prefix={s}
        \\libdir={s}
        \\includedir={s}
        \\
        \\Name: Nix
        \\Description: Nix Package Manager
        \\Version: 0.1.0
        \\Cflags: -I${{includedir}}/nix -std=c++2a
        \\Libs: -L${{libdir}} -lnixfetchers
    , .{
        b.getInstallPath(.prefix, ""),
        b.getInstallPath(.lib, ""),
        b.getInstallPath(.header, ""),
    })).getDirectory().path(b, "nix-fetchers.pc"), .lib, "pkgconfig/nix-fetchers.pc").step);
}

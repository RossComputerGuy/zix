{
  lib,
  stdenv,
  mkMesonLibrary,

  unixtools,
  darwin,

  nix-util,
  boost,
  curl,
  aws-sdk-cpp,
  libseccomp,
  nlohmann_json,
  sqlite,

  busybox-sandbox-shell ? null,

  # Configuration Options

  version,
  nixVersion,

  embeddedSandboxShell ? stdenv.hostPlatform.isStatic,
}:

let
  inherit (lib) fileset;
in

mkMesonLibrary (finalAttrs: {
  pname = "zix-store";
  inherit version nixVersion;

  workDir = ./.;
  fileset = fileset.unions [
    ../../nix-meson-build-support
    ./nix-meson-build-support
    ../../.version
    ./.version
    ../../.zix-version
    ./.zix-version
    ./meson.build
    ./meson.options
    ./linux/meson.build
    ./unix/meson.build
    ./windows/meson.build
    (fileset.fileFilter (file: file.hasExt "cc") ./.)
    (fileset.fileFilter (file: file.hasExt "hh") ./.)
    (fileset.fileFilter (file: file.hasExt "sb") ./.)
    (fileset.fileFilter (file: file.hasExt "md") ./.)
    (fileset.fileFilter (file: file.hasExt "sql") ./.)
    (fileset.fileFilter (file: file.hasExt "zig") ./.)
  ];

  nativeBuildInputs = lib.optional embeddedSandboxShell unixtools.hexdump;

  buildInputs =
    [
      boost
      curl
      sqlite
    ]
    ++ lib.optional stdenv.hostPlatform.isLinux libseccomp
    # There have been issues building these dependencies
    ++ lib.optional stdenv.hostPlatform.isDarwin darwin.apple_sdk.libs.sandbox
    ++ lib.optional (
      stdenv.hostPlatform == stdenv.buildPlatform && (stdenv.isLinux || stdenv.isDarwin)
    ) aws-sdk-cpp;

  propagatedBuildInputs = [
    nix-util
    nlohmann_json
  ];

  mesonFlags =
    [
      (lib.mesonEnable "seccomp-sandboxing" stdenv.hostPlatform.isLinux)
      (lib.mesonBool "embedded-sandbox-shell" embeddedSandboxShell)
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      (lib.mesonOption "sandbox-shell" "${busybox-sandbox-shell}/bin/busybox")
    ];

  env = {
    # Needed for Meson to find Boost.
    # https://github.com/NixOS/nixpkgs/issues/86131.
    BOOST_INCLUDEDIR = "${lib.getDev boost}/include";
    BOOST_LIBRARYDIR = "${lib.getLib boost}/lib";
  };

  meta = {
    platforms = lib.platforms.unix ++ lib.platforms.windows;
  };

})

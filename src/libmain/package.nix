{
  lib,
  mkZigLibrary,

  nix-util,
  nix-store,

  # Configuration Options

  version,
  nixVersion,
}:

let
  inherit (lib) fileset;
in

mkZigLibrary (finalAttrs: {
  pname = "zix-main";
  inherit version nixVersion;

  workDir = ./.;
  fileset = fileset.unions [
    ../libutil
    ../libstore
    ../../nix-meson-build-support
    ./nix-meson-build-support
    ../../.version
    ./.version
    ../../.zix-version
    ./.zix-version
    ./meson.build
    ./meson.options
    (fileset.fileFilter (file: file.hasExt "cc") ./.)
    (fileset.fileFilter (file: file.hasExt "hh") ./.)
    (fileset.fileFilter (file: file.hasExt "zig") ./.)
    (fileset.fileFilter (file: file.hasExt "zon") ./.)
  ];

  propagatedBuildInputs = [
    nix-util
    nix-store
  ];

  zigBuildFlags = [
    "-fsys=nix-util"
    "-fsys=nix-store"
  ];

  postInstall = ''
    substituteInPlace $out/lib/pkgconfig/nix-main.pc \
      --replace-fail "includedir=$out" "includedir=$dev"
  '';

  meta = {
    platforms = lib.platforms.unix ++ lib.platforms.windows;
  };

})

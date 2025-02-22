{
  lib,
  buildPackages,
  stdenv,
  mkMesonExecutable,

  nix-expr,
  nix-expr-c,
  nix-expr-test-support,

  rapidcheck,
  gtest,
  runCommand,

  # Configuration Options

  version,
  nixVersion,
  resolvePath,
}:

let
  inherit (lib) fileset;
in

mkMesonExecutable (finalAttrs: {
  pname = "zix-expr-tests";
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
    (fileset.fileFilter (file: file.hasExt "cc") ./.)
    (fileset.fileFilter (file: file.hasExt "hh") ./.)
  ];

  buildInputs = [
    nix-expr
    nix-expr-c
    nix-expr-test-support
    rapidcheck
    gtest
  ];

  mesonFlags = [
  ];

  passthru = {
    tests = {
      run =
        runCommand "${finalAttrs.pname}-run"
          {
            meta.broken = !stdenv.hostPlatform.emulatorAvailable buildPackages;
          }
          (
            lib.optionalString stdenv.hostPlatform.isWindows ''
              export HOME="$PWD/home-dir"
              mkdir -p "$HOME"
            ''
            + ''
              export _NIX_TEST_UNIT_DATA=${resolvePath ./data}
              ${stdenv.hostPlatform.emulator buildPackages} ${lib.getExe finalAttrs.finalPackage}
              touch $out
            ''
          );
    };
  };

  meta = {
    platforms = lib.platforms.unix ++ lib.platforms.windows;
    mainProgram = "nix-expr-tests${stdenv.hostPlatform.extensions.executable}";
  };

})

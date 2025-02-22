project('nix-util-c',
  version : files('.zix-version'),
  default_options : [
    # TODO(Qyriad): increase the warning level
    'warning_level=1',
    'errorlogs=true', # Please print logs for tests that fail
  ],
  meson_version : '>= 1.1',
  license : 'LGPL-2.1-or-later',
)

fs = import('fs')

subdir('nix-meson-build-support/zig')

zig_prefix = meson.current_build_dir() / 'zig-out'

deps = []

libutil = dependency('nix-util', required: false)
if libutil.found()
  deps += libutil
  zig_build_args += [
    '-fsys=nix-util',
    '--search-prefix', libutil.get_variable('prefix'),
    '--search-prefix', fs.parent(libutil.get_variable('includedir')),
    '--search-prefix', fs.parent(libutil.get_variable('libdir')),
  ]
endif

zig_target = custom_target('zig build',
  output: ['zig-out'],
  command: [zig, 'build', zig_build_args, '--prefix', zig_prefix, '--build-file', meson.project_source_root() / 'build.zig'],
  env: {
    'USE_MESON_LIBS': '1',
  },
)

includedir = zig_prefix / 'include' / 'nix'
compile_args = ['-I' + includedir]

install_subdir(zig_prefix / 'lib', install_dir: get_option('libdir'), strip_directory: true)
install_subdir(zig_prefix / 'include', install_dir: get_option('includedir'), strip_directory: true)

meson.override_dependency('nix-util-c', declare_dependency(
  compile_args: compile_args,
  link_args: ['-L' + zig_prefix / 'lib', '-lnixutilc'],
  dependencies: deps,
  sources: [zig_target],
))

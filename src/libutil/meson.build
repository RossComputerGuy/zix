project('nix-util',
  version : files('.zix-version'),
  default_options : [
    'warning_level=1',
    'errorlogs=true', # Please print logs for tests that fail
  ],
  meson_version : '>= 1.1',
  license : 'LGPL-2.1-or-later',
)

subdir('nix-meson-build-support/zig')

zig_prefix = meson.current_build_dir() / 'zig-out'

zig_target = custom_target('zig build',
  output: ['zig-out'],
  command: [zig, 'build', zig_build_args, '--prefix', zig_prefix, '--build-file', meson.project_source_root() / 'build.zig'],
)

includedir = zig_prefix / 'include' / 'nix'
compile_args = ['-I' + includedir]

install_subdir(zig_prefix / 'lib', install_dir: get_option('libdir'), strip_directory: true)
install_subdir(zig_prefix / 'include', install_dir: get_option('includedir'), strip_directory: true)

meson.override_dependency('nix-util', declare_dependency(
  compile_args: compile_args,
  link_args: ['-L' + zig_prefix / 'lib', '-lnixutil'],
  sources: [zig_target],
  variables: {
    'prefix': zig_prefix,
    'includedir': zig_prefix / 'include',
    'libdir': zig_prefix / 'lib',
  },
))

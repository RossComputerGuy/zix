project('nix-store',
  version : files('.zix-version'),
  default_options : [
    # TODO(Qyriad): increase the warning level
    'warning_level=1',
    'errorlogs=true', # Please print logs for tests that fail
    'localstatedir=/nix/var',
  ],
  meson_version : '>= 1.1',
  license : 'LGPL-2.1-or-later',
)

fs = import('fs')

subdir('nix-meson-build-support/zig')

zig_prefix = meson.current_build_dir() / 'zig-out'

aws_s3 = dependency('aws-cpp-sdk-s3', required : false)
busybox = find_program(get_option('sandbox-shell'), required : false)

zig_build_args += [
  '-Dlog-path=' + get_option('log-dir'),
  '-Dstore-path=' + get_option('store-dir'),
  '-Dsandbox-shell=' + busybox.full_path(),
]

if get_option('embedded-sandbox-shell')
  zig_build_args += ['-Dembedded-sandbox-shell=true']
else
  zig_build_args += ['-Dembedded-sandbox-shell=false']
endif

if aws_s3.found()
  zig_build_args += ['-Ds3=true']
else
  zig_build_args += ['-Ds3=false']
endif

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

meson.override_dependency('nix-store', declare_dependency(
  compile_args: compile_args,
  link_args: ['-L' + zig_prefix / 'lib', '-lnixstore'],
  sources: [zig_target],
  dependencies: deps,
  variables: {
    'prefix': zig_prefix,
    'includedir': zig_prefix / 'include',
    'libdir': zig_prefix / 'lib',
    'storedir': get_option('store-dir')
  }
))

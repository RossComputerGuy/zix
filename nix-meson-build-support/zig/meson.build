zig = find_program('zig')
zig_target = target_machine.cpu_family() + '-'

if target_machine.system() == 'darwin'
  zig_target += target_machine.subsystem()
else
  zig_target += target_machine.system()
endif

zig_target += '-' + get_option('abi')

zig_args = [
  '--cache-dir', meson.current_build_dir() / 'zig-cache',
  '--global-cache-dir', meson.project_build_root() / 'zig-cache',
  '-target', zig_target,
]

if get_option('debug') or get_option('optimization') == 'plain'
  zig_args += ['-O', 'Debug']
elif get_option('optimization') == '2'
  zig_args += ['-O', 'ReleaseFast']
elif get_option('optimization') == '3'
  zig_args += ['-O', 'ReleaseSafe']
elif get_option('optimization') == 's'
  zig_args += ['-O', 'ReleaseSmall']
endif

dep_scanner = dependency('wayland-scanner', native: true)
prog_scanner = find_program(dep_scanner.get_variable(pkgconfig: 'wayland_scanner'))

protocol_file = files('pantheon-desktop-shell-v1.xml')

pantheon_desktop_shell_sources = []
pantheon_desktop_shell_sources += custom_target(
	'pantheon-desktop-shell-server-protocol.h',
	command: [ prog_scanner, 'server-header', '@INPUT@', '@OUTPUT@' ],
	input: protocol_file,
	output: 'pantheon-desktop-shell-server-protocol.h',
)

output_type = 'private-code'
if dep_scanner.version().version_compare('< 1.14.91')
    output_type = 'code'
endif
pantheon_desktop_shell_sources += custom_target(
	'pantheon-desktop-shell-protocol.c',
	command: [ prog_scanner, output_type, '@INPUT@', '@OUTPUT@' ],
	input: protocol_file,
	output: 'pantheon-desktop-shell-protocol.c',
)

pantheon_desktop_shell_dep = declare_dependency(
    dependencies: [
        vala.find_library('pantheon-desktop-shell', dirs: meson.current_source_dir()),
        dependency('wayland-server'),
    ],
    include_directories: include_directories('.'),
    sources: pantheon_desktop_shell_sources
)

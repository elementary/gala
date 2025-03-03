dep_scanner = dependency('wayland-scanner', native: true)
prog_scanner = find_program(dep_scanner.get_variable(pkgconfig: 'wayland_scanner'))

blur_protocol_file = files('pantheon-blur-v1.xml')

pantheon_blur_sources = []
pantheon_blur_sources += custom_target(
	'pantheon-blur-server-protocol.h',
	command: [ prog_scanner, 'server-header', '@INPUT@', '@OUTPUT@' ],
	input: blur_protocol_file,
	output: 'pantheon-blur-server-protocol.h',
)

output_type = 'private-code'
if dep_scanner.version().version_compare('< 1.14.91')
    output_type = 'code'
endif
pantheon_blur_sources += custom_target(
	'pantheon-blur-protocol.c',
	command: [ prog_scanner, output_type, '@INPUT@', '@OUTPUT@' ],
	input: blur_protocol_file,
	output: 'pantheon-blur-protocol.c',
)

pantheon_blur_dep = declare_dependency(
    dependencies: [
        vala.find_library('pantheon-blur', dirs: meson.current_source_dir()),
        dependency('wayland-server'),
    ],
    include_directories: include_directories('.'),
    sources: pantheon_blur_sources
)

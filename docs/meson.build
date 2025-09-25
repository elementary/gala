valadoc = find_program('valadoc')

mutter_packages_command = []
foreach dep : mutter_dep
    mutter_packages_command += [ '--pkg', dep.name() ]
endforeach

basic_command = [
    valadoc,
    '--force',
    '--verbose',
    '--package-name','gala',
    '--package-version', meson.project_version(),
    mutter_packages_command,
    '--pkg', 'gtk4',
    '--pkg', 'gee-0.8',
    '--pkg', 'gio-unix-2.0',
    '--pkg', 'gmodule-2.0',
    '--pkg', 'posix',
    vala_flags,
    '--vapidir=' + join_paths(meson.build_root(), 'lib'),
    '--vapidir=' + join_paths(meson.global_source_root(), 'vapi'),
    '--doclet=html',
    '--use-svg-images'
]

doc_target = custom_target(
    'library documentation',
    command: [
        basic_command,
        '-o', '@OUTPUT@',
        '@INPUT@'
    ],
    build_by_default: true,
    input: gala_lib_sources,
    output: 'library'
)

all_doc_target = custom_target(
    'full documentation',
    command: [
        basic_command,
        '--internal',
        '--pkg', 'atk-bridge-2.0',
        '--pkg', 'gnome-bg-4',
        '--pkg', 'gnome-desktop-4',
        '--pkg', 'libsystemd',
        '--pkg', 'pantheon-desktop-shell',
        '--pkg', 'sqlite3',
        '--pkg', 'wayland-server',
        '--vapidir=' + join_paths(meson.global_source_root(), 'protocol'),
        '-o', '@OUTPUT@',
        '@INPUT@'
    ],
    build_by_default: true,
    input: gala_lib_sources + gala_bin_sources + [config_header],
    output: 'full'
)

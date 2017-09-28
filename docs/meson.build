valadoc = find_program('valadoc')

packages_command = [
    '--pkg', 'config',
    '--pkg', 'compat',
    '--pkg', 'cogl-fixes',
    '--pkg', libmutter_name,
]

foreach core_pkg : core_dependencies_txt
    packages_command += ['--pkg', core_pkg]
endforeach

foreach libmutter_extra_pkg : libmutter_extra
    packages_command += ['--pkg', libmutter_extra_pkg]
endforeach

basic_command = [
    valadoc,
    '--force',
    '--verbose',
    '--package-name','gala',
    '--package-version', GALA_SO_VERSION,
    '--driver', meson.get_compiler('vala').version(),
    packages_command,
    vala_flags,
    '--vapidir=' + join_paths(meson.build_root(), 'lib'),
    '--vapidir=' + vapi_dir,
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
    input: lib_files,
    output: 'library'
)

all_doc_target = custom_target(
    'full documentation',
    command: [
        basic_command,
        '--internal',
        '--pkg', 'granite',
        '--pkg', 'gnome-desktop-3.0',
        '--pkg', 'gmodule-2.0',
        '-o', '@OUTPUT@',
        '@INPUT@'
    ],
    build_by_default: true,
    input: lib_files + gala_files,
    output: 'full'
)

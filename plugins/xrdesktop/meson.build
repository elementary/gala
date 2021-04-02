gala_xrdesktop_sources = [
    'Main.vala',
]

gala_xrdesktop_lib = shared_library(
    'gala-xrdesktop',
    gala_xrdesktop_sources,
    dependencies: [gala_dep, gala_base_dep],
    include_directories: config_inc_dir,
    install: true,
    install_dir: plugins_dir,
    install_rpath: mutter_typelib_dir,
)

add_project_arguments('--vapidir', join_paths(meson.current_source_dir(), 'vapi'), language: 'vala')
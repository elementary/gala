gala_touchegg_sources = [
    'Main.vala',
    'Client.vala',
    'Gesture.vala',
]

gala_touchegg_lib = shared_library(
    'gala-touchegg',
    gala_touchegg_sources,
    dependencies: [gala_dep, gala_base_dep],
    include_directories: config_inc_dir,
    install: true,
    install_dir: plugins_dir,
    install_rpath: mutter_typelib_dir,
)

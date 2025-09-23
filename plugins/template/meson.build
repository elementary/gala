gala_template_sources = [
    'Main.vala',
]

gala_template_lib = shared_library(
    'gala-template',
    gala_template_sources,
    dependencies: [gala_dep, gala_base_dep],
    include_directories: include_directories('.'),
    install: false,
    install_dir: plugins_dir,
    install_rpath: mutter_typelib_dir,
)

gala_xrdesktop_sources = [
    'DBusService.vala',
    'Main.vala',
    'Window.vala',
]

gala_xrdesktop_lib = shared_library(
    'gala-xrdesktop',
    gala_xrdesktop_sources,
    dependencies: [
        gala_dep,
        gala_base_dep,
        xrdesktop_dep,
        gulkan_dep,
        gxr_dep,
        vulkan_dep,
        glew_dep
    ],
    include_directories: config_inc_dir,
    install: true,
    install_dir: plugins_dir,
    install_rpath: mutter_typelib_dir,
)
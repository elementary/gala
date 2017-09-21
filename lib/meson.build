
lib_files = [
    'ActivatableComponent.vala',
    'Plugin.vala',
    'Utils.vala',
    'WindowIcon.vala',
    'WindowManager.vala'
]

resources = gnome.compile_resources('gala-resources', join_paths(meson.source_root(), 'data', 'gala.gresource.xml'),
                                    source_dir: join_paths(meson.source_root(), 'data'))

gala_lib = shared_library('gala', [lib_files, resources],
                          vala_header: 'gala.h',
                          vala_gir: 'Gala-1.0.gir',
                          dependencies: core_dependencies,
                          version: GALA_SO_VERSION,
                          install: true,
                          install_dir: [true, join_paths(get_option('libdir'), 'gala'), true, true])

gala_requires = [
    'gobject-2.0',
    'glib-2.0',
    'gio-2.0',
    'gio-unix-2.0',
    'gtk+-3.0',
    'gdk-x11-3.0',
    'libbamf3',
    'plank',
    libmutter_name
]

pkg.generate(libraries: '-lgala',
             requires : gala_requires,
             version : '0',
             name : 'Gala',
             filebase : 'gala',
             subdirs: 'gala',
             variables: 'pkgdatadir=${prefix}/share/gala',
             description : 'Library to develop plugins for Gala')

deps_data = configuration_data()
deps_data.set('mutter', libmutter_name)
configure_file(input: 'gala.deps.in',
               output: 'gala.deps',
               configuration: deps_data,
               install_dir: join_paths(get_option('datadir'), 'vala', 'vapi'))

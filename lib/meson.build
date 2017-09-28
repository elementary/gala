
lib_files = files([
    'ActivatableComponent.vala',
    'Plugin.vala',
    'Utils.vala',
    'WindowIcon.vala',
    'WindowManager.vala'
])

resources = gnome.compile_resources(
    'gala-resources',
    join_paths(meson.source_root(), 'data', 'gala.gresource.xml'),
    source_dir: join_paths(meson.source_root(), 'data')
)

gala_lib = shared_library(
    library_name,
    [lib_files, resources],
    vala_header: library_name + '.h',
    vala_gir: 'Gala-1.0.gir',
    dependencies: core_dependencies,
    version: GALA_SO_VERSION,
    install: true,
    install_dir: [true, join_paths(get_option('libdir'), library_name), true, true]
)

libgala_dep = declare_dependency(
    link_with: gala_lib,
    include_directories: include_directories('.')
)

pkg.generate(
    libraries: gala_lib,
    requires : core_dependencies_txt,
    version : '0',
    name : 'Gala',
    filebase : library_name,
    subdirs: library_name,
    variables: 'pkgdatadir=${prefix}/share/' + library_name,
    description : 'Library to develop plugins for Gala'
)

deps_data = configuration_data()
deps_data.set('mutter', libmutter_name)
configure_file(
    input: library_name + '.deps.in',
    output: library_name + '.deps',
    configuration: deps_data,
    install_dir: join_paths(get_option('datadir'), 'vala', 'vapi')
)

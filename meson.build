project('gala',
    'vala',
    version: '8.6.1',
    meson_version: '>= 0.59.0',
    license: 'GPL3',
    default_options: [
        'buildtype=debugoptimized',
    ],
)

gnome = import('gnome')
i18n = import('i18n')
pkg = import('pkgconfig')
cc = meson.get_compiler('c')
vala = meson.get_compiler('vala')

vapi_dir = meson.current_source_dir() / 'vapi'

locale_dir = join_paths(get_option('prefix'), get_option('localedir'))
data_dir = join_paths(get_option('prefix'), get_option('datadir'))
plugins_dir = join_paths(get_option('prefix'), get_option('libdir'), meson.project_name(), 'plugins')

conf = configuration_data()
conf.set('GETTEXT_PACKAGE', meson.project_name())
conf.set('LOCALEDIR', locale_dir)
conf.set('PLUGINDIR', plugins_dir)
conf.set('VERSION', meson.project_version())
config_header = configure_file (
    input: 'config.vala.in',
    output: 'config.vala',
    configuration: conf
)

glib_version_required = '2.78'

add_project_arguments([
        '--target-glib=' + glib_version_required,
        '--hide-internal',
        '--vapidir=' + vapi_dir,
    ],
    language: 'vala',
)
add_project_arguments([
        '-Wno-discarded-qualifiers',
        '-Wno-incompatible-pointer-types',
        '-Wno-unused',
        '-Wno-address',
        '-Wno-duplicate-decl-specifier',
        '-Wno-deprecated-declarations',
        '-Wl,--enable-new-dtags',

        '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
        '-DGNOME_DESKTOP_USE_UNSTABLE_API',

        '-DGLIB_VERSION_MIN_REQUIRED=GLIB_VERSION_@0@'.format(glib_version_required.replace('.', '_')),
        '-DGLIB_VERSION_MAX_ALLOWED=GLIB_VERSION_@0@'.format(glib_version_required.replace('.', '_')),
    ],
    language: 'c',
)


# Dependencies
atk_bridge_dep = dependency('atk-bridge-2.0')
gdk_pixbuf_def = dependency ('gdk-pixbuf-2.0')
gtk4_dep = dependency('gtk4')
glib_dep = dependency('glib-2.0', version: '>= @0@'.format(glib_version_required))
gobject_dep = dependency('gobject-2.0', version: '>= @0@'.format(glib_version_required))
gio_dep = dependency('gio-2.0', version: '>= @0@'.format(glib_version_required))
gio_unix_dep = dependency('gio-unix-2.0', version: '>= @0@'.format(glib_version_required))
gmodule_dep = dependency('gmodule-2.0')
gee_dep = dependency('gee-0.8')
gnome_desktop_dep = dependency('gnome-desktop-4')
ibus_dep = dependency('ibus-1.0')
gnome_bg_dep = dependency('gnome-bg-4')
m_dep = cc.find_library('m', required: false)
posix_dep = vala.find_library('posix', required: false)
sqlite3_dep = dependency('sqlite3')
xext_dep = cc.find_library('Xext', required: true)
if get_option('systemd')
    systemd_dep = dependency('libsystemd')
endif

# library version -> gnome version
supported_mutter_versions = {
    '14': 46,
    '15': 47,
    '16': 48,
    '17': 49,
    '18': 50,
}

mutter_api_version = ''

vala_flags = []

foreach lib_version, gnome_version : supported_mutter_versions
    vala_flags += ['--define', 'HAS_MUTTER' + gnome_version.to_string()]

    required_version = ['>= ' + gnome_version.to_string(), '< ' + (gnome_version + 1).to_string()]
    libmutter_dep = dependency('libmutter-' + lib_version, version: required_version, required: false)
    if libmutter_dep.found()
        mutter_api_version = lib_version
        break
    endif
endforeach

if mutter_api_version == ''
    error ('No supported mutter library found!')
endif

libmutter_dep = dependency('libmutter-' + mutter_api_version)

mutter_dep = [
    libmutter_dep,
    dependency('mutter-mtk-' + mutter_api_version),
    dependency('mutter-cogl-' + mutter_api_version),
    dependency('mutter-clutter-' + mutter_api_version)
]

if libmutter_dep.version().version_compare('<= 47')
    mutter_dep += dependency('mutter-cogl-pango-' + mutter_api_version)
endif

if libmutter_dep.version().version_compare('>= 48') and libmutter_dep.get_variable('have_fonts') == 'false'
	error ('Gala requires mutter to be built with fonts rendering support!')
endif

mutter_typelib_dir = libmutter_dep.get_variable('typelibdir')

if get_option('systemd')
    vala_flags += ['--define', 'WITH_SYSTEMD']
endif

if vala.version().version_compare('>= 0.56.17')
    vala_flags += ['--define', 'VALA_0_56_17']
endif

add_project_arguments(vala_flags, language: 'vala')
add_project_link_arguments(['-Wl,-rpath,@0@'.format(mutter_typelib_dir)], language: 'c')

gala_base_dep = [atk_bridge_dep, gdk_pixbuf_def, gtk4_dep, glib_dep, gobject_dep, gio_dep, gio_unix_dep, gmodule_dep, gee_dep, mutter_dep, gnome_desktop_dep, gnome_bg_dep, ibus_dep, m_dep, posix_dep, sqlite3_dep, xext_dep]

if get_option('systemd')
    gala_base_dep += systemd_dep
endif

subdir('data')
subdir('protocol')
subdir('lib')
subdir('src')
subdir('daemon')
subdir('daemon-gtk3')
subdir('plugins/pip')
subdir('plugins/template')
if get_option('documentation')
    subdir('docs')
endif
if get_option('tests')
    subdir('tests')
endif
subdir('po')

vapigen = find_program('vapigen', required: false)
if vapigen.found()
    subdir('vapi')
endif

gnome.post_install(
    glib_compile_schemas: true,
    update_desktop_database: true
)

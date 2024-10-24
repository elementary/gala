project('gala',
    'c', 'vala',
    version: '8.0.2',
    meson_version: '>= 0.59.0',
    license: 'GPL3',
)

is_release = false

gnome = import('gnome')
i18n = import('i18n')
pkg = import('pkgconfig')
cc = meson.get_compiler('c')

gala_version = meson.project_version()

vala_version_required = '0.46.0'
vala = meson.get_compiler('vala')
if not vala.version().version_compare('>= @0@'.format(vala_version_required))
    error('Valac >= @0@ required!'.format(vala_version_required))
endif

vapi_dir = meson.current_source_dir() / 'vapi'

locale_dir = join_paths(get_option('prefix'), get_option('localedir'))
data_dir = join_paths(get_option('prefix'), get_option('datadir'))
plugins_dir = join_paths(get_option('prefix'), get_option('libdir'), meson.project_name(), 'plugins')
pkgdata_dir = join_paths(get_option('prefix'), get_option('datadir'), meson.project_name())
pkglib_dir = join_paths(get_option('prefix'), get_option('libdir'), meson.project_name())

conf = configuration_data()
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('LOCALEDIR', locale_dir)
conf.set_quoted('DATADIR', data_dir)
conf.set_quoted('PKGDATADIR', pkgdata_dir)
conf.set_quoted('PLUGINDIR', plugins_dir)
conf.set_quoted('RESOURCEPATH', '/org/pantheon/desktop/gala')
conf.set_quoted('VERSION', gala_version)
config_h = configure_file(
    output: 'config.h',
    configuration: conf
)

config_dep = declare_dependency(
    dependencies: vala.find_library('config', dirs: vapi_dir),
    sources: config_h
)

config_inc_dir = include_directories('.')

customconf = configuration_data()
customconf.set('GETTEXT_PACKAGE', meson.project_name())

add_project_arguments([
        '--target-glib=2.44',
        '--hide-internal',
        '--enable-deprecated',
        '--vapidir=' + vapi_dir,
    ],
    language: 'vala',
)
add_project_arguments([
        '-Wno-discarded-qualifiers',
        '-Wno-incompatible-pointer-types',
        '-Wno-unused',
        '-Wl,--enable-new-dtags',

        '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
        '-DGNOME_DESKTOP_USE_UNSTABLE_API',

        '-DGLIB_VERSION_MIN_REQUIRED=GLIB_VERSION_2_74',
        '-DGLIB_VERSION_MAX_ALLOWED=GLIB_VERSION_2_74',
    ],
    language: 'c',
)


# Dependencies
glib_version_required = '2.74.0'
gtk_version_required = '3.10.0'

atk_bridge_dep = dependency('atk-bridge-2.0')
canberra_dep = dependency('libcanberra')
glib_dep = dependency('glib-2.0', version: '>= @0@'.format(glib_version_required))
gobject_dep = dependency('gobject-2.0', version: '>= @0@'.format(glib_version_required))
gio_dep = dependency('gio-2.0', version: '>= @0@'.format(glib_version_required))
gio_unix_dep = dependency('gio-unix-2.0', version: '>= @0@'.format(glib_version_required))
gmodule_dep = dependency('gmodule-2.0')
gtk_dep = [dependency('gtk+-3.0', version: '>= @0@'.format(gtk_version_required)), dependency('gdk-x11-3.0')]
gtk4_dep = dependency('gtk4')
gee_dep = dependency('gee-0.8')
granite_dep = dependency('granite-7')
gnome_desktop_dep = dependency('gnome-desktop-3.0')
m_dep = cc.find_library('m', required: false)
posix_dep = vala.find_library('posix', required: false)
sqlite3_dep = dependency('sqlite3')
if get_option('systemd')
    systemd_dep = dependency('libsystemd')
endif

mutter_dep = []
libmutter_dep = []

vala_flags = []

mutter42_dep = dependency('libmutter-10', version: ['>= 42', '< 43'], required: false)
if mutter42_dep.found()
	libmutter_dep = dependency('libmutter-10', version: '>= 42')
	mutter_dep = [
		libmutter_dep,
		dependency('mutter-cogl-10'), dependency('mutter-cogl-pango-10'),
		dependency('mutter-clutter-10')
	]
	vala_flags = []
endif

mutter43_dep = dependency('libmutter-11', version: ['>= 43', '< 44'], required: false)
if mutter43_dep.found()
	libmutter_dep = dependency('libmutter-11', version: '>= 43')
	mutter_dep = [
		libmutter_dep,
		dependency('mutter-cogl-11'), dependency('mutter-cogl-pango-11'),
		dependency('mutter-clutter-11')
	]
	vala_flags = ['--define', 'HAS_MUTTER43']
endif

mutter44_dep = dependency('libmutter-12', version: ['>= 44', '< 45'], required: false)
if mutter44_dep.found()
	libmutter_dep = dependency('libmutter-12', version: '>= 44')
	mutter_dep = [
		libmutter_dep,
		dependency('mutter-cogl-12'), dependency('mutter-cogl-pango-12'),
		dependency('mutter-clutter-12')
	]
	vala_flags = ['--define', 'HAS_MUTTER43', '--define', 'HAS_MUTTER44']
endif

mutter45_dep = dependency('libmutter-13', version: ['>= 45', '< 46'], required: false)
if mutter45_dep.found()
	libmutter_dep = dependency('libmutter-13', version: '>= 45')
	mutter_dep = [
		libmutter_dep,
		dependency('mutter-mtk-13'), dependency('mutter-cogl-13'),
		dependency('mutter-cogl-pango-13'), dependency('mutter-clutter-13')
	]
	vala_flags = ['--define', 'HAS_MUTTER43', '--define', 'HAS_MUTTER44', '--define', 'HAS_MUTTER45']
endif

mutter46_dep = dependency('libmutter-14', version: ['>= 46', '< 47'], required: false)
if mutter46_dep.found()
	libmutter_dep = dependency('libmutter-14', version: '>= 46')
	mutter_dep = [
		libmutter_dep,
		dependency('mutter-mtk-14'), dependency('mutter-cogl-14'),
		dependency('mutter-cogl-pango-14'), dependency('mutter-clutter-14')
	]
	vala_flags = ['--define', 'HAS_MUTTER43', '--define', 'HAS_MUTTER44', '--define', 'HAS_MUTTER45', '--define', 'HAS_MUTTER46']
endif

if mutter_dep.length() == 0
    error ('No supported mutter library found!')
endif

mutter_typelib_dir = libmutter_dep.get_variable('typelibdir')

if get_option('systemd')
    vala_flags += ['--define', 'WITH_SYSTEMD']
endif

add_project_arguments(vala_flags, language: 'vala')
add_project_link_arguments(['-Wl,-rpath,@0@'.format(mutter_typelib_dir)], language: 'c')

gala_base_dep = [atk_bridge_dep, canberra_dep, glib_dep, gobject_dep, gio_dep, gio_unix_dep, gmodule_dep, gee_dep, gtk_dep, mutter_dep, gnome_desktop_dep, m_dep, posix_dep, sqlite3_dep, config_dep]

if get_option('systemd')
    gala_base_dep += systemd_dep
endif

subdir('data')
subdir('protocol')
subdir('lib')
subdir('src')
subdir('daemon')
subdir('daemon-gtk3')
subdir('background')
subdir('plugins/pip')
subdir('plugins/template')
if get_option('documentation')
    subdir('docs')
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

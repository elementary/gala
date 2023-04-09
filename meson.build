project('gala',
    'c', 'vala',
    version: '7.0.2',
    meson_version: '>= 0.58.0',
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
conf.set_quoted('SCHEMA', 'org.pantheon.desktop.gala')
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

        '-DGLIB_VERSION_MIN_REQUIRED=GLIB_VERSION_2_44',
        '-DGLIB_VERSION_MAX_ALLOWED=GLIB_VERSION_2_44',
        '-DGDK_VERSION_MIN_REQUIRED=GDK_VERSION_3_10',
        '-DGDK_VERSION_MAX_ALLOWED=GDK_VERSION_3_10',
    ],
    language: 'c',
)


# Dependencies
glib_version_required = '2.44.0'
gtk_version_required = '3.10.0'
gsd_version_required = '3.15.2'

canberra_dep = dependency('libcanberra')
glib_dep = dependency('glib-2.0', version: '>= @0@'.format(glib_version_required))
gobject_dep = dependency('gobject-2.0', version: '>= @0@'.format(glib_version_required))
gio_dep = dependency('gio-2.0', version: '>= @0@'.format(glib_version_required))
gio_unix_dep = dependency('gio-unix-2.0', version: '>= @0@'.format(glib_version_required))
gmodule_dep = dependency('gmodule-2.0')
gtk_dep = [dependency('gtk+-3.0', version: '>= @0@'.format(gtk_version_required)), dependency('gdk-x11-3.0')]
gee_dep = dependency('gee-0.8')
granite_dep = dependency('granite', version: '>= 5.4.0')
gnome_desktop_dep = dependency('gnome-desktop-3.0')
gsd_dep = dependency('gnome-settings-daemon', version: '>= @0@'.format(gsd_version_required))
m_dep = cc.find_library('m', required: false)
posix_dep = vala.find_library('posix', required: false)
gexiv2_dep = dependency('gexiv2')
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

if mutter_dep.length() == 0
    error ('No supported mutter library found!')
endif

mutter_typelib_dir = libmutter_dep.get_variable('typelibdir')

if get_option('systemd')
    vala_flags += ['--define', 'WITH_SYSTEMD']
endif

add_project_arguments(vala_flags, language: 'vala')
add_project_link_arguments(['-Wl,-rpath,@0@'.format(mutter_typelib_dir)], language: 'c')

gala_base_dep = [canberra_dep, glib_dep, gobject_dep, gio_dep, gio_unix_dep, gmodule_dep, gee_dep, gtk_dep, mutter_dep, granite_dep, gnome_desktop_dep, m_dep, posix_dep, gexiv2_dep, config_dep]

if get_option('systemd')
    gala_base_dep += systemd_dep
endif

subdir('data')
subdir('lib')
subdir('src')
subdir('daemon')
subdir('plugins/maskcorners')
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

meson.add_install_script('build-aux/meson/post_install.py')

project('gala',
    'vala',
    version: '8.2.5',
    meson_version: '>= 0.59.0',
    license: 'GPL3',
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
gnome_bg_dep = dependency('gnome-bg-4')
m_dep = cc.find_library('m', required: false)
posix_dep = vala.find_library('posix', required: false)
sqlite3_dep = dependency('sqlite3')
xext_dep = cc.find_library('Xext', required: true)
if get_option('systemd')
    systemd_dep = dependency('libsystemd')
endif

mutter_dep = []
libmutter_dep = []

vala_flags = []

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

mutter47_dep = dependency('libmutter-15', version: ['>= 47', '< 48'], required: false)
if mutter47_dep.found()
	libmutter_dep = dependency('libmutter-15', version: '>= 47')
	mutter_dep = [
		libmutter_dep,
		dependency('mutter-mtk-15'), dependency('mutter-cogl-15'),
		dependency('mutter-cogl-pango-15'), dependency('mutter-clutter-15')
	]
	vala_flags = ['--define', 'HAS_MUTTER43', '--define', 'HAS_MUTTER44', '--define', 'HAS_MUTTER45', '--define', 'HAS_MUTTER46', '--define', 'HAS_MUTTER47']
endif

mutter48_dep = dependency('libmutter-16', version: ['>= 48', '< 49'], required: false)
if mutter48_dep.found()
	libmutter_dep = dependency('libmutter-16', version: '>= 48')
	mutter_dep = [
		libmutter_dep,
		dependency('mutter-mtk-16'), dependency('mutter-cogl-16'),
		dependency('mutter-clutter-16')
	]
	vala_flags = ['--define', 'HAS_MUTTER43', '--define', 'HAS_MUTTER44', '--define', 'HAS_MUTTER45', '--define', 'HAS_MUTTER46', '--define', 'HAS_MUTTER47', '--define', 'HAS_MUTTER48']
endif

mutter49_dep = dependency('libmutter-17', version: ['>= 49', '< 50'], required: false)
if mutter49_dep.found()
	libmutter_dep = dependency('libmutter-17', version: '>= 49')
	mutter_dep = [
		libmutter_dep,
		dependency('mutter-mtk-17'), dependency('mutter-cogl-17'),
		dependency('mutter-clutter-17')
	]
	vala_flags = ['--define', 'HAS_MUTTER43', '--define', 'HAS_MUTTER44', '--define', 'HAS_MUTTER45', '--define', 'HAS_MUTTER46', '--define', 'HAS_MUTTER47', '--define', 'HAS_MUTTER48', '--define', 'HAS_MUTTER49']
endif

if mutter_dep.length() == 0
    error ('No supported mutter library found!')
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

gala_base_dep = [atk_bridge_dep, gdk_pixbuf_def, gtk4_dep, glib_dep, gobject_dep, gio_dep, gio_unix_dep, gmodule_dep, gee_dep, mutter_dep, gnome_desktop_dep, gnome_bg_dep, m_dep, posix_dep, sqlite3_dep, xext_dep]

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
subdir('po')

vapigen = find_program('vapigen', required: false)
if vapigen.found()
    subdir('vapi')
endif

gnome.post_install(
    glib_compile_schemas: true,
    update_desktop_database: true
)

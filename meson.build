project('io.elementary.gala', 'vala', 'c')

gnome = import('gnome')
i18n = import('i18n')
pkg = import('pkgconfig')

GALA_SO_VERSION = '0.0.0'

GLIB_MIN_VERSION = '>=2.44.0'
GTK_MIN_VERSION = '>=3.4.0'

vapi_dir = join_paths(meson.current_source_dir(), 'vapi')
plugin_dir = join_paths(get_option('prefix'), get_option('libdir'), 'gala', 'plugins')
pkg_data_dir = join_paths(get_option('prefix'), get_option('datadir'), 'gala')

gobject_dep = dependency('gobject-2.0', version : GLIB_MIN_VERSION)
glib_dep = dependency('glib-2.0', version : GLIB_MIN_VERSION)
gio_dep = dependency('gio-2.0', version : GLIB_MIN_VERSION)
gio_unix_dep = dependency('gio-unix-2.0', version : GLIB_MIN_VERSION)
gtk_dep = dependency('gtk+-3.0', version : GTK_MIN_VERSION)
gdk_x11_dep = dependency('gdk-x11-3.0', version : GTK_MIN_VERSION)
bamf_dep = dependency('libbamf3')
granite_dep = dependency('granite')
gee_dep = dependency('gee-0.8')
gnome_desktop_dep = dependency('gnome-desktop-3.0')
g_s_d_dep = dependency('gnome-settings-daemon', version : '>=3.15.2')
plank_dep = dependency('plank', version : '>=0.11.0')
gmodule_dep = dependency('gmodule-2.0')
colg_fixes_dep = meson.get_compiler('vala').find_library('cogl-fixes', dirs: vapi_dir)
compat_dep = meson.get_compiler('vala').find_library('compat', dirs: vapi_dir)
config_dep = meson.get_compiler('vala').find_library('config', dirs: vapi_dir)
m_dep = meson.get_compiler('c').find_library('m')

add_project_arguments('-DGETTEXT_PACKAGE="gala"', language:'c')
add_project_arguments('-DPKGDATADIR="' + pkg_data_dir + '"', language:'c')
add_project_arguments('-DVERSION="' + GALA_SO_VERSION + '"', language:'c')
add_project_arguments('-DDATADIR="' + get_option('datadir') + '"', language:'c')
add_project_arguments('-DPLUGINDIR="' + plugin_dir + '"', language:'c')
add_project_arguments('-DSCHEMA="org.pantheon.desktop.gala"', language:'c')
add_project_arguments('-DGNOME_DESKTOP_USE_UNSTABLE_API', language:'c')
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

core_dependencies = [
    gobject_dep,
    glib_dep,
    gio_dep,
    gio_unix_dep,
    gtk_dep,
    gdk_x11_dep,
    granite_dep,
    bamf_dep,
    plank_dep
]

#
# Mutter detection
#

vala_flags = []
c_flags = []
libmutter_name = ''
libmutter_extra = []

## 3.18
libmutter_318_dep = dependency('libmutter', version : ['>=3.18.3', '<3.19'], required : false)
libmutter_320_dep = dependency('libmutter', version : ['>=3.19', '<3.21'], required : false)
libmutter_322_dep = dependency('libmutter', version : '>=3.21', required : false)
libmutter_324_dep = dependency('libmutter-0', version : '>=3.23', required : false)
libmutter_326_dep = dependency('libmutter-1', version : '>=3.25', required : false)

if libmutter_318_dep.found()
    core_dependencies += libmutter_318_dep
    core_dependencies += dependency('cogl-1.0')
    core_dependencies += dependency('clutter-1.0')
    libmutter_name = 'libmutter'
    libmutter_extra += 'cogl-1.0'
    libmutter_extra += 'clutter-1.0'
    message('Mutter version: ' + libmutter_318_dep.version ())
endif

## 3.20
if libmutter_320_dep.found()
    vala_flags += ['--define', 'HAS_MUTTER320']
    core_dependencies += libmutter_320_dep
    core_dependencies += dependency('cogl-1.0')
    core_dependencies += dependency('clutter-1.0')
    libmutter_name = 'libmutter'
    libmutter_extra += 'cogl-1.0'
    libmutter_extra += 'clutter-1.0'
    message('Mutter version: ' + libmutter_320_dep.version ())
endif

## 3.22
if libmutter_322_dep.found()
    typelib_dir = libmutter_322_dep.get_pkgconfig_variable('typelibdir')
    vala_flags += ['--define', 'HAS_MUTTER320']
    vala_flags += ['--define', 'HAS_MUTTER322']
    c_flags += [
        '-DCLUTTER_ENABLE_COMPOSITOR_API',
        '-DCLUTTER_ENABLE_EXPERIMENTAL_API',
        '-DCOGL_ENABLE_EXPERIMENTAL_API',
        '-DCOGL_ENABLE_EXPERIMENTAL_2_0_API'
    ]
    core_dependencies += libmutter_322_dep
    core_dependencies += dependency('mutter-cogl-1.0')
    core_dependencies += meson.get_compiler('c').find_library('mutter-cogl-pango-1.0', dirs: typelib_dir)
    core_dependencies += meson.get_compiler('c').find_library('mutter-cogl-path-1.0', dirs: typelib_dir)
    core_dependencies += dependency('mutter-clutter-1.0')
    libmutter_name = 'libmutter'
    libmutter_extra += 'mutter-cogl-1.0'
    libmutter_extra += 'mutter-clutter-1.0'
    message('Mutter version: ' + libmutter_322_dep.version ())
endif

## 3.24
if libmutter_324_dep.found()
    typelib_dir = libmutter_324_dep.get_pkgconfig_variable('typelibdir')
    vala_flags += ['--define', 'HAS_MUTTER320']
    vala_flags += ['--define', 'HAS_MUTTER322']
    vala_flags += ['--define', 'HAS_MUTTER324']
    c_flags += '-DCLUTTER_ENABLE_COMPOSITOR_API'
    c_flags += '-DCLUTTER_ENABLE_EXPERIMENTAL_API'
    c_flags += '-DCOGL_ENABLE_EXPERIMENTAL_API'
    c_flags += '-DCOGL_ENABLE_EXPERIMENTAL_2_0_API'

    core_dependencies += libmutter_324_dep
    core_dependencies += dependency('mutter-cogl-0')
    core_dependencies += meson.get_compiler('c').find_library('mutter-cogl-pango-0', dirs: typelib_dir)
    core_dependencies += meson.get_compiler('c').find_library('mutter-cogl-path-0', dirs: typelib_dir)
    core_dependencies += dependency('mutter-clutter-0')
    libmutter_name = 'libmutter-0'
    libmutter_extra += 'mutter-cogl-0'
    libmutter_extra += 'mutter-clutter-0'
    message('Mutter version: ' + libmutter_324_dep.version ())
endif

## 3.26
if libmutter_326_dep.found()
    typelib_dir = libmutter_326_dep.get_pkgconfig_variable('typelibdir')
    vala_flags += ['--define', 'HAS_MUTTER320']
    vala_flags += ['--define', 'HAS_MUTTER322']
    vala_flags += ['--define', 'HAS_MUTTER324']
    vala_flags += ['--define', 'HAS_MUTTER326']
    core_dependencies += libmutter_326_dep
    core_dependencies += dependency('mutter-cogl-1')
    core_dependencies += meson.get_compiler('c').find_library('mutter-cogl-pango-1', dirs: typelib_dir)
    core_dependencies += meson.get_compiler('c').find_library('mutter-cogl-path-1', dirs: typelib_dir)
    core_dependencies += dependency('mutter-clutter-1')
    libmutter_name = 'libmutter-1'
    libmutter_extra += 'mutter-cogl-1'
    libmutter_extra += 'mutter-clutter-1'
    message('Mutter version: ' + libmutter_326_dep.version ())
endif

if libmutter_name == ''
    error ('Mutter library not found')
endif

add_project_arguments(vala_flags, language: 'vala')
add_project_arguments(c_flags, language: 'c')
subdir('po')
subdir('data')
subdir('lib')

libgala_dep = declare_dependency(link_with: gala_lib)
libgala_dir = include_directories('./lib')
gala_dependencies = [
    libgala_dep,
    gee_dep,
    gnome_desktop_dep,
    gmodule_dep,
    m_dep,
    colg_fixes_dep,
    compat_dep,
    config_dep
]

subdir('src')

if (get_option('documentation'))
    subdir('docs')
endif

# dependencies for the notification plugin
libcanberra_dep = dependency('libcanberra')
# We need these three steps because the .vapi and .pc have different names
libcanberra_gtk_lib = meson.get_compiler('c').find_library('libcanberra-gtk3')
libcanberra_gtk_vapi = meson.get_compiler('vala').find_library('libcanberra-gtk',
    dirs: [join_paths(get_option('prefix'), get_option('datadir'), 'vala', 'vapi'),
           join_paths('/usr', 'share', 'vala', 'vapi')])
libcanberra_gtk_dep = declare_dependency(dependencies: [libcanberra_gtk_lib, libcanberra_gtk_vapi])
notification_dependencies = [
    libcanberra_dep,
    libcanberra_gtk_dep
]

subdir('plugins')

message('Plugins will be installed in: ' + plugin_dir)

gala_app_windows_sources = [
	'Main.vala',
	'AppWindowOverview.vala'
]

gala_app_windows_lib = shared_library(
	'gala-app-windows',
	gala_app_windows_sources,
	dependencies: [gala_bin_lib_dep, gala_dep, gala_base_dep],
	include_directories: config_inc_dir,
	install: true,
	install_dir: plugins_dir,
	install_rpath: mutter_typelib_dir,
)
quickswitch_sources = [
	'Main.vala',
]

quickswitch_sources = shared_library(
	'gala-quickswitch',
	quickswitch_sources,
	dependencies: [gala_dep, gala_base_dep],
	include_directories: config_inc_dir,
	install: true,
	install_dir: plugins_dir,
	install_rpath: mutter_typelib_dir,
)
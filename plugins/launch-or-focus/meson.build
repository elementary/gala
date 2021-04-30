launch_or_focus_sources = [
	'Main.vala',
]

launch_or_focus_sources = shared_library(
	'gala-launch-or-focus',
	launch_or_focus_sources,
	dependencies: [gala_dep, gala_base_dep],
	include_directories: config_inc_dir,
	install: true,
	install_dir: plugins_dir,
	install_rpath: mutter_typelib_dir,
)

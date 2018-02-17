install_data(
	'io.elementary.gala.daemon.desktop',
	install_dir: join_paths(data_dir, 'applications')
)

daemon_sources = files (
    'main.vala',
	'MenuDaemon.vala'
)

executable('io.elementary.gala.daemon',
           daemon_sources,
           dependencies: [gala_dep, gala_base_dep],
           install: true)

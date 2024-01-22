gala_daemon_sources = files(
    'Main.vala',
    'MenuDaemon.vala',
    'MonitorLabel.vala'
)

gala_daemon_bin = executable(
    'gala-daemon',
    gala_daemon_sources,
    dependencies: [gala_dep, gala_base_dep, dependency('libhandy-1')],
    include_directories: config_inc_dir,
    install: true,
)

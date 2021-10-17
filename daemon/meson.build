gala_daemon_sources = files(
    'Main.vala',
    'MenuDaemon.vala'
)

gala_daemon_bin = executable(
    'gala-daemon',
    gala_daemon_sources,
    dependencies: [gala_dep, gala_base_dep],
    include_directories: config_inc_dir,
    install: true,
)

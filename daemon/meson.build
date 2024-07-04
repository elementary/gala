gala_daemon_sources = files(
    'Main.vala',
    'DBus.vala',
    'MonitorLabel.vala',
    'Window.vala',
    'WindowMenu.vala',
)

gala_daemon_bin = executable(
    'gala-daemon',
    gala_daemon_sources,
    gala_resources,
    dependencies: [config_dep, granite_dep, gtk4_dep],
    include_directories: config_inc_dir,
    install: true,
)

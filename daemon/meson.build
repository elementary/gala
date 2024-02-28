gala_daemon_sources = files(
    'Main.vala',
    'DBus.vala',
    'MonitorLabel.vala',
    'Window.vala',
    'WindowMenu.vala',
    'BackgroundMenu.vala',
)

gala_daemon_bin = executable(
    'gala-daemon',
    gala_daemon_sources,
    dependencies: [gala_dep, gala_base_dep, hdy_dep],
    include_directories: config_inc_dir,
    install: true,
)

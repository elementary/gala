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
    dependencies: [dependency('gtk4'), dependency('granite-7'), dependency('libadwaita-1')],
    # include_directories: config_inc_dir,
    install: true,
)

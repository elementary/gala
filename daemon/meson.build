gala_daemon_sources = files(
    'Main.vala',
    'DisplayConfig.vala',
    'DBus.vala',
    'MonitorLabel.vala',
    'Window.vala',
    'WindowMenu.vala',
)

granite_dep = dependency('granite-7')

gala_daemon_bin = executable(
    'gala-daemon',
    gala_daemon_sources,
    gala_resources,
    config_header,
    dependencies: [granite_dep, gtk4_dep],
    include_directories: include_directories('.'),
    install: true,
)

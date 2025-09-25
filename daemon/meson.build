gala_daemon_sources = files(
    'Main.vala',
    'DisplayConfig.vala',
    'DBus.vala',
    'MonitorLabel.vala',
    'Window.vala',
    'WindowMenu.vala',
)

gtk4_dep = dependency('gtk4')
granite7_dep = dependency('granite-7')

executable(
    'gala-daemon',
    gala_daemon_sources,
    config_header,
    gala_resources,
    dependencies: [gtk4_dep, granite7_dep],
    install: true
)

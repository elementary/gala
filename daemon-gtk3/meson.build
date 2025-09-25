gala_daemon_sources = files(
    'Main.vala',
    'DBus.vala',
    'MonitorLabel.vala',
    'Window.vala',
    'WindowMenu.vala',
    'BackgroundMenu.vala',
)

granite6_dep = dependency('granite')
hdy_dep = dependency('libhandy-1')

executable(
    'gala-daemon-gtk3',
    gala_daemon_sources,
    config_header,
    dependencies: [gala_base_dep, gala_dep, granite6_dep, hdy_dep],
    install: true,
)

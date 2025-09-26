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

gala_daemon_bin = executable(
    'gala-daemon-gtk3',
    gala_daemon_sources,
    gala_common_enums,
    config_header,
    dependencies: [granite6_dep, hdy_dep],
    install: true,
)

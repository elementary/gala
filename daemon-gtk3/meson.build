gala_daemon_sources = files(
    'Main.vala',
    'DBus.vala',
    'MonitorLabel.vala',
    'Window.vala',
    'WindowMenu.vala',
    'BackgroundMenu.vala',
)

granite_dep_old = dependency('granite')
hdy_dep = dependency('libhandy-1')

gala_daemon_bin = executable(
    'gala-daemon-gtk3',
    gala_daemon_sources,
    config_header,
    dependencies: [granite_dep_old, hdy_dep],
    include_directories: config_inc_dir,
    install: true,
)

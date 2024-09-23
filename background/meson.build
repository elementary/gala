background_sources = files(
    'Application.vala',
    'BackgroundWindow.vala',
)

background_bin = executable(
    'io.elementary.desktop.background',
    background_sources,
    gala_resources,
    dependencies: [config_dep, granite_dep, gtk4_dep, dependency('pantheon-wayland-1'), m_dep, dependency('libadwaita-1')],
    include_directories: config_inc_dir,
    install: true,
)

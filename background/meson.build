background_sources = files(
    'Application.vala',
    'Background.vala',
    'BackgroundManager.vala',
    'BackgroundWindow.vala',
    'Utils.vala',
)

executable(
    'io.elementary.desktop.background',
    background_sources,
    gala_resources,
    dependencies: [config_dep, granite_dep, gtk4_dep, dependency('pantheon-wayland-1'), m_dep, dependency('libadwaita-1'), dependency('gnome-desktop-4'), dependency('gnome-bg-4')],
    include_directories: config_inc_dir,
    install: true,
)

window_switcher_sources = files(
    'Application.vala',
    'ShellKeyGrabber.vala',
    'WindowSwitcher.vala',
    'WindowSwitcherIcon.vala'
)

window_switcher_bin = executable(
    'io.elementary.window-switcher',
    window_switcher_sources,
    gala_resources,
    dependencies: [config_dep, granite_dep, gtk4_dep, dependency('pantheon-wayland-1')],
    include_directories: config_inc_dir,
    install: true,
)

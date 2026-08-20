gala_daemon_sources = files(
    'Main.vala',
    'DisplayConfig.vala',
    'DBus.vala',
    'MonitorLabel.vala',
    'Window.vala',
    'Background' / 'Background.vala',
    'Background' / 'BackgroundManager.vala',
    'Background' / 'BackgroundWindow.vala',
    'Background' / 'Utils.vala',
    'IBus' / 'Candidate.vala',
    'IBus' / 'CandidateArea.vala',
    'IBus' / 'CandidateBox.vala',
    'IBus' / 'IBusService.vala',
    'IBus' / 'IBusCandidateWindow.vala',
    'OSK' / 'InputManager.vala',
    'OSK' / 'ModelManager.vala',
    'OSK' / 'OSKManager.vala',
    'OSK' / 'OSKService.vala',
    'OSK' / 'KeyboardModel' / 'Key.vala',
    'OSK' / 'KeyboardModel' / 'KeyboardModel.vala',
    'OSK' / 'KeyboardModel' / 'KeyboardModelBuilder.vala',
    'OSK' / 'KeyboardModel' / 'KeyboardView.vala',
    'OSK' / 'Parsers' / 'GnomeOSKParser.vala',
    'OSK' / 'Window' / 'OSKWindow.vala',
    'OSK' / 'Window' / 'Keyboard' / 'Keyboard.vala',
    'OSK' / 'Window' / 'Keyboard' / 'KeyButton.vala',
    'OSK' / 'Window' / 'Keyboard' / 'ViewContainer.vala',
)

adw_dep = dependency('libadwaita-1')
gtk4_dep = dependency('gtk4')
gtk_wayland_dep = dependency('gtk4-wayland')
gtk_x11_dep = dependency('gtk4-x11')
granite7_dep = dependency('granite-7')
json_dep = dependency('json-glib-1.0')
pantheon_wayland_dep = dependency('pantheon-wayland-1')

executable(
    'gala-daemon',
    gala_daemon_sources,
    config_header,
    gala_resources,
    osk_resources,
    dependencies: [adw_dep, gnome_desktop_dep, gnome_bg_dep, gtk4_dep, gtk_wayland_dep, gtk_x11_dep, granite7_dep, ibus_dep, json_dep, pantheon_wayland_dep],
    install: true
)

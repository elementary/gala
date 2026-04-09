gala_daemon_sources = files(
    'Main.vala',
    'DisplayConfig.vala',
    'DBus.vala',
    'MonitorLabel.vala',
    'Window.vala',
    'WindowMenu.vala',
    'IBus' / 'Candidate.vala',
    'IBus' / 'CandidateArea.vala',
    'IBus' / 'CandidateBox.vala',
    'IBus' / 'IBusService.vala',
    'IBus' / 'IBusCandidateWindow.vala',
    'OSK' / 'Keyboard' / 'Keyboard.vala',
    'OSK' / 'Keyboard' / 'KeyButton.vala',
    'OSK' / 'Keyboard' / 'ViewContainer.vala',
    'OSK' / 'KeyboardModel' / 'Key.vala',
    'OSK' / 'KeyboardModel' / 'KeyboardModel.vala',
    'OSK' / 'KeyboardModel' / 'KeyboardModelBuilder.vala',
    'OSK' / 'KeyboardModel' / 'KeyboardView.vala',
    'OSK' / 'Parsers' / 'GnomeOSKParser.vala',
    'OSK' / 'InputManager.vala',
    'OSK' / 'ModelManager.vala',
    'OSK' / 'OSKManager.vala',
    'OSK' / 'OSKWindow.vala',
)

adw_dep = dependency('libadwaita-1')
gtk4_dep = dependency('gtk4')
granite7_dep = dependency('granite-7')
json_dep = dependency('json-glib-1.0')

executable(
    'gala-daemon',
    gala_daemon_sources,
    gala_common_enums,
    config_header,
    gala_resources,
    dependencies: [adw_dep, gtk4_dep, granite7_dep, ibus_dep, json_dep],
    install: true
)

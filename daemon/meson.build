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
    'IBus' / 'IBusCandidateWindow.vala'
)

gtk4_dep = dependency('gtk4')
granite7_dep = dependency('granite-7')

executable(
    'gala-daemon',
    gala_daemon_sources,
    gala_common_enums,
    config_header,
    gala_resources,
    dependencies: [gtk4_dep, granite7_dep, ibus_dep],
    install: true
)

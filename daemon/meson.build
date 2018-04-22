daemon_sources = files (
    'main.vala',
    'MenuDaemon.vala'
)

executable('gala-daemon',
           daemon_sources,
           dependencies: [gala_dep, gala_base_dep],
           install: true)

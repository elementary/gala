src_tests = [
    'StartupTest',
]

src_test_sources = []
foreach test : src_tests
    src_test_sources += test + '.vala'
endforeach

src_test_sources += [
    'Main.vala'
]

src_test_executable = executable(
    'io.elementary.gala.src-tests',
    common_test_sources,
    src_test_sources,
    gala_bin_base_sources,
    config_header,
    dependencies: [gala_dep, gala_base_dep, pantheon_desktop_shell_dep],
    install: false,
)

foreach test : src_tests
    test(test, dbus_runner, args: ['--', src_test_executable, 'Gala' + test], suite: ['Gala', 'Gala/src'], is_parallel: false)
endforeach


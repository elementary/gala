src_tests = [
    'TransitionBuilderTest'
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
    dependencies: [gala_base_dep, gala_dep, pantheon_desktop_shell_dep],
    install: false,
)

foreach test : src_tests
    test(test, src_test_executable, args: 'Gala' + test, suite: ['Gala', 'Gala/src'], is_parallel: false)
endforeach


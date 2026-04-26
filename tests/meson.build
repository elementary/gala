common_test_sources = files(
    'MutterTestCase.vala',
    'TestCase.vala',
)

lib_tests = [
    'GestureControllerTest',
    'PropertyTargetTest',
    'SetupTest',
]

foreach lib_test : lib_tests
    test_executable = executable(
        lib_test,
        'lib/@0@.vala'.format(lib_test),
        common_test_sources,
        dependencies: [gala_bin_dep],
        install: false,
    )

    test(lib_test, test_executable, suite: ['Gala', 'Gala/lib'], is_parallel: false)
endforeach

src_tests = [
    'ActionFilterTest',
]

foreach src_test : src_tests
    test_executable = executable(
        src_test,
        'src/@0@.vala'.format(src_test),
        common_test_sources,
        dependencies: [gala_bin_dep],
        install: false,
    )

    test(src_test, test_executable, suite: ['Gala', 'Gala/src'], is_parallel: false)
endforeach


tests = [
    'GestureControllerTest',
    'PropertyTargetTest',
    'SetupTest',
]

foreach test : tests
    test_executable = executable(
        test,
        '@0@.vala'.format(test),
        common_test_sources,
        dependencies: [gala_lib_dep, gala_base_dep],
        install: false,
    )

    test(test, test_executable, suite: ['Gala', 'Gala/lib'], is_parallel: false)
endforeach

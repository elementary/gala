lib_tests = [
    'GestureControllerTest',
    'PropertyTargetTest',
    'SetupTest',
    'SwipeTriggerTest',
]

lib_test_sources = []
foreach test : lib_tests
    lib_test_sources += test + '.vala'
endforeach

lib_test_sources += [
    'Main.vala'
]

lib_test_executable = executable(
    'io.elementary.gala.lib-tests',
    common_test_sources,
    lib_test_sources,
    gala_lib_sources,
    dependencies: gala_base_dep,
    install: false,
)

foreach test : lib_tests
    test(test, lib_test_executable, args: 'Gala' + test, suite: ['Gala', 'Gala/lib'], is_parallel: false)
endforeach


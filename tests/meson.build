common_test_sources = files(
    'Main.vala',
    'MutterTestCase.vala',
    'TestCase.vala',
)

lib_tests = [
    'GestureControllerTest',
    'PropertyTargetTest',
    'SetupTest',
    'SwipeTriggerTest',
]

lib_test_sources = files()
foreach lib_test : lib_tests
    lib_test_sources += files('lib/@0@.vala'.format(lib_test))
endforeach

test_executable = executable(
    'io.elementary.gala.tests',
    common_test_sources,
    lib_test_sources,
    gala_lib_sources,
    dependencies: gala_base_dep,
    install: false,
)

lib_test_sources = files()
foreach lib_test : lib_tests
    test(lib_test, test_executable, args: ['--test-name=@0@'.format(lib_test)] ,is_parallel: false)
endforeach


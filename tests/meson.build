sources = files(
    'Main.vala',
    'MutterTestCase.vala',
    'TestCase.vala',
    'lib' / 'GestureControllerTest.vala',
    'lib' / 'PropertyTargetTest.vala',
    'lib' / 'SetupTest.vala',
    'lib' / 'SwipeTriggerTest.vala',
)

test_executable = executable(
    'io.elementary.gala.tests',
    sources,
    gala_lib_sources,
    dependencies: gala_base_dep,
    install: false,
)

test('Tests', test_executable, is_parallel: false)

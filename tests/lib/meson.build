tests = [
    'GestureControllerTest',
    'PropertyTargetTest',
    'SetupTest',
    'SwipeTriggerTest',
]

test_sources = []
foreach test : tests
    test_sources += test + '.vala'
endforeach

lib_test_sources = [
    'Main.vala'
]

test_executable = executable(
    'io.elementary.gala.tests',
    common_test_sources,
    lib_test_sources,
    test_sources,
    gala_lib_sources,
    dependencies: gala_base_dep,
    install: false,
)

foreach test : tests
    test(test, test_executable, args: 'Gala' + test, suite: ['Gala', 'Gala/lib'], is_parallel: false)
endforeach


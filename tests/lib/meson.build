lib_test_sources = files(
    meson.project_source_root() / 'lib' / 'CommonEnums.vala',
    meson.project_source_root() / 'lib' / 'WindowManager.vala',
    meson.project_source_root() / 'lib' / 'Gestures' / 'Gesture.vala',
    meson.project_source_root() / 'lib' / 'Gestures' / 'GestureTarget.vala',
    meson.project_source_root() / 'lib' / 'Gestures' / 'PropertyTarget.vala',
)

tests = [
    'PropertyTargetTest',
    'SetupTest',
]

foreach test : tests
    test_executable = executable(
        test,
        '@0@.vala'.format(test),
        common_test_sources,
        lib_test_sources,
        dependencies: gala_base_dep,
        install: false,
    )

    test(test, test_executable, suite: ['Gala', 'Gala/lib'], env : ['XDG_RUNTIME_DIR=/run/user/1000'])
endforeach

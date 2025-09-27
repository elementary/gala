lib_test_sources = files(
    meson.project_source_root() / 'lib' / 'Gestures' / 'Gesture.vala',
    meson.project_source_root() / 'lib' / 'Gestures' / 'GestureBackend.vala',
    meson.project_source_root() / 'lib' / 'Gestures' / 'GestureController.vala',
    meson.project_source_root() / 'lib' / 'Gestures' / 'GestureSettings.vala',
    meson.project_source_root() / 'lib' / 'Gestures' / 'GestureTarget.vala',
    meson.project_source_root() / 'lib' / 'Gestures' / 'RootTarget.vala',
    meson.project_source_root() / 'lib' / 'Gestures' / 'ScrollBackend.vala',
    meson.project_source_root() / 'lib' / 'Gestures' / 'SpringTimeline.vala',
    meson.project_source_root() / 'lib' / 'Gestures' / 'ToucheggBackend.vala',
    meson.project_source_root() / 'lib' / 'Gestures' / 'TouchpadBackend.vala',
)

tests = [
    'GestureControllerTest',
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

    test(test, test_executable, suite: ['Gala', 'Gala/lib'])
endforeach

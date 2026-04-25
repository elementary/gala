gala_common_enums = files(
  'CommonEnums.vala',
)

gala_lib_sources = files(
    'ActivatableComponent.vala',
    'BackgroundManager.vala',
    'Constants.vala',
    'DragDropAction.vala',
    'Plugin.vala',
    'SessionSettings.vala',
    'Utils.vala',
    'WindowManager.vala',
    'AppSystem/App.vala',
    'AppSystem/AppCache.vala',
    'AppSystem/AppSystem.vala',
    'Drawing/BufferSurface.vala',
    'Drawing/Canvas.vala',
    'Drawing/Color.vala',
    'Drawing/StyleManager.vala',
    'Drawing/Utilities.vala',
    'Effects/BackgroundBlurEffect.vala',
    'Effects/RoundedCornersEffect.vala',
    'Effects/ShadowEffect.vala',
    'Gestures/Backends/GestureBackend.vala',
    'Gestures/Backends/ToucheggBackend.vala',
    'Gestures/Backends/TouchpadBackend.vala',
    'Gestures/Backends/ScrollBackend.vala',
    'Gestures/Targets/ActorTarget.vala',
    'Gestures/Targets/GestureTarget.vala',
    'Gestures/Targets/PropertyTarget.vala',
    'Gestures/Targets/RootTarget.vala',
    'Gestures/Triggers/GestureTrigger.vala',
    'Gestures/Triggers/GlobalTrigger.vala',
    'Gestures/Triggers/SwipeTrigger.vala',
    'Gestures/Gesture.vala',
    'Gestures/GestureController.vala',
    'Gestures/GestureSettings.vala',
    'Gestures/SpringTimeline.vala',
    'Gestures/WorkspaceHideTracker.vala',
    'Widgets/AbstractSwitcher.vala',
    'Widgets/CanvasActor.vala',
    'Widgets/CloseButton.vala',
    'Widgets/FocusUtils.vala',
    'Widgets/Icon.vala',
    'Widgets/Image.vala',
    'Widgets/Root.vala',
    'Widgets/Text.vala',
    'Widgets/Widget.vala',
    'Widgets/WindowIcon.vala'
) + gala_common_enums

gala_resources = gnome.compile_resources(
    'gala-resources',
    join_paths(meson.global_source_root(), 'data', 'gala.gresource.xml'),
    source_dir: join_paths(meson.global_source_root(), 'data'),
    c_name: 'gala',
)

gala_lib = shared_library(
    'gala',
    gala_lib_sources,
    gala_resources,
    dependencies: [gala_base_dep],
    install: true,
    install_dir: [true, join_paths(get_option('includedir'), 'gala'), true],
    install_rpath: mutter_typelib_dir,
    version : '0.0.0'
)

deps_conf = configuration_data()
deps_conf.set('MUTTER_DEP', libmutter_dep.name())
config_h = configure_file(
    input: 'gala.deps.in',
    output: '@BASENAME@',
    configuration: deps_conf,
    install_dir: join_paths(get_option('datadir'), 'vala', 'vapi')
)

gala_dep = declare_dependency(link_with: [gala_lib], include_directories: include_directories('.'))

pkg.generate(
    gala_lib,
    filebase: 'gala',
    name: 'Gala',
    description: 'Library to develop plugins for Gala',
    subdirs: 'gala',
    requires: [glib_dep, gobject_dep, gio_dep, gio_unix_dep, libmutter_dep]
)

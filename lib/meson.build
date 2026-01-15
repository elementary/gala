gala_common_enums = files(
  'CommonEnums.vala',
)

gala_lib_sources = files(
    'ActivatableComponent.vala',
    'App.vala',
    'AppCache.vala',
    'AppSystem.vala',
    'BackgroundManager.vala',
    'CanvasActor.vala',
    'CloseButton.vala',
    'Constants.vala',
    'DragDropAction.vala',
    'Drawing/BufferSurface.vala',
    'Drawing/Canvas.vala',
    'Drawing/Color.vala',
    'Drawing/StyleManager.vala',
    'Drawing/Utilities.vala',
    'Icon.vala',
    'Image.vala',
    'Plugin.vala',
    'RoundedCornersEffect.vala',
    'ShadowEffect.vala',
    'Text.vala',
    'Utils.vala',
    'WindowIcon.vala',
    'WindowManager.vala',
    'Focusable/Focusable.vala',
    'Focusable/FocusController.vala',
    'Focusable/FocusUtils.vala',
    'Gestures/ActorTarget.vala',
    'Gestures/Gesture.vala',
    'Gestures/GestureBackend.vala',
    'Gestures/GestureController.vala',
    'Gestures/GestureSettings.vala',
    'Gestures/GestureTarget.vala',
    'Gestures/PropertyTarget.vala',
    'Gestures/RootTarget.vala',
    'Gestures/ScrollBackend.vala',
    'Gestures/SpringTimeline.vala',
    'Gestures/ToucheggBackend.vala',
    'Gestures/TouchpadBackend.vala',
    'Gestures/WorkspaceHideTracker.vala'
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

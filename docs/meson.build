valadoc = find_program('valadoc')

packages_command = [
    '--pkg', 'config',
    '--pkg', 'compat',
    '--pkg', 'cogl-fixes',
    '--pkg', 'gobject-2.0',
    '--pkg', 'glib-2.0',
    '--pkg', 'gio-2.0',
    '--pkg', 'gio-unix-2.0',
    '--pkg', 'gtk+-3.0',
    '--pkg', 'gdk-x11-3.0',
    '--pkg', 'libbamf3',
    '--pkg', 'plank',
    '--pkg', libmutter_name,
]

foreach libmutter_extra_pkg : libmutter_extra
    packages_command += ['--pkg', libmutter_extra_pkg]
endforeach

basic_command = [
    valadoc,
    '--force',
    '--verbose',
    '--package-name','gala',
    '--package-version', GALA_SO_VERSION,
    '--driver', meson.get_compiler('vala').version(),
    packages_command,
    vala_flags,
    '--vapidir=' + join_paths(meson.build_root(), 'lib'),
    '--vapidir=' + vapi_dir,
    '--doclet=html',
    '--use-svg-images'
]

libgala_doc_files = [
    join_paths(meson.source_root(), 'lib', 'ActivatableComponent.vala'),
    join_paths(meson.source_root(), 'lib', 'Plugin.vala'),
    join_paths(meson.source_root(), 'lib', 'Utils.vala'),
    join_paths(meson.source_root(), 'lib', 'WindowManager.vala'),
    join_paths(meson.source_root(), 'lib', 'WindowIcon.vala')
]

gala_doc_files = [
    join_paths(meson.source_root(), 'src', 'DBus.vala'),
    join_paths(meson.source_root(), 'src', 'DBusAccelerator.vala'),
    join_paths(meson.source_root(), 'src', 'DockThemeManager.vala'),
    join_paths(meson.source_root(), 'src', 'DragDropAction.vala'),
    join_paths(meson.source_root(), 'src', 'InternalUtils.vala'),
    join_paths(meson.source_root(), 'src', 'KeyboardManager.vala'),
    join_paths(meson.source_root(), 'src', 'Main.vala'),
    join_paths(meson.source_root(), 'src', 'MediaFeedback.vala'),
    join_paths(meson.source_root(), 'src', 'PluginManager.vala'),
    join_paths(meson.source_root(), 'src', 'ScreenSaver.vala'),
    join_paths(meson.source_root(), 'src', 'ScreenshotManager.vala'),
    join_paths(meson.source_root(), 'src', 'Settings.vala'),
    join_paths(meson.source_root(), 'src', 'ShadowEffect.vala'),
    join_paths(meson.source_root(), 'src', 'TextShadowEffect.vala'),
    join_paths(meson.source_root(), 'src', 'WindowListener.vala'),
    join_paths(meson.source_root(), 'src', 'WindowManager.vala'),
    join_paths(meson.source_root(), 'src', 'WorkspaceManager.vala'),
    join_paths(meson.source_root(), 'src', 'Background', 'Animation.vala'),
    join_paths(meson.source_root(), 'src', 'Background', 'Background.vala'),
    join_paths(meson.source_root(), 'src', 'Background', 'BackgroundCache.vala'),
    join_paths(meson.source_root(), 'src', 'Background', 'BackgroundContainer.vala'),
    join_paths(meson.source_root(), 'src', 'Background', 'BackgroundManager.vala'),
    join_paths(meson.source_root(), 'src', 'Background', 'BackgroundSource.vala'),
    join_paths(meson.source_root(), 'src', 'Background', 'SystemBackground.vala'),
    join_paths(meson.source_root(), 'src', 'Widgets', 'IconGroup.vala'),
    join_paths(meson.source_root(), 'src', 'Widgets', 'IconGroupContainer.vala'),
    join_paths(meson.source_root(), 'src', 'Widgets', 'MonitorClone.vala'),
    join_paths(meson.source_root(), 'src', 'Widgets', 'MultitaskingView.vala'),
    join_paths(meson.source_root(), 'src', 'Widgets', 'SafeWindowClone.vala'),
    join_paths(meson.source_root(), 'src', 'Widgets', 'WindowClone.vala'),
    join_paths(meson.source_root(), 'src', 'Widgets', 'WindowCloneContainer.vala'),
    join_paths(meson.source_root(), 'src', 'Widgets', 'WindowIconActor.vala'),
    join_paths(meson.source_root(), 'src', 'Widgets', 'WindowMenu.vala'),
    join_paths(meson.source_root(), 'src', 'Widgets', 'WindowOverview.vala'),
    join_paths(meson.source_root(), 'src', 'Widgets', 'WindowSwitcher.vala'),
    join_paths(meson.source_root(), 'src', 'Widgets', 'WorkspaceClone.vala'),
    join_paths(meson.source_root(), 'src', 'Widgets', 'WorkspaceInsertThumb.vala')
]

doc_target = custom_target(
    'library documentation',
    command: [
        basic_command,
        '-o', join_paths(meson.build_root(), 'docs', 'library'),
        '@INPUT@'
    ],
    build_by_default: true,
    input: libgala_doc_files,
    output: 'library'
)

all_doc_target = custom_target(
    'full documentation',
    command: [
        basic_command,
        '--internal',
        '--pkg', 'granite',
        '--pkg', 'gnome-desktop-3.0',
        '--pkg', 'gmodule-2.0',
        '-o', join_paths(meson.build_root(), 'docs', 'full'),
        '@INPUT@'
    ],
    build_by_default: true,
    input: libgala_doc_files + gala_doc_files,
    output: 'full'
)

pip_files = files([
    'Main.vala',
    'ShadowEffect.vala',
    'SelectionArea.vala',
    'PopupWindow.vala',
    'MoveAction.vala'
])

shared_module(
    'gala-pip',
    pip_files,
    dependencies: [core_dependencies, gala_dependencies],
    install: true,
    install_dir: plugin_dir
)

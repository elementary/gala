
install_data(
    'gala.css',
    'texture.png',
    install_dir: pkg_data_dir)

install_data(
    'org.pantheon.desktop.gala.gschema.xml',
    install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas')
)

i18n.merge_file (
    'desktop',
    input: 'gala-multitaskingview.desktop.in',
    output: 'gala-multitaskingview.desktop',
    install: true,
    install_dir: join_paths(get_option('datadir'), 'applications'),
    po_dir: join_paths(meson.source_root (), 'po'),
    type: 'desktop'
)

i18n.merge_file (
    'desktop',
    input: 'gala-other.desktop.in',
    output: 'gala-other.desktop',
    install: true,
    install_dir: join_paths(get_option('datadir'), 'applications'),
    po_dir: join_paths(meson.source_root (), 'po'),
    type: 'desktop'
)

install_data(
    'gala.desktop',
    'gala-wayland.desktop',
    install_dir: join_paths(get_option('datadir'), 'applications')
)

install_data(
    join_paths('icons', '32x32', 'multitasking-view.svg'),
    install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', '32x32', 'apps')
)

install_data(
    join_paths('icons', '48x48', 'multitasking-view.svg'),
    install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', '48x48', 'apps')
)

install_data(
    join_paths('icons', '64x64', 'multitasking-view.svg'),
    install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', '64x64', 'apps')
)

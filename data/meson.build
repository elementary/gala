install_data(
    'gala.gschema.xml',
    install_dir: join_paths(data_dir, 'glib-2.0', 'schemas'),
    rename: 'org.pantheon.desktop.gala.gschema.xml'
)

install_data(
    'gala-daemon.desktop',
    install_dir: join_paths(get_option('sysconfdir'), 'xdg', 'autostart')
)

i18n.merge_file(
    input: 'gala.appdata.xml.in',
    output: meson.project_name() + '.appdata.xml',
    po_dir: join_paths(meson.source_root(), 'po'),
    type: 'xml',
    install: true,
    install_dir: join_paths(get_option('datadir'), 'metainfo'),
)

i18n.merge_file(
	input: 'gala-multitaskingview.desktop.in',
	output: 'gala-multitaskingview.desktop',
	po_dir: join_paths(meson.source_root (), 'po'),
	type: 'desktop',
	install: true,
	install_dir: join_paths(data_dir, 'applications')
)
i18n.merge_file(
	input: 'gala-other.desktop.in',
	output: 'gala-other.desktop',
	po_dir: join_paths(meson.source_root (), 'po'),
	type: 'desktop',
	install: true,
	install_dir: join_paths(data_dir, 'applications')
)
install_data(['gala.desktop', 'gala-wayland.desktop'], install_dir: join_paths(data_dir, 'applications'))
install_data(files('20_elementary.pantheon.wm.gschema.override'), install_dir: join_paths(data_dir, 'glib-2.0', 'schemas'))

icons_dir = join_paths(get_option('datadir'), 'icons', 'hicolor')
install_data('icons/32x32/multitasking-view.svg', install_dir: join_paths(icons_dir, '32x32', 'apps'))
install_data('icons/48x48/multitasking-view.svg', install_dir: join_paths(icons_dir, '48x48', 'apps'))
install_data('icons/64x64/multitasking-view.svg', install_dir: join_paths(icons_dir, '64x64', 'apps'))

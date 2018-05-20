gala_gschema = configure_file(
	input: 'org.pantheon.desktop.gala.gschema.xml.in',
	output: 'org.pantheon.desktop.gala.gschema.xml',
	configuration: customconf,
	install: true,
	install_dir: join_paths(data_dir, 'glib-2.0', 'schemas')
)

gala_gschema_compile = gnome.compile_schemas()

msgfmt = find_program('msgfmt')

custom_target('gala-multitaskingview.desktop_merge',
    input: 'gala-multitaskingview.desktop.in',
    output: 'gala-multitaskingview.desktop',
    command : [msgfmt,
               '--desktop',
               '--keyword=Comment',
               '--keyword=Name',
               '--keyword=Keywords',
               '--keyword=GenericName',
               '-d' + join_paths(meson.source_root (), 'po'),
               '--template=@INPUT@',
               '-o@OUTPUT@',
               ],
    install : true,
    install_dir: join_paths(data_dir, 'applications')
)

custom_target('gala-other.desktop_merge',
    input: 'gala-other.desktop.in',
    output: 'gala-other.desktop',
    command : [msgfmt,
               '--desktop',
               '--keyword=Comment',
               '--keyword=Name',
               '--keyword=Keywords',
               '--keyword=GenericName',
               '-d' + join_paths(meson.source_root (), 'po'),
               '--template=@INPUT@',
               '-o@OUTPUT@',
               ],
    install : true,
    install_dir: join_paths(data_dir, 'applications')
)

install_data(['gala.desktop', 'gala-wayland.desktop'], install_dir: join_paths(data_dir, 'applications'))

icons_dir = join_paths(get_option('datadir'), 'icons', 'hicolor')
install_data('icons/32x32/multitasking-view.svg', install_dir: join_paths(icons_dir, '32x32', 'apps'))
install_data('icons/48x48/multitasking-view.svg', install_dir: join_paths(icons_dir, '48x48', 'apps'))
install_data('icons/64x64/multitasking-view.svg', install_dir: join_paths(icons_dir, '64x64', 'apps'))

install_data(['gala.css', 'texture.png'], install_dir: pkgdata_dir)

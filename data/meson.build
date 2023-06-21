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
    input: 'gala.metainfo.xml.in',
    output: meson.project_name() + '.metainfo.xml',
    po_dir: meson.global_source_root() / 'po',
    type: 'xml',
    install: true,
    install_dir: get_option('datadir') / 'metainfo',
)

i18n.merge_file(
    input: 'gala-multitaskingview.desktop.in',
    output: 'gala-multitaskingview.desktop',
    po_dir: join_paths(meson.global_source_root (), 'po'),
    type: 'desktop',
    install: true,
    install_dir: join_paths(data_dir, 'applications')
)

i18n.merge_file(
    input: 'gala-other.desktop.in',
    output: 'gala-other.desktop',
    po_dir: join_paths(meson.global_source_root (), 'po'),
    type: 'desktop',
    install: true,
    install_dir: join_paths(data_dir, 'applications')
)
install_data(['gala.desktop', 'gala-wayland.desktop'], install_dir: join_paths(data_dir, 'applications'))
install_data(files('20_elementary.pantheon.wm.gschema.override'), install_dir: join_paths(data_dir, 'glib-2.0', 'schemas'))

if get_option('systemd')
    dep_systemd = dependency('systemd', required: true)
    systemd_userunitdir = get_option('systemduserunitdir')
    if systemd_userunitdir == ''
        systemd_userunitdir = dep_systemd.get_variable('systemduserunitdir', pkgconfig_define: ['prefix', get_option('prefix')])
    endif

    bindir = join_paths(get_option('prefix'), get_option('bindir'))
    unit_conf = configuration_data()
    unit_conf.set('bindir', bindir)

    configure_file(
        input: 'gala@x11.service.in',
        output: 'io.elementary.gala@x11.service',
        install: true,
        install_dir: systemd_userunitdir,
        configuration: unit_conf
    )

    configure_file(
        input: 'gala@wayland.service.in',
        output: 'io.elementary.gala@wayland.service',
        install: true,
        install_dir: systemd_userunitdir,
        configuration: unit_conf
    )

    install_data(
        'gala.target',
        rename: 'io.elementary.gala.target',
        install_dir: systemd_userunitdir
    )
endif

vapigen_args = [
	'--directory=@0@'.format(meson.current_build_dir()),
	'--metadatadir=@0@'.format(meson.current_source_dir()),
	'--girdir=@0@'.format(mutter_typelib_dir),
	'--vapidir=@0@'.format(meson.current_build_dir()),
	'--vapidir=@0@'.format(meson.current_source_dir()),
]

libmutter_mtk_name = 'mutter-mtk-18'
libmutter_cogl_name = 'mutter-cogl-18'
libmutter_clutter_name = 'mutter-clutter-18'
libmutter_name = 'libmutter-18'

libmutter_mtk_gir_name = 'Mtk-18'
libmutter_cogl_gir_name = 'Cogl-18'
libmutter_clutter_gir_name = 'Clutter-18'
libmutter_gir_name = 'Meta-18'

mtk_target = custom_target(
    libmutter_mtk_name,
    command: [
        vapigen,
        mutter_typelib_dir / libmutter_mtk_gir_name + '.gir',
        '--library=' + libmutter_mtk_name,
        '--pkg=gobject-2.0',
        '--pkg=gio-2.0',
        '--pkg=cairo',
        '--pkg=graphene-gobject-1.0',
        vapigen_args
    ],
    output: libmutter_mtk_name + '.vapi'
)
cogl_target = custom_target(
    libmutter_cogl_name,
    command: [
        vapigen,
        mutter_typelib_dir / libmutter_cogl_gir_name + '.gir',
        files(libmutter_cogl_gir_name + '-custom.vala'),
        '--library=' + libmutter_cogl_name,
        '--pkg=' + libmutter_mtk_name,
        '--pkg=gobject-2.0',
        '--pkg=gio-2.0',
        '--pkg=cairo',
        '--pkg=graphene-gobject-1.0',
        '--pkg=x11',
        vapigen_args,
    ],
    depends: mtk_target,
    output: libmutter_cogl_name + '.vapi'
)

clutter_target = custom_target(
    libmutter_clutter_name,
    command: [
        vapigen,
        mutter_typelib_dir / libmutter_clutter_gir_name + '.gir',
        '--library=' + libmutter_clutter_name,
        '--pkg=graphene-gobject-1.0',
        '--pkg=' + libmutter_mtk_name,
        '--pkg=' + libmutter_cogl_name,
        '--pkg=atk',
        '--pkg=gio-2.0',
        '--pkg=json-glib-1.0',
        '--pkg=pango',
        '--pkg=x11',
        vapigen_args,
    ],
    depends: [ cogl_target, mtk_target ],
    output: libmutter_clutter_name + '.vapi'
)

libmutter_target = custom_target(
    libmutter_name,
    command: [
        vapigen,
        mutter_typelib_dir / libmutter_gir_name + '.gir',
        files(libmutter_gir_name + '-custom.vala'),
        '--library=' + libmutter_name,
        '--pkg=graphene-gobject-1.0',
        '--pkg=' + libmutter_cogl_name,
        '--pkg=' + libmutter_clutter_name,
        '--pkg=atk',
        '--pkg=gio-2.0',
        '--pkg=json-glib-1.0',
        '--pkg=pango',
        '--pkg=x11',
        '--pkg=xfixes-4.0',
        vapigen_args,
    ],
    depends: [ cogl_target, clutter_target ],
    output: libmutter_name + '.vapi'
)

vapigen_args = [
	'--directory=@0@'.format(meson.current_build_dir()),
	'--metadatadir=@0@'.format(meson.current_source_dir()),
	'--girdir=@0@'.format(mutter_typelib_dir),
	'--vapidir=@0@'.format(meson.current_build_dir()),
	'--vapidir=@0@'.format(meson.current_source_dir()),
]

if mutter50_dep.found()
	mtk_target = custom_target('mutter-mtk-18',
		command: [
			vapigen,
			mutter_typelib_dir / 'Mtk-18.gir',
			'--library=mutter-mtk-18',
			'--pkg=gobject-2.0',
			'--pkg=gio-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			vapigen_args
		],
		output: 'mutter-mtk-18.vapi'
	)
	cogl_target = custom_target('mutter-cogl-18',
		command: [
			vapigen,
			mutter_typelib_dir / 'Cogl-18.gir',
			'--library=mutter-cogl-18',
			'--pkg=mutter-mtk-18',
			'--pkg=gobject-2.0',
			'--pkg=gio-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			'--pkg=x11',
			vapigen_args,
			files('Cogl-18-custom.vala')
		],
		depends: mtk_target,
		output: 'mutter-cogl-18.vapi'
	)

	clutter_target = custom_target('mutter-clutter-18',
		command: [
			vapigen,
			mutter_typelib_dir / 'Clutter-18.gir',
			'--library=mutter-clutter-18',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-mtk-18',
			'--pkg=mutter-cogl-18',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pango',
			'--pkg=x11',
			vapigen_args,
		],
		depends: [ cogl_target, mtk_target ],
		output: 'mutter-clutter-18.vapi'
	)

	libmutter_target = custom_target('libmutter-18',
		command: [
			vapigen,
			mutter_typelib_dir / 'Meta-18.gir',
			'--library=libmutter-18',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-18',
			'--pkg=mutter-clutter-18',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pango',
			'--pkg=x11',
			'--pkg=xfixes-4.0',
			vapigen_args,
			files('Meta-18-custom.vala')
		],
		depends: [ cogl_target, clutter_target ],
		output: 'libmutter-18.vapi'
	)
endif
if mutter51_dep.found()
	mtk_target = custom_target('mutter-mtk-51',
		command: [
			vapigen,
			mutter_typelib_dir / 'Mtk-51.gir',
			'--library=mutter-mtk-51',
			'--pkg=gobject-2.0',
			'--pkg=gio-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			vapigen_args
		],
		output: 'mutter-mtk-51.vapi'
	)
	cogl_target = custom_target('mutter-cogl-51',
		command: [
			vapigen,
			mutter_typelib_dir / 'Cogl-51.gir',
			'--library=mutter-cogl-51',
			'--pkg=mutter-mtk-51',
			'--pkg=gobject-2.0',
			'--pkg=gio-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			'--pkg=x11',
			vapigen_args,
			files('Cogl-51-custom.vala')
		],
		depends: mtk_target,
		output: 'mutter-cogl-51.vapi'
	)

	clutter_target = custom_target('mutter-clutter-51',
		command: [
			vapigen,
			mutter_typelib_dir / 'Clutter-51.gir',
			'--library=mutter-clutter-51',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-mtk-51',
			'--pkg=mutter-cogl-51',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pango',
			'--pkg=x11',
			vapigen_args,
		],
		depends: [ cogl_target, mtk_target ],
		output: 'mutter-clutter-51.vapi'
	)

	libmutter_target = custom_target('libmutter-51',
		command: [
			vapigen,
			mutter_typelib_dir / 'Meta-51.gir',
			'--library=libmutter-51',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-51',
			'--pkg=mutter-clutter-51',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pango',
			'--pkg=x11',
			'--pkg=xfixes-4.0',
			vapigen_args
		],
		depends: [ cogl_target, clutter_target ],
		output: 'libmutter-51.vapi'
	)
endif

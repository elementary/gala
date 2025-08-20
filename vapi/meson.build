vapigen_args = [
	'--directory=@0@'.format(meson.current_build_dir()),
	'--metadatadir=@0@'.format(meson.current_source_dir()),
	'--girdir=@0@'.format(mutter_typelib_dir),
	'--vapidir=@0@'.format(meson.current_build_dir()),
	'--vapidir=@0@'.format(meson.current_source_dir()),
]

if mutter45_dep.found()
	mtk_target = custom_target('mutter-mtk-13',
		command: [
			vapigen,
			mutter_typelib_dir / 'Mtk-13.gir',
			'--library=mutter-mtk-13',
			'--pkg=gobject-2.0',
			'--pkg=gio-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			vapigen_args
		],
		output: 'mutter-mtk-13.vapi'
	)
	cogl_target = custom_target('mutter-cogl-13',
		command: [
			vapigen,
			mutter_typelib_dir / 'Cogl-13.gir',
			'--library=mutter-cogl-13',
			'--pkg=gobject-2.0',
			'--pkg=gio-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			vapigen_args,
			files('Cogl-13-custom.vala')
		],
		output: 'mutter-cogl-13.vapi'
	)

	cogl_pango_target = custom_target('mutter-cogl-pango-13',
		command: [
			vapigen,
			mutter_typelib_dir / 'CoglPango-13.gir',
			'--library=mutter-cogl-pango-13',
			'--pkg=mutter-cogl-13',
			'--pkg=pangocairo',
			'--pkg=gio-2.0',
			'--pkg=glib-2.0',
			vapigen_args
		],
		depends: cogl_target,
		output: 'mutter-cogl-pango-13.vapi'
	)

	clutter_target = custom_target('mutter-clutter-13',
		command: [
			vapigen,
			mutter_typelib_dir / 'Clutter-13.gir',
			'--library=mutter-clutter-13',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-13',
			'--pkg=mutter-cogl-pango-13',
			'--pkg=mutter-mtk-13',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pangocairo',
			vapigen_args,
			files('Clutter-13-custom.vala')
		],
		depends: [ cogl_target, cogl_pango_target, mtk_target ],
		output: 'mutter-clutter-13.vapi'
	)

	libmutter_target = custom_target('libmutter-13',
		command: [
			vapigen,
			mutter_typelib_dir / 'Meta-13.gir',
			'--library=libmutter-13',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-13',
			'--pkg=mutter-cogl-pango-13',
			'--pkg=mutter-clutter-13',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pangocairo',
			'--pkg=x11',
			'--pkg=xfixes-4.0',
			vapigen_args
		],
		depends: [ cogl_target, cogl_pango_target, clutter_target ],
		output: 'libmutter-13.vapi'
	)
endif
if mutter46_dep.found()
	mtk_target = custom_target('mutter-mtk-14',
		command: [
			vapigen,
			mutter_typelib_dir / 'Mtk-14.gir',
			'--library=mutter-mtk-14',
			'--pkg=gobject-2.0',
			'--pkg=gio-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			vapigen_args
		],
		output: 'mutter-mtk-14.vapi'
	)
	cogl_target = custom_target('mutter-cogl-14',
		command: [
			vapigen,
			mutter_typelib_dir / 'Cogl-14.gir',
			'--library=mutter-cogl-14',
			'--pkg=mutter-mtk-14',
			'--pkg=gobject-2.0',
			'--pkg=gio-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			'--pkg=x11',
			vapigen_args,
			files('Cogl-14-custom.vala')
		],
		depends: mtk_target,
		output: 'mutter-cogl-14.vapi'
	)

	cogl_pango_target = custom_target('mutter-cogl-pango-14',
		command: [
			vapigen,
			mutter_typelib_dir / 'CoglPango-14.gir',
			'--library=mutter-cogl-pango-14',
			'--pkg=mutter-mtk-14',
			'--pkg=mutter-cogl-14',
			'--pkg=pangocairo',
			'--pkg=gio-2.0',
			'--pkg=glib-2.0',
			'--pkg=x11',
			vapigen_args
		],
		depends: [mtk_target, cogl_target],
		output: 'mutter-cogl-pango-14.vapi'
	)

	clutter_target = custom_target('mutter-clutter-14',
		command: [
			vapigen,
			mutter_typelib_dir / 'Clutter-14.gir',
			'--library=mutter-clutter-14',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-mtk-14',
			'--pkg=mutter-cogl-14',
			'--pkg=mutter-cogl-pango-14',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pangocairo',
			'--pkg=x11',
			vapigen_args,
			files('Clutter-14-custom.vala')
		],
		depends: [ cogl_target, cogl_pango_target, mtk_target ],
		output: 'mutter-clutter-14.vapi'
	)

	libmutter_target = custom_target('libmutter-14',
		command: [
			vapigen,
			mutter_typelib_dir / 'Meta-14.gir',
			'--library=libmutter-14',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-14',
			'--pkg=mutter-cogl-pango-14',
			'--pkg=mutter-clutter-14',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pangocairo',
			'--pkg=x11',
			'--pkg=xfixes-4.0',
			vapigen_args
		],
		depends: [ cogl_target, cogl_pango_target, clutter_target ],
		output: 'libmutter-14.vapi'
	)
endif
if mutter47_dep.found()
	mtk_target = custom_target('mutter-mtk-15',
		command: [
			vapigen,
			mutter_typelib_dir / 'Mtk-15.gir',
			'--library=mutter-mtk-15',
			'--pkg=gobject-2.0',
			'--pkg=gio-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			vapigen_args
		],
		output: 'mutter-mtk-15.vapi'
	)
	cogl_target = custom_target('mutter-cogl-15',
		command: [
			vapigen,
			mutter_typelib_dir / 'Cogl-15.gir',
			'--library=mutter-cogl-15',
			'--pkg=mutter-mtk-15',
			'--pkg=gobject-2.0',
			'--pkg=gio-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			'--pkg=x11',
			vapigen_args,
			files('Cogl-15-custom.vala')
		],
		depends: mtk_target,
		output: 'mutter-cogl-15.vapi'
	)

	cogl_pango_target = custom_target('mutter-cogl-pango-15',
		command: [
			vapigen,
			mutter_typelib_dir / 'CoglPango-15.gir',
			'--library=mutter-cogl-pango-15',
			'--pkg=mutter-mtk-15',
			'--pkg=mutter-cogl-15',
			'--pkg=pangocairo',
			'--pkg=gio-2.0',
			'--pkg=glib-2.0',
			'--pkg=x11',
			vapigen_args
		],
		depends: [mtk_target, cogl_target],
		output: 'mutter-cogl-pango-15.vapi'
	)

	clutter_target = custom_target('mutter-clutter-15',
		command: [
			vapigen,
			mutter_typelib_dir / 'Clutter-15.gir',
			'--library=mutter-clutter-15',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-mtk-15',
			'--pkg=mutter-cogl-15',
			'--pkg=mutter-cogl-pango-15',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pangocairo',
			'--pkg=x11',
			vapigen_args,
		],
		depends: [ cogl_target, cogl_pango_target, mtk_target ],
		output: 'mutter-clutter-15.vapi'
	)

	libmutter_target = custom_target('libmutter-15',
		command: [
			vapigen,
			mutter_typelib_dir / 'Meta-15.gir',
			'--library=libmutter-15',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-15',
			'--pkg=mutter-cogl-pango-15',
			'--pkg=mutter-clutter-15',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pangocairo',
			'--pkg=x11',
			'--pkg=xfixes-4.0',
			vapigen_args
		],
		depends: [ cogl_target, cogl_pango_target, clutter_target ],
		output: 'libmutter-15.vapi'
	)
endif
if mutter48_dep.found()
	mtk_target = custom_target('mutter-mtk-16',
		command: [
			vapigen,
			mutter_typelib_dir / 'Mtk-16.gir',
			'--library=mutter-mtk-16',
			'--pkg=gobject-2.0',
			'--pkg=gio-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			vapigen_args
		],
		output: 'mutter-mtk-16.vapi'
	)
	cogl_target = custom_target('mutter-cogl-16',
		command: [
			vapigen,
			mutter_typelib_dir / 'Cogl-16.gir',
			'--library=mutter-cogl-16',
			'--pkg=mutter-mtk-16',
			'--pkg=gobject-2.0',
			'--pkg=gio-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			'--pkg=x11',
			vapigen_args,
			files('Cogl-16-custom.vala')
		],
		depends: mtk_target,
		output: 'mutter-cogl-16.vapi'
	)

	clutter_target = custom_target('mutter-clutter-16',
		command: [
			vapigen,
			mutter_typelib_dir / 'Clutter-16.gir',
			'--library=mutter-clutter-16',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-mtk-16',
			'--pkg=mutter-cogl-16',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pango',
			'--pkg=x11',
			vapigen_args,
		],
		depends: [ cogl_target, mtk_target ],
		output: 'mutter-clutter-16.vapi'
	)

	libmutter_target = custom_target('libmutter-16',
		command: [
			vapigen,
			mutter_typelib_dir / 'Meta-16.gir',
			'--library=libmutter-16',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-16',
			'--pkg=mutter-clutter-16',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pango',
			'--pkg=x11',
			'--pkg=xfixes-4.0',
			vapigen_args
		],
		depends: [ cogl_target, clutter_target ],
		output: 'libmutter-16.vapi'
	)
endif
if mutter49_dep.found()
	mtk_target = custom_target('mutter-mtk-17',
		command: [
			vapigen,
			mutter_typelib_dir / 'Mtk-17.gir',
			'--library=mutter-mtk-17',
			'--pkg=gobject-2.0',
			'--pkg=gio-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			vapigen_args
		],
		output: 'mutter-mtk-17.vapi'
	)
	cogl_target = custom_target('mutter-cogl-17',
		command: [
			vapigen,
			mutter_typelib_dir / 'Cogl-17.gir',
			'--library=mutter-cogl-17',
			'--pkg=mutter-mtk-17',
			'--pkg=gobject-2.0',
			'--pkg=gio-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			'--pkg=x11',
			vapigen_args,
			files('Cogl-17-custom.vala')
		],
		depends: mtk_target,
		output: 'mutter-cogl-17.vapi'
	)

	clutter_target = custom_target('mutter-clutter-17',
		command: [
			vapigen,
			mutter_typelib_dir / 'Clutter-17.gir',
			'--library=mutter-clutter-17',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-mtk-17',
			'--pkg=mutter-cogl-17',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pango',
			'--pkg=x11',
			vapigen_args,
		],
		depends: [ cogl_target, mtk_target ],
		output: 'mutter-clutter-17.vapi'
	)

	libmutter_target = custom_target('libmutter-17',
		command: [
			vapigen,
			mutter_typelib_dir / 'Meta-17.gir',
			'--library=libmutter-17',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-17',
			'--pkg=mutter-clutter-17',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pango',
			'--pkg=x11',
			'--pkg=xfixes-4.0',
			vapigen_args
		],
		depends: [ cogl_target, clutter_target ],
		output: 'libmutter-17.vapi'
	)
endif

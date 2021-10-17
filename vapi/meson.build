vapigen_args = [
	'--directory=@0@'.format(meson.current_build_dir()),
	'--metadatadir=@0@'.format(meson.current_source_dir()),
	'--girdir=@0@'.format(mutter_typelib_dir),
	'--vapidir=@0@'.format(meson.current_build_dir()),
	'--vapidir=@0@'.format(meson.current_source_dir()),
]

if mutter336_dep.found()
	cogl_target = custom_target('mutter-cogl-6',
		command: [
			vapigen,
			mutter_typelib_dir / 'Cogl-6.gir',
			'--library=mutter-cogl-6',
			'--pkg=mutter-cogl-path-6',
			'--pkg=gobject-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			vapigen_args,
			files('Cogl-6-custom.vala')
		],
		output: 'mutter-cogl-6.vapi'
	)

	cogl_pango_target = custom_target('mutter-cogl-pango-6',
		command: [
			vapigen,
			mutter_typelib_dir / 'CoglPango-6.gir',
			'--library=mutter-cogl-pango-6',
			'--pkg=mutter-cogl-path-6',
			'--pkg=mutter-cogl-6',
			'--pkg=pangocairo',
			vapigen_args
		],
		depends: cogl_target,
		output: 'mutter-cogl-pango-6.vapi'
	)

	clutter_target = custom_target('mutter-clutter-6',
		command: [
			vapigen,
			mutter_typelib_dir / 'Clutter-6.gir',
			'--library=mutter-clutter-6',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-6',
			'--pkg=mutter-cogl-pango-6',
			'--pkg=mutter-cogl-path-6',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pangocairo',
			vapigen_args,
			files('Clutter-6-custom.vala')
		],
		depends: [ cogl_target, cogl_pango_target ],
		output: 'mutter-clutter-6.vapi'
	)

	libmutter_target = custom_target('libmutter-6',
		command: [
			vapigen,
			mutter_typelib_dir / 'Meta-6.gir',
			'--library=libmutter-6',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-6',
			'--pkg=mutter-cogl-pango-6',
			'--pkg=mutter-cogl-path-6',
			'--pkg=mutter-clutter-6',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pangocairo',
			'--pkg=gtk+-3.0',
			'--pkg=x11',
			'--pkg=xfixes-4.0',
			vapigen_args
		],
		depends: [ cogl_target, cogl_pango_target, clutter_target ],
		output: 'libmutter-6.vapi'
	)
endif
if mutter338_dep.found()
	cogl_target = custom_target('mutter-cogl-7',
		command: [
			vapigen,
			mutter_typelib_dir / 'Cogl-7.gir',
			'--library=mutter-cogl-7',
			'--pkg=gobject-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			vapigen_args,
			files('Cogl-7-custom.vala')
		],
		output: 'mutter-cogl-7.vapi'
	)

	cogl_pango_target = custom_target('mutter-cogl-pango-7',
		command: [
			vapigen,
			mutter_typelib_dir / 'CoglPango-7.gir',
			'--library=mutter-cogl-pango-7',
			'--pkg=mutter-cogl-7',
			'--pkg=pangocairo',
			vapigen_args
		],
		depends: cogl_target,
		output: 'mutter-cogl-pango-7.vapi'
	)

	clutter_target = custom_target('mutter-clutter-7',
		command: [
			vapigen,
			mutter_typelib_dir / 'Clutter-7.gir',
			'--library=mutter-clutter-7',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-7',
			'--pkg=mutter-cogl-pango-7',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pangocairo',
			vapigen_args,
			files('Clutter-7-custom.vala')
		],
		depends: [ cogl_target, cogl_pango_target ],
		output: 'mutter-clutter-7.vapi'
	)

	libmutter_target = custom_target('libmutter-7',
		command: [
			vapigen,
			mutter_typelib_dir / 'Meta-7.gir',
			'--library=libmutter-7',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-7',
			'--pkg=mutter-cogl-pango-7',
			'--pkg=mutter-clutter-7',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pangocairo',
			'--pkg=gtk+-3.0',
			'--pkg=x11',
			'--pkg=xfixes-4.0',
			vapigen_args
		],
		depends: [ cogl_target, cogl_pango_target, clutter_target ],
		output: 'libmutter-7.vapi'
	)
endif
if mutter40_dep.found()
	cogl_target = custom_target('mutter-cogl-8',
		command: [
			vapigen,
			mutter_typelib_dir / 'Cogl-8.gir',
			'--library=mutter-cogl-8',
			'--pkg=gobject-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			vapigen_args,
			files('Cogl-8-custom.vala')
		],
		output: 'mutter-cogl-8.vapi'
	)

	cogl_pango_target = custom_target('mutter-cogl-pango-8',
		command: [
			vapigen,
			mutter_typelib_dir / 'CoglPango-8.gir',
			'--library=mutter-cogl-pango-8',
			'--pkg=mutter-cogl-8',
			'--pkg=pangocairo',
			vapigen_args
		],
		depends: cogl_target,
		output: 'mutter-cogl-pango-8.vapi'
	)

	clutter_target = custom_target('mutter-clutter-8',
		command: [
			vapigen,
			mutter_typelib_dir / 'Clutter-8.gir',
			'--library=mutter-clutter-8',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-8',
			'--pkg=mutter-cogl-pango-8',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pangocairo',
			vapigen_args,
			files('Clutter-8-custom.vala')
		],
		depends: [ cogl_target, cogl_pango_target ],
		output: 'mutter-clutter-8.vapi'
	)

	libmutter_target = custom_target('libmutter-8',
		command: [
			vapigen,
			mutter_typelib_dir / 'Meta-8.gir',
			'--library=libmutter-8',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-8',
			'--pkg=mutter-cogl-pango-8',
			'--pkg=mutter-clutter-8',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pangocairo',
			'--pkg=gtk+-3.0',
			'--pkg=x11',
			'--pkg=xfixes-4.0',
			vapigen_args
		],
		depends: [ cogl_target, cogl_pango_target, clutter_target ],
		output: 'libmutter-8.vapi'
	)
endif
if mutter41_dep.found()
	cogl_target = custom_target('mutter-cogl-9',
		command: [
			vapigen,
			mutter_typelib_dir / 'Cogl-9.gir',
			'--library=mutter-cogl-9',
			'--pkg=gobject-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			vapigen_args,
			files('Cogl-9-custom.vala')
		],
		output: 'mutter-cogl-9.vapi'
	)

	cogl_pango_target = custom_target('mutter-cogl-pango-9',
		command: [
			vapigen,
			mutter_typelib_dir / 'CoglPango-9.gir',
			'--library=mutter-cogl-pango-9',
			'--pkg=mutter-cogl-9',
			'--pkg=pangocairo',
			vapigen_args
		],
		depends: cogl_target,
		output: 'mutter-cogl-pango-9.vapi'
	)

	clutter_target = custom_target('mutter-clutter-9',
		command: [
			vapigen,
			mutter_typelib_dir / 'Clutter-9.gir',
			'--library=mutter-clutter-9',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-9',
			'--pkg=mutter-cogl-pango-9',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pangocairo',
			vapigen_args,
			files('Clutter-9-custom.vala')
		],
		depends: [ cogl_target, cogl_pango_target ],
		output: 'mutter-clutter-9.vapi'
	)

	libmutter_target = custom_target('libmutter-9',
		command: [
			vapigen,
			mutter_typelib_dir / 'Meta-9.gir',
			'--library=libmutter-9',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-9',
			'--pkg=mutter-cogl-pango-9',
			'--pkg=mutter-clutter-9',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pangocairo',
			'--pkg=gtk+-3.0',
			'--pkg=x11',
			'--pkg=xfixes-4.0',
			vapigen_args
		],
		depends: [ cogl_target, cogl_pango_target, clutter_target ],
		output: 'libmutter-9.vapi'
	)
endif

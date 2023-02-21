vapigen_args = [
	'--directory=@0@'.format(meson.current_build_dir()),
	'--metadatadir=@0@'.format(meson.current_source_dir()),
	'--girdir=@0@'.format(mutter_typelib_dir),
	'--vapidir=@0@'.format(meson.current_build_dir()),
	'--vapidir=@0@'.format(meson.current_source_dir()),
]

if mutter42_dep.found()
	cogl_target = custom_target('mutter-cogl-10',
		command: [
			vapigen,
			mutter_typelib_dir / 'Cogl-10.gir',
			'--library=mutter-cogl-10',
			'--pkg=gobject-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			vapigen_args,
			files('Cogl-10-custom.vala')
		],
		output: 'mutter-cogl-10.vapi'
	)

	cogl_pango_target = custom_target('mutter-cogl-pango-10',
		command: [
			vapigen,
			mutter_typelib_dir / 'CoglPango-10.gir',
			'--library=mutter-cogl-pango-10',
			'--pkg=mutter-cogl-10',
			'--pkg=pangocairo',
			vapigen_args
		],
		depends: cogl_target,
		output: 'mutter-cogl-pango-10.vapi'
	)

	clutter_target = custom_target('mutter-clutter-10',
		command: [
			vapigen,
			mutter_typelib_dir / 'Clutter-10.gir',
			'--library=mutter-clutter-10',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-10',
			'--pkg=mutter-cogl-pango-10',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pangocairo',
			vapigen_args,
			files('Clutter-10-custom.vala')
		],
		depends: [ cogl_target, cogl_pango_target ],
		output: 'mutter-clutter-10.vapi'
	)

	libmutter_target = custom_target('libmutter-10',
		command: [
			vapigen,
			mutter_typelib_dir / 'Meta-10.gir',
			'--library=libmutter-10',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-10',
			'--pkg=mutter-cogl-pango-10',
			'--pkg=mutter-clutter-10',
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
		output: 'libmutter-10.vapi'
	)
endif
if mutter43_dep.found()
	cogl_target = custom_target('mutter-cogl-11',
		command: [
			vapigen,
			mutter_typelib_dir / 'Cogl-11.gir',
			'--library=mutter-cogl-11',
			'--pkg=gobject-2.0',
			'--pkg=gio-2.0',
			'--pkg=cairo',
			'--pkg=graphene-gobject-1.0',
			vapigen_args,
			files('Cogl-11-custom.vala')
		],
		output: 'mutter-cogl-11.vapi'
	)

	cogl_pango_target = custom_target('mutter-cogl-pango-11',
		command: [
			vapigen,
			mutter_typelib_dir / 'CoglPango-11.gir',
			'--library=mutter-cogl-pango-11',
			'--pkg=mutter-cogl-11',
			'--pkg=pangocairo',
			'--pkg=gio-2.0',
			'--pkg=glib-2.0',
			vapigen_args
		],
		depends: cogl_target,
		output: 'mutter-cogl-pango-11.vapi'
	)

	clutter_target = custom_target('mutter-clutter-11',
		command: [
			vapigen,
			mutter_typelib_dir / 'Clutter-11.gir',
			'--library=mutter-clutter-11',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-11',
			'--pkg=mutter-cogl-pango-11',
			'--pkg=atk',
			'--pkg=gio-2.0',
			'--pkg=json-glib-1.0',
			'--pkg=pangocairo',
			vapigen_args,
			files('Clutter-11-custom.vala')
		],
		depends: [ cogl_target, cogl_pango_target ],
		output: 'mutter-clutter-11.vapi'
	)

	libmutter_target = custom_target('libmutter-11',
		command: [
			vapigen,
			mutter_typelib_dir / 'Meta-11.gir',
			'--library=libmutter-11',
			'--pkg=graphene-gobject-1.0',
			'--pkg=mutter-cogl-11',
			'--pkg=mutter-cogl-pango-11',
			'--pkg=mutter-clutter-11',
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
		output: 'libmutter-11.vapi'
	)
endif

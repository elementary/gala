vapigen_standard_args = [
	'--directory=@0@'.format(meson.current_build_dir()),
	'--metadatadir=@0@'.format(meson.current_source_dir()),
	'--vapidir=@0@'.format(meson.current_build_dir()),
	'--vapidir=@0@'.format(meson.current_source_dir()),
]

vapigen_args = vapigen_standard_args + [
	'--girdir=@0@'.format(mutter_typelib_dir),
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

if gulkan_dep.found ()
	gulkan_girdir = gulkan_dep.get_pkgconfig_variable('prefix', default: get_option('prefix')) / get_option('datadir') / 'gir-1.0'
	gulkan_target = custom_target('gulkan',
		command: [
			vapigen,
			gulkan_girdir / 'Gulkan-0.15.gir',
			'--library=gulkan-0.15',
			'--pkg=gio-2.0',
			'--pkg=gdk-3.0',
			'--pkg=vulkan',
			vapigen_standard_args,
			'--girdir=@0@'.format(gulkan_girdir),
		],
		output: 'gulkan-0.15.vapi'
	)
endif

if gxr_dep.found ()
	gxr_girdir = gxr_dep.get_pkgconfig_variable('prefix', default: get_option('prefix')) / get_option('datadir') / 'gir-1.0'
	gxr_target = custom_target('gxr',
		command: [
			vapigen,
			gxr_girdir / 'Gxr-0.15.gir',
			'--library=gxr-0.15',
			'--pkg=gio-2.0',
			'--pkg=gdk-3.0',
			'--pkg=vulkan',
			'--pkg=gulkan-0.15',
			vapigen_standard_args,
			'--girdir=@0@'.format(gxr_girdir),
		],
		output: 'gxr-0.15.vapi'
	)
endif

if xrdesktop_dep.found()
	xrdesktop_girdir = xrdesktop_dep.get_pkgconfig_variable('prefix', default: get_option('prefix')) / get_option('datadir') / 'gir-1.0'
	xrdesktop_target = custom_target('xrdesktop',
		command: [
			vapigen,
			xrdesktop_girdir / 'Xrd-0.15.gir',
			'--library=xrdesktop-0.15',
			'--pkg=gio-2.0',
			'--pkg=gdk-3.0',
			'--pkg=vulkan',
			'--pkg=gulkan-0.15',
			'--pkg=gxr-0.15',
			vapigen_standard_args,
			'--girdir=@0@'.format(xrdesktop_girdir),
		],
		output: 'xrdesktop-0.15.vapi'
	)
endif

if libinputsynth_dep.found ()
	libinputsynth_target = custom_target('libinputsynth',
		command: [
			vapigen,
			'libinputsynth-0.15.gir',
			'--library=libinputsynth-0.15',
			vapigen_standard_args
		],
		output: 'libinputsynth-0.15.vapi'
	)
endif

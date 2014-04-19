include $(top_srcdir)/Makefile.common

VAPIDIR = $(top_srcdir)/vapi

BUILT_SOURCES = \
	libgala_la_vala.stamp \
	$(NULL)

libgala_la_LTLIBRARIES = libgala.la

libgala_ladir = $(pkglibdir)

libgala_la_CFLAGS = \
	$(GALA_CORE_CFLAGS) \
	-include config.h \
	-w \
	$(NULL)

libgala_la_LDFLAGS = \
	-avoid-version \
	$(GALA_CORE_LDFLAGS) \
	$(NULL)

libgala_la_VALAFLAGS = \
	$(GALA_CORE_VALAFLAGS) \
	--vapidir $(VAPIDIR) \
	$(VAPIDIR)/config.vapi \
	$(NULL)

libgala_la_LIBADD = \
	$(GALA_CORE_LIBS) \
	$(NULL)

libgala_la_VALASOURCES = \
	Plugin.vala \
	Utils.vala \
	WindowManager.vala \
	$(NULL)

nodist_libgala_la_SOURCES = \
	$(BUILT_SOURCES) \
	$(libgala_la_VALASOURCES:.vala=.c) \
	$(NULL)

libgala_la_vala.stamp: $(libgala_la_VALASOURCES)
	$(AM_V_VALA)$(VALAC) \
		$(libgala_la_VALAFLAGS) \
		--basedir $(srcdir) \
		--directory $(builddir) \
		-C \
		-H gala.h \
		--vapi gala.vapi \
		--library gala \
		$(filter %.vala %.c,$^)
	$(AM_V_at)touch $@

CLEANFILES = \
	$(nodist_libgala_la_SOURCES) \
	gala.vapi \
	gala.h \
	$(NULL)

EXTRA_DIST = \
	$(libgala_la_VALASOURCES) \
	$(NULL)


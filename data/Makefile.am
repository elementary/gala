SUBDIRS = \
	icons \
	$(NULL)

stylesdir = $(pkgdatadir)
styles_DATA = gala.css texture.png close.png

applicationsdir = $(datadir)/applications
applications_DATA = gala.desktop gala-multitaskingview.desktop

@INTLTOOL_DESKTOP_RULE@

gsettings_SCHEMAS = org.pantheon.desktop.gala.gschema.xml

@INTLTOOL_XML_RULE@

@GSETTINGS_RULES@

gschemas.compiled: Makefile $(gsettings_SCHEMAS:.xml=.valid)
	$(AM_V_GEN) $(GLIB_COMPILE_SCHEMAS) --targetdir=$(builddir) $(builddir)

all-local: gschemas.compiled

EXTRA_DIST = \
	gala.css \
	gala.desktop \
	gala-multitaskingview.desktop.in \
	texture.png \
	close.png \
	org.pantheon.desktop.gala.gschema.xml.in.in \
	$(NULL)

CLEANFILES = \
	gala-multitaskingview.desktop \
	gschemas.compiled \
	org.pantheon.desktop.gala.gschema.xml \
	org.pantheon.desktop.gala.gschema.xml.in \
	$(NULL)


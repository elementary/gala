stylesdir = $(pkgdatadir)
styles_DATA = gala.css texture.png

applicationsdir = $(datadir)/applications
applications_DATA = gala.desktop

gsettings_SCHEMAS = org.pantheon.desktop.gala.gschema.xml

%.gschema.xml.in: %.gschema.xml.in.in Makefile
	$(AM_V_GEN) sed -e 's|@GETTEXT_PACKAGE[@]|$(GETTEXT_PACKAGE)|g' $< > $@ || rm $@

@INTLTOOL_XML_RULE@

@GSETTINGS_RULES@

gschemas.compiled: Makefile $(gsettings_SCHEMAS:.xml=.valid)
	$(AM_V_GEN) $(GLIB_COMPILE_SCHEMAS) --targetdir=$(builddir) $(builddir)

all-local: gschemas.compiled

EXTRA_DIST = \
	gala.css \
	gala.desktop \
	texture.png \
	org.pantheon.desktop.gala.gschema.xml.in.in \
	$(NULL)

CLEANFILES = \
	$(applications_DATA) \
	$(styles_DATA) \
	$(gsettings_SCHEMAS) \
	gschemas.compiled \
	data/org.pantheon.desktop.gala.gschema.xml \
	data/org.pantheon.desktop.gala.gschema.xml.in \
	$(NULL)


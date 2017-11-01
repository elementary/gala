# Gala
[![l10n](https://l10n.elementary.io/widgets/desktop/gala/svg-badge.svg)](https://l10n.elementary.io/projects/desktop/gala)

A window & compositing manager based on libmutter and designed by elementary for use with Pantheon.

## Building, Testing, and Installation

You'll need the following dependencies:
* automake
* autopoint
* gettext (>= 0.19.6)
* gnome-settings-daemon-dev (>= 3.15.2),
* gsettings-desktop-schemas-dev
* libbamf3-dev
* libcanberra-dev
* libcanberra-gtk3-dev
* libclutter-1.0-dev (>= 1.12.0)
* libgee-0.8-dev
* libglib2.0-dev (>= 2.44)
* libgnome-desktop-3-dev
* libgranite-dev
* libgtk-3-dev (>= 3.4.0)
* libmutter-0-dev (>= 3.23.90) | libmutter-dev (>= 3.14.4)
* libplank-dev (>= 0.10.9)
* libtool
* libxml2-utils
* valac (>= 0.28.0)

Run `autogen.sh` to configure the build environment and then `make` to build

    ./autogen.sh --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu/
    make

To install, use `make install`, then execute with `gala --replace`

    sudo make install
    gala --replace

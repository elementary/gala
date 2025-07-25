# Gala
[![Translation status](https://l10n.elementary.io/widgets/desktop/-/gala/svg-badge.svg)](https://l10n.elementary.io/engage/desktop/?utm_source=widget)

A window & compositing manager based on libmutter and designed by elementary for use with Pantheon.

## Building, Testing, and Installation

You'll need the following dependencies:
* gettext (>= 0.19.6)
* gsettings-desktop-schemas-dev
* libcanberra-dev
* libclutter-1.0-dev (>= 1.12.0)
* libgee-0.8-dev
* libglib2.0-dev (>= 2.74)
* libgnome-desktop-3-dev
* libgranite-dev (>= 5.4.0)
* libgtk-3-dev (>= 3.10.0)
* libmutter-10-dev (>= 42.0) | libmutter-dev (>= 3.18.3)
* meson (>= 0.59.0)
* valac (>= 0.46.0)

Run `meson build` to configure the build environment. Change to the build directory and run `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

You can set the `documentation` option to `true` to build the documentation. In the build directory, use `meson configure`

    meson configure -Ddocumentation=true

To install, use `ninja install`, then execute with `gala --replace`

    sudo ninja install
    gala --replace

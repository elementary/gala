# Gala
[![Translation status](https://l10n.elementary.io/widgets/desktop/-/gala/svg-badge.svg)](https://l10n.elementary.io/engage/desktop/?utm_source=widget)

A window & compositing manager based on libmutter and designed by elementary for use with Pantheon.

## Building, Testing, and Installation

You'll need the following dependencies:
* gettext (>= 0.19.6)
* gsettings-desktop-schemas-dev
* libclutter-1.0-dev (>= 1.12.0)
* libgee-0.8-dev
* libglib2.0-dev (>= 2.74)
* libgnome-desktop-4-dev
* libgnome-bg-4-dev
* libgranite-dev (>= 5.4.0)
* libgranite-7-dev
* libgtk-3-dev
* libgtk-4-dev
* libmutter-10-dev (>= 42.0) | libmutter-dev (>= 3.18.3)
* meson (>= 0.59.0)
* valac (>= 0.46.0)
* libsqlite3-dev
* libhandy-1-dev

Run `meson build` to configure the build environment. Change to the build directory and run `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

You can set the `documentation` option to `true` to build the documentation. In the build directory, use `meson configure`

    meson configure -Ddocumentation=true

To install, run `ninja install`, then based on your session type do the following:

- **Wayland**: Log out and log back in (or reboot) to start the newly installed Gala. (`gala --replace` is not supported for an already running Wayland session.)
- **X11**: run `gala --replace` to replace the running Gala.

### Running the tests

First make sure you include the tests in your build. In the build directory, use `meson configure`

    meson configure -Dtests=true

To run the tests you have to be a user (so no `sudo`). In order for the test environment
to be somewhat isolated and not clash with your running mutter based compositor use
`dbus-run-session`. In the build directory run

    dbus-run-session -- meson test

In order to run the tests even while another compositor is running the test environment
uses `wayland-1` instead of the default `wayland-0` as the name for the wayland display
so you have to make sure that no other running compositor uses that.

In order to debug the tests you can take a look at the log file where the output of
the test goes. meson tells you where it is located when you run the tests.

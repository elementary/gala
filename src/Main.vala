//
//  Copyright (C) 2012 Tom Beckmann, Rico Tzschichholz
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Gala {
    private const OptionEntry[] OPTIONS = {
        { "version", 0, OptionFlags.NO_ARG, OptionArg.CALLBACK, (void*) print_version, "Print version", null },
        { null }
    };

    private void print_version () {
        stdout.printf ("Gala %s\n", Config.VERSION);
        Meta.exit (Meta.ExitCode.SUCCESS);
    }

    public static int main (string[] args) {
        GLib.Intl.setlocale (LocaleCategory.ALL, "");
        GLib.Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
        GLib.Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
        GLib.Intl.textdomain (Config.GETTEXT_PACKAGE);

        var ctx = new Meta.Context ("Mutter(Gala)");
        ctx.add_option_entries (Gala.OPTIONS, Config.GETTEXT_PACKAGE);
        try {
            ctx.configure (ref args);
        } catch (Error e) {
            stderr.printf ("Error initializing: %s\n", e.message);
            return Posix.EXIT_FAILURE;
        }

        /* Intercept signals */
        ctx.set_plugin_gtype (typeof (WindowManagerGala));
        Posix.sigset_t empty_mask;
        Posix.sigemptyset (out empty_mask);
        Posix.sigaction_t act = {};
        act.sa_handler = Posix.SIG_IGN;
        act.sa_mask = empty_mask;
        act.sa_flags = 0;

        if (Posix.sigaction (Posix.Signal.PIPE, act, null) < 0) {
            warning ("Failed to register SIGPIPE handler: %s", GLib.strerror (GLib.errno));
        }

        if (Posix.sigaction (Posix.Signal.XFSZ, act, null) < 0) {
            warning ("Failed to register SIGXFSZ handler: %s", GLib.strerror (GLib.errno));
        }

        GLib.Unix.signal_add (Posix.Signal.TERM, () => {
            ctx.terminate ();
            return GLib.Source.REMOVE;
        });

        try {
            ctx.setup ();
        } catch (Error e) {
            stderr.printf ("Failed to setup: %s\n", e.message);
            return Posix.EXIT_FAILURE;
        }

        // Force initialization of static fields in Utils class
        // https://gitlab.gnome.org/GNOME/vala/-/issues/11
        typeof (Gala.Utils).class_ref ();

        try {
            ctx.start ();
            if (ctx.get_compositor_type () == Meta.CompositorType.WAYLAND) {
                Gala.init_pantheon_shell (ctx);
            }
        } catch (Error e) {
            stderr.printf ("Failed to start: %s\n", e.message);
            return Posix.EXIT_FAILURE;
        }

        try {
            ctx.run_main_loop ();
        } catch (Error e) {
            stderr.printf ("Gala terminated with a failure: %s\n", e.message);
            return Posix.EXIT_FAILURE;
        }

        return Posix.EXIT_SUCCESS;
    }
}

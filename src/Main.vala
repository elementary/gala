/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *                         2012 Tom Beckmann
 *                         2012 Rico Tzschichholz
 */

namespace Gala {
    private const int SCHED_RESET_ON_FORK = 0x40000000;

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

        var param = Posix.Sched.Param () {
            sched_priority = Posix.Sched.get_priority_min (Posix.Sched.Algorithm.RR)
        };

        var retval = Posix.Sched.setscheduler (0, Posix.Sched.Algorithm.RR | SCHED_RESET_ON_FORK, ref param);
        if (retval != 0) {
            warning ("Failed to set RT scheduler.");
        }

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

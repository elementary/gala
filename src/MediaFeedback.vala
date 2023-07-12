/*
 * Copyright 2016 Rico Tzschichholz
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

[DBus (name = "io.elementary.wingpanel.sound")]
public interface Gala.WingpanelSound : GLib.Object {
    public abstract void volume_up () throws DBusError, IOError;

    public abstract void volume_down () throws DBusError, IOError;

    public abstract void mute () throws DBusError, IOError;
}

public class Gala.MediaFeedback : GLib.Object {
    public static WindowManager wm;
    private static MediaFeedback instance;
    private static WingpanelSound wingpanel_sound;

    public static unowned MediaFeedback init (WindowManager _wm) {
        if (instance == null) {
            wm = _wm;
            instance = new MediaFeedback ();
        }

        return instance;
    }

    construct {
        try {
            Bus.watch_name (BusType.SESSION, "io.elementary.wingpanel.sound", BusNameWatcherFlags.NONE, on_watch, on_unwatch);
        } catch (IOError e) {
            warning (e.message);
        }

        unowned var display = wm.get_display ();
        var keybindings_settings = new GLib.Settings ("org.pantheon.desktop.gala.keybindings");

        display.add_keybinding ("volume-up", keybindings_settings, NONE, () => {
            try {
                wingpanel_sound.volume_up ();
            } catch (Error e) {
                warning (e.message);
            }
        });
        display.add_keybinding ("volume-down", keybindings_settings, NONE, () => {
            try {
                wingpanel_sound.volume_down ();
            } catch (Error e) {
                warning (e.message);
            }
        });
        display.add_keybinding ("volume-mute", keybindings_settings, NONE, () => {
            try {
                wingpanel_sound.mute ();
            } catch (Error e) {
                warning (e.message);
            }
        });
    }

    private void on_watch (DBusConnection connection) {
        connection.get_proxy.begin<WingpanelSound> ("io.elementary.wingpanel.sound",
            "/io/elementary/wingpanel/sound", DBusProxyFlags.NONE, null, (obj, res) => {
            try {
                wingpanel_sound = ((DBusConnection) obj).get_proxy.end<WingpanelSound> (res);
            } catch (Error e) {
                warning (e.message);
                wingpanel_sound = null;
            }
        });
    }

    private void on_unwatch (DBusConnection conn) {
        wingpanel_sound = null;
    }
}

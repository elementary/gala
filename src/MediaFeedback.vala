//
//  Copyright (C) 2016 Rico Tzschichholz
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
        warning ("CONSTRUCT");
        try {
            Bus.watch_name (BusType.SESSION, "io.elementary.wingpanel.sound", BusNameWatcherFlags.NONE, on_watch, on_unwatch);
        } catch (IOError e) {
            warning (e.message);
        }

        unowned var display = wm.get_display ();
        var keybindings_settings = new GLib.Settings ("org.pantheon.desktop.gala.keybindings");

        display.add_keybinding ("volume-up", keybindings_settings, NONE, (Meta.KeyHandlerFunc) wingpanel_sound.volume_up);
        display.add_keybinding ("volume-down", keybindings_settings, NONE, (Meta.KeyHandlerFunc) wingpanel_sound.volume_down);
        display.add_keybinding ("volume-mute", keybindings_settings, NONE, (Meta.KeyHandlerFunc) wingpanel_sound.mute);
    }

    private void on_watch (DBusConnection connection) {
        warning ("wathing");
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
        warning ("Unwatch");
        wingpanel_sound = null;
    }
}

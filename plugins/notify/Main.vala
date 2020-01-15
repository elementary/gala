//
//  Copyright (C) 2014 Tom Beckmann
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

using Clutter;
using Meta;

namespace Gala.Plugins.Notify {
    public class Main : Gala.Plugin {
        private GLib.Settings behavior_settings;
        Gala.WindowManager? wm = null;

        NotifyServer server;
        NotificationStack stack;

        uint owner_id = 0U;

        public override void initialize (Gala.WindowManager wm) {
            behavior_settings = new GLib.Settings ("org.pantheon.desktop.gala.behavior");

            this.wm = wm;
#if HAS_MUTTER330
            unowned Meta.Display display = wm.get_display ();
#else
            var screen = wm.get_screen ();
#endif

#if HAS_MUTTER330
            stack = new NotificationStack (display);
#else
            stack = new NotificationStack (screen);
#endif
            stack.animations_changed.connect ((running) => {
                freeze_track = running;
            });

#if HAS_MUTTER330
            Meta.MonitorManager.@get ().monitors_changed_internal.connect (update_position);
            display.workareas_changed.connect (update_position);
#else
            screen.monitors_changed.connect (update_position);
            screen.workareas_changed.connect (update_position);
#endif

            server = new NotifyServer (stack);

            if (!behavior_settings.get_boolean ("use-new-notifications")) {
                enable ();
            }

            behavior_settings.changed["use-new-notifications"].connect (() => {
                if (!behavior_settings.get_boolean ("use-new-notifications")) {
                    enable ();
                } else {
                    disable ();
                }
            });
        }

        void enable ()
        {
            if (owner_id != 0U) {
                return;
            }

            wm.ui_group.add_child (stack);
            track_actor (stack);

            update_position ();

            owner_id = Bus.own_name (BusType.SESSION, "org.freedesktop.Notifications", BusNameOwnerFlags.REPLACE,
                (connection) => {
                    try {
                        connection.register_object ("/org/freedesktop/Notifications", server);
                    } catch (Error e) {
                        warning ("Registring notification server failed: %s", e.message);
                        destroy ();
                    }
                },
                () => {},
                (con, name) => {
                    warning ("Could not aquire bus %s", name);
                    destroy ();
                });
        }

        void disable () {
            if (owner_id == 0U) {
                return;
            }

            Bus.unown_name (owner_id);

            untrack_actor (stack);
            wm.ui_group.remove_child (stack);

            owner_id = 0U;
        }

        void update_position () {
#if HAS_MUTTER330
            unowned Meta.Display display = wm.get_display ();
            var primary = display.get_primary_monitor ();
            var area = display.get_workspace_manager ().get_active_workspace ().get_work_area_for_monitor (primary);
#else
            var screen = wm.get_screen ();
            var primary = screen.get_primary_monitor ();
            var area = screen.get_active_workspace ().get_work_area_for_monitor (primary);
#endif

            stack.x = area.x + area.width - stack.width;
            stack.y = area.y;
        }

        public override void destroy () {
            if (wm == null)
                return;

            untrack_actor (stack);
            stack.destroy ();
        }
    }
}

public Gala.PluginInfo register_plugin () {
    return Gala.PluginInfo () {
        name = "Notify",
        author = "Gala Developers",
        plugin_type = typeof (Gala.Plugins.Notify.Main),
        provides = Gala.PluginFunction.ADDITION,
        load_priority = Gala.LoadPriority.IMMEDIATE
    };
}

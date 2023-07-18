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

namespace Gala {
    public class BackgroundCache : Object {
        private static BackgroundCache? instance = null;

        public static unowned BackgroundCache get_default () {
            if (instance == null)
                instance = new BackgroundCache ();

            return instance;
        }

        public signal void file_changed (GLib.File file);

        private Gee.HashMap<GLib.File,FileMonitor> file_monitors;
        private Gee.HashMap<string,BackgroundSource> background_sources;

        private Animation animation;

        public BackgroundCache () {
            Object ();
        }

        construct {
            file_monitors = new Gee.HashMap<GLib.File, FileMonitor> ((Gee.HashDataFunc) GLib.File.hash, (Gee.EqualDataFunc) GLib.File.equal);
            background_sources = new Gee.HashMap<string,BackgroundSource> ();
        }

        public void monitor_file (GLib.File file) {
            if (file_monitors.has_key (file))
                return;

            try {
                var monitor = file.monitor (FileMonitorFlags.NONE, null);
                monitor.changed.connect (() => {
                    file_changed (file);
                });

                file_monitors[file] = monitor;
            } catch (Error e) {
                warning ("Failed to monitor %s: %s", file.get_path (), e.message);
            }
        }

        public async Animation get_animation (GLib.File file) {
            if (animation != null && animation.file == file) {
                Idle.add (() => {
                    get_animation.callback ();
                    return false;
                });
                yield;

                return animation;
            }

            var animation = new Animation (file);

            yield animation.load ();

            Idle.add (() => {
                get_animation.callback ();
                return false;
            });
            yield;

            return animation;
        }

        public BackgroundSource get_background_source (Meta.Display display, string settings_schema) {
            var background_source = background_sources[settings_schema];
            if (background_source == null) {
                background_source = new BackgroundSource (display, settings_schema);
                background_source.use_count = 1;
                background_sources[settings_schema] = background_source;
            } else
                background_source.use_count++;

            return background_source;
        }

        public void release_background_source (string settings_schema) {
            if (background_sources.has_key (settings_schema)) {
                var source = background_sources[settings_schema];
                if (--source.use_count == 0) {
                    background_sources.unset (settings_schema);
                    source.destroy ();
                }
            }
        }
    }
}

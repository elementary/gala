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

        public signal void file_changed (string filename);

        private Gee.HashMap<string,FileMonitor> file_monitors;
        private Gee.HashMap<string,BackgroundSource> background_sources;

        private Animation animation;

        public BackgroundCache () {
            Object ();
        }

        construct {
            file_monitors = new Gee.HashMap<string,FileMonitor> ();
            background_sources = new Gee.HashMap<string,BackgroundSource> ();
        }

        public void monitor_file (string filename) {
            if (file_monitors.has_key (filename))
                return;

            var file = File.new_for_path (filename);
            try {
                var monitor = file.monitor (FileMonitorFlags.NONE, null);
                monitor.changed.connect (() => {
                    file_changed (filename);
                });

                file_monitors[filename] = monitor;
            } catch (Error e) {
                warning ("Failed to monitor %s: %s", filename, e.message);
            }
        }

        public async Animation get_animation (string filename) {
            if (animation != null && animation.filename == filename) {
                Idle.add (() => {
                    get_animation.callback ();
                    return false;
                });
                yield;

                return animation;
            }

            var animation = new Animation (filename);

            yield animation.load ();

            Idle.add (() => {
                get_animation.callback ();
                return false;
            });
            yield;

            return animation;
        }
    }
}

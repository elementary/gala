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
    public class SystemBackground : GLib.Object {
        private const Clutter.Color DEFAULT_BACKGROUND_COLOR = { 0x2e, 0x34, 0x36, 0xff };

        static Meta.Background? system_background = null;
        public Meta.BackgroundActor background_actor { get; construct; }

        public SystemBackground (Meta.Display display) {
            Object (background_actor: new Meta.BackgroundActor (display, 0));
        }

        construct {
            File? background_file = null;
            var appearance_settings = new GLib.Settings (Config.SCHEMA + ".appearance");
            var custom_path = appearance_settings.get_string ("workspace-switcher-background");
            if (custom_path != "" && FileUtils.test (custom_path, FileTest.IS_REGULAR)) {
                background_file = GLib.File.new_for_path (custom_path);
            }

            if (system_background == null) {
                system_background = new Meta.Background (background_actor.meta_display);
                system_background.set_color (DEFAULT_BACKGROUND_COLOR);
                if (background_file != null) {
                    system_background.set_file (background_file, GDesktop.BackgroundStyle.WALLPAPER);
                }
            }

            ((Meta.BackgroundContent)background_actor.content).background = system_background;

            if (background_file != null) {
                var cache = Meta.BackgroundImageCache.get_default ();
                var image = cache.load (background_file);
                if (image.is_loaded ()) {
                    image = null;
                } else {
                    ulong handler = 0;
                    handler = image.loaded.connect (() => {
                        image.disconnect (handler);
                        image = null;
                    });
                }
            }
        }

        public static void refresh () {
            // Meta.Background.refresh_all does not refresh backgrounds with the WALLPAPER style.
            // (Last tested with mutter 3.28)
            // As a workaround, re-apply the current color again to force the wallpaper texture
            // to be rendered from scratch.
            if (system_background != null) {
                system_background.set_color (DEFAULT_BACKGROUND_COLOR);
            }
        }
    }
}

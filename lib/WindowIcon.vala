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
    /**
     * Creates a new ClutterTexture with an icon for the window at the given size.
     * This is recommended way to grab an icon for a window as this method will make
     * sure the icon is updated if it becomes available at a later point.
     */
    public class WindowIcon : Clutter.Actor {
        public Meta.Window window { get; construct; }
        public int icon_size { get; construct; }
        public int scale { get; construct; }

        /**
         * If set to true, the SafeWindowClone will destroy itself when the connected
         * window is unmanaged
         */
        public bool destroy_on_unmanaged {
            get {
                return _destroy_on_unmanaged;
            }
            construct set {
                if (_destroy_on_unmanaged == value)
                    return;

                _destroy_on_unmanaged = value;
                if (_destroy_on_unmanaged)
                    window.unmanaged.connect (unmanaged);
                else
                    window.unmanaged.disconnect (unmanaged);
            }
        }

        bool _destroy_on_unmanaged = false;

        /**
         * Creates a new WindowIcon
         *
         * @param window               The window for which to create the icon
         * @param icon_size            The size of the icon in pixels
         * @param scale                The desired scale of the icon
         * @param destroy_on_unmanaged see destroy_on_unmanaged property
         */
        public WindowIcon (Meta.Window window, int icon_size, int scale = 1, bool destroy_on_unmanaged = false) {
            Object (window: window,
                icon_size: icon_size,
                destroy_on_unmanaged: destroy_on_unmanaged,
                scale: scale);
        }

        construct {
            width = icon_size * scale;
            height = icon_size * scale;

            update_texture (true);
        }

        void update_texture (bool initial) {
            var pixbuf = Gala.Utils.get_icon_for_window (window, icon_size, scale);
            try {
                var image = new Clutter.Image ();
                Cogl.PixelFormat pixel_format = (pixbuf.get_has_alpha () ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888);
                image.set_data (pixbuf.get_pixels (), pixel_format, pixbuf.width, pixbuf.height, pixbuf.rowstride);
                set_content (image);
            } catch (Error e) {}
        }

        void unmanaged (Meta.Window window) {
            destroy ();
        }
    }
}

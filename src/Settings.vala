//
//  Copyright (C) 2012 GardenGnome, Rico Tzschichholz, Tom Beckmann
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
    public class ShadowSettings : Granite.Services.Settings {
        public string[] menu { get; set; }
        public string[] normal_focused { get; set; }
        public string[] normal_unfocused { get; set; }
        public string[] dialog_focused { get; set; }
        public string[] dialog_unfocused { get; set; }

        static ShadowSettings? instance = null;

        private ShadowSettings () {
            base (Config.SCHEMA + ".shadows");
        }

        public static unowned ShadowSettings get_default () {
            if (instance == null)
                instance = new ShadowSettings ();

            return instance;
        }

        public Meta.ShadowParams get_shadowparams (string class_name) {
            string[] val;
            get (class_name, out val);

            if (val == null || int.parse (val[0]) < 1)
                return Meta.ShadowParams () {radius = 1, top_fade = 0, x_offset = 0, y_offset = 0, opacity = 0};

            return Meta.ShadowParams () {radius = int.parse (val[0]), top_fade = int.parse (val[1]),
                x_offset = int.parse (val[2]), y_offset = int.parse (val[3]), opacity = (uint8)int.parse (val[4])};
        }
    }
}

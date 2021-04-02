/*
* Copyright 2021 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

namespace Gala.Plugins.XRDesktop {

    public class Main : Gala.Plugin {
        Gala.WindowManager? wm = null;
        Xrd.Client? client = null;

        // This function is called as soon as Gala has started and gives you
        // an instance of the GalaWindowManager class.
        public override void initialize (Gala.WindowManager wm) {
            this.wm = wm;
            this.client = new Xrd.Client ();
        }

        public override void destroy () {
            // here you would destroy actors you added to the stage or remove
            // keybindings
        }
    }
}

public Gala.PluginInfo register_plugin () {
    return {
        "xrdesktop",
        "elementary, Inc. (https://elementary.io)",
        typeof (Gala.Plugins.XRDesktop.Main),
        Gala.PluginFunction.ADDITION,
        Gala.LoadPriority.IMMEDIATE
    };
}

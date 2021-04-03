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

    public class XRWindow: Object {
        public weak Meta.WindowActor? meta_window_actor;
        public bool keep_above_restore;
        public bool keep_below_restore;

        /* The offscreen texture Gala renders into to avoid allocating a
         * new offscreen texture every frame
         */
        public GLES2.GLuint gl_texture;
    }
}
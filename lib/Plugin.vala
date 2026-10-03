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
    public enum PluginFunction {
        ADDITION,
        WINDOW_SWITCHER
    }

    public enum LoadPriority {
        /**
         * Have your plugin loaded immediately once gala has started
         */
        IMMEDIATE,
        /**
         * Allow gala to defer loading your plugin once it got the
         * major part of the initialization done
         */
        DEFERRED
    }

    public struct PluginInfo {
        string name;
        string author;

        /**
         * Type of your plugin class, has to be derived from the Plugin class.
         */
        Type plugin_type;

        /**
         * This property allows you to override default functionality of gala
         * so systems won't be instantiated next to each other. Use
         * PluginFunction.ADDITION if no special component is overridden.
         */
        PluginFunction provides;

        /**
         * Give gala a hint for when to load your plugin. Especially use DEFERRED
         * if you're adding a completely new ui component that's not directly
         * related to the wm.
         */
        LoadPriority load_priority;

        /**
         * You don't have to fill this field, it will be filled by gala with
         * the filename in which your module was found.
         */
        string module_name;
    }

    /**
     * This class has to be implemented by every plugin.
     * Additionally, the plugin module is required to have a register_plugin
     * function which returns a PluginInfo struct.
     * The plugin_type field has to be the type of your plugin class derived
     * from this class.
     */
    public abstract class Plugin : Object {
        /**
         * Emitted when update_region is called. Mainly for internal purposes.
         */
        public signal void region_changed ();

        /**
         * The region indicates an area where mouse events should be sent to
         * the stage, which means your actors, instead of the windows.
         *
         * It is calculated by the system whenever update_region is called.
         * You can influence it with the track_actor function.
         */
        private Mtk.Rectangle[] region;
        public unowned Mtk.Rectangle[] get_region () {
            return region;
        }

        private List<Clutter.Actor> tracked_actors = new List<Clutter.Actor> ();

        /**
         * Once this method is called you can start adding actors to the stage
         * via the window manager instance that is given to you.
         *
         * @param wm The window manager.
         */
        public abstract void initialize (WindowManager wm);

        /**
         * This method is currently not called in the code, however you should
         * still implement it to be compatible whenever we decide to use it.
         * It should make sure that everything your plugin added to the stage
         * is cleaned up.
         */
        public abstract void destroy ();

        /**
         * Listen to changes to the allocation of actor and update the region
         * accordingly. You may add multiple actors, their shapes will be
         * combined when one of them changes.
         *
         * @param actor The actor to be tracked
         */
        public void track_actor (Clutter.Actor actor) {
            tracked_actors.prepend (actor);
            actor.notify["allocation"].connect (update_region);

            update_region ();
        }

        /**
         * Stop listening to allocation changes and remove the actor's
         * allocation from the region array.
         *
         * @param actor The actor to stop listening the changes on
         */
        public void untrack_actor (Clutter.Actor actor) {
            tracked_actors.remove (actor);
            actor.notify["allocation"].disconnect (update_region);
        }

        /**
         * You can call this method to force the system to update the region that
         * is used by the window manager. It will automatically be called when a tracked actor's allocation changes.
         */
        public void update_region () {
            var regions = new Mtk.Rectangle[tracked_actors.length ()];
            var i = 0;

            foreach (var actor in tracked_actors) {
                float x, y, w, h;
                actor.get_transformed_position (out x, out y);
                actor.get_transformed_size (out w, out h);

                regions[i++] = { (int) x, (int) y, (int) w, (int) h };
            }

            region = regions;

            region_changed ();
        }
    }
}

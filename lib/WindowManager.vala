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
    namespace ActionKeys {
        public const string INTERACTIVE_SCREENSHOT_ACTION = "interactive-screenshot-action";
        public const string OVERLAY_ACTION = "overlay-action";
        public const string PANEL_MAIN_MENU_ACTION = "panel-main-menu-action";
        public const string TOGGLE_RECORDING_ACTION = "toggle-recording-action";
    }

    /**
     * Function that should return true if the given shortcut should be blocked.
     */
    public delegate bool KeybindingFilter (Meta.KeyBinding binding);

    /**
     * A minimal class mostly used to identify your call to {@link WindowManager.push_modal} and used
     * to end your modal mode again with {@link WindowManager.pop_modal}
     */
    public class ModalProxy : Object {
        public Clutter.Grab? grab { get; set; }

        private GestureAction[] allowed_actions;

        /**
         * A function which is called whenever a keybinding is pressed. If you supply a custom
         * one you can filter out those that'd you like to be passed through and block all others.
         * Defaults to blocking all.
         * @see KeybindingFilter
         */
        private KeybindingFilter? _keybinding_filter = () => true;
        public unowned KeybindingFilter? get_keybinding_filter () {
            return _keybinding_filter;
        }

        public void set_keybinding_filter (KeybindingFilter? filter) {
            _keybinding_filter = filter;
        }

        public ModalProxy () {
        }

        /**
         * Small utility to allow all keybindings
         */
        public void allow_all_keybindings () {
            _keybinding_filter = null;
        }

        public void allow_actions (GestureAction[] actions) {
            allowed_actions = actions;
        }

        public bool filter_action (GestureAction action) {
            return !(action in allowed_actions);
        }
    }

    public interface WindowManager : Meta.Plugin {
        /**
         * This is the container you'll most likely want to add your component to. It wraps
         * every other container listed in this interface and is a direct child of the stage.
         */
        public abstract Clutter.Actor ui_group { get; protected set; }

        /**
         * The stage of the window manager
         */
        public abstract Clutter.Stage stage { get; protected set; }

        /**
         * A group containing all 'usual' windows
         * @see top_window_group
         */
        public abstract Clutter.Actor window_group { get; protected set; }

        /**
         * The top window group contains special windows that are always placed on top
         * like fullscreen windows.
         */
        public abstract Clutter.Actor top_window_group { get; protected set; }

        /**
         * The background group is a container for the background actors forming the wallpaper
         */
        public abstract Meta.BackgroundGroup background_group { get; protected set; }

        /**
         * Enters the modal mode, which will block keybindings and gestures. See {@link ModalProxy} for
         * how to allow certain gestures and keybindings.
         * If {@link grab} is true all events will be redirected to the given {@link Clutter.Actor}.
         * If {@link grab} is false other actors and shell windows may still receive events.
         * Normal windows will never receive keyboard focus though they will still receive pointer events
         * if {@link grab} is false and their {@link Meta.WindowActor} is visible.
         *
         * @param actor The actor to grab events for
         * @param grab Whether to grab all events onto the actor
         *
         * @return a {@link ModalProxy} which is needed to end the modal mode again and provides some
         *         some basic control on the behavior of the window manager while it is in modal mode.
         */
        public abstract ModalProxy push_modal (Clutter.Actor actor, bool grab);

        /**
         * May exit the modal mode again, unless another component has called {@link push_modal}
         *
         * @param proxy The {@link ModalProxy} received from {@link push_modal}
         */
        public abstract void pop_modal (ModalProxy proxy);

        /**
         * Returns whether the window manager is currently in modal mode.
         * @see push_modal
         */
        public abstract bool is_modal ();

        /**
         * Tests if a given {@link ModalProxy} is valid and may be popped. Should not be necessary
         * to use this function in most cases, but it may be helpful for debugging. Gala catches
         * invalid proxies as well and emits a warning in that case.
         *
         * @param proxy The {@link ModalProxy} to check
         * @return      Returns true if the prox is valid
         */
        public abstract bool modal_proxy_valid (ModalProxy proxy);

        /**
         * Tells the window manager to perform the given action.
         *
         * @param type The type of action to perform
         */
        public abstract void perform_action (ActionType type);

        /**
         * Moves the window to the given workspace.
         *
         * @param window    The window to be moved
         * @param workspace The workspace the window should be moved to
         */
        public abstract void move_window (Meta.Window? window, Meta.Workspace workspace, uint32 timestamp);

        /**
         * Switches to the next workspace in the given direction.
         *
         * @param direction The direction in which to switch
         */
        public abstract void switch_to_next_workspace (Meta.MotionDirection direction, uint32 timestamp);

        /**
         * Gets action command from gsettings and executes it.
         *
         * @param action_key The gsettings key of action. Available keys are stored in ActionKeys
         */
        public abstract void launch_action (string action_key);

        /**
         * Checks whether the action should currently be prohibited.
         * @return true if the action should be prohibited, false otherwise
         */
        public abstract bool filter_action (GestureAction action);

        /**
         * Adds target to the multitasking view and window overview so the target responds to the multitasking view
         * close/open gesture and shortcuts.
         *
         * @param target Target to add to multitasking view and window overview
         */
        public abstract void add_multitasking_view_target (GestureTarget target);
    }
}

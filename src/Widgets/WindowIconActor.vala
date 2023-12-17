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
    /**
     * Private class which is basically just a container for the actual
     * icon and takes care of blending the same icon in different sizes
     * over each other and various animations related to the icons
     */
    public class WindowIconActor : Clutter.Actor {
        public Meta.Window window { get; construct; }
        public WindowManager wm { get; construct; }

        private float cur_icon_scale = 1.0f;
        private float desired_icon_scale = 1.0f;

        private int _icon_size;
        /**
         * The icon size of the WindowIcon. Once set the new icon will be
         * faded over the old one and the actor animates to the new size.
         */
        public int icon_size {
            get {
                return _icon_size;
            }
            private set {
                if (value == _icon_size && cur_icon_scale == desired_icon_scale) {
                    return;
                }

                _icon_size = value;
                cur_icon_scale = desired_icon_scale;

                var scaled_size = InternalUtils.scale_to_int (_icon_size, cur_icon_scale);
                set_size (scaled_size, scaled_size);

                fade_new_icon ();
            }
        }

        private bool _temporary;
        /**
         * Mark the WindowIcon as temporary. Only effect of this is that a pulse
         * animation will be played on the actor. Used while DnDing window thumbs
         * over the group.
         */
        public bool temporary {
            get {
                return _temporary;
            }
            set {
                if (_temporary && !value) {
                    remove_transition ("pulse");
                } else if (!_temporary && value && wm.enable_animations) {
                    var transition = new Clutter.TransitionGroup () {
                        duration = 800,
                        auto_reverse = true,
                        repeat_count = -1,
                        progress_mode = Clutter.AnimationMode.LINEAR
                    };

                    var opacity_transition = new Clutter.PropertyTransition ("opacity");
                    opacity_transition.set_from_value (100);
                    opacity_transition.set_to_value (255);
                    opacity_transition.auto_reverse = true;

                    var scale_x_transition = new Clutter.PropertyTransition ("scale-x");
                    scale_x_transition.set_from_value (0.8);
                    scale_x_transition.set_to_value (1.1);
                    scale_x_transition.auto_reverse = true;

                    var scale_y_transition = new Clutter.PropertyTransition ("scale-y");
                    scale_y_transition.set_from_value (0.8);
                    scale_y_transition.set_to_value (1.1);
                    scale_y_transition.auto_reverse = true;

                    transition.add_transition (opacity_transition);
                    transition.add_transition (scale_x_transition);
                    transition.add_transition (scale_y_transition);

                    add_transition ("pulse", transition);
                }

                _temporary = value;
            }
        }

        private WindowIcon? icon = null;
        private WindowIcon? old_icon = null;

        public WindowIconActor (WindowManager wm, Meta.Window window) {
            Object (wm: wm, window: window);
        }

        construct {
            set_pivot_point (0.5f, 0.5f);

            window.notify["on-all-workspaces"].connect (on_all_workspaces_changed);
        }

        ~WindowIconActor () {
            window.notify["on-all-workspaces"].disconnect (on_all_workspaces_changed);
        }

        private void on_all_workspaces_changed () {
            // we don't display windows that are on all workspaces
            if (window.on_all_workspaces)
                destroy ();
        }

        /**
         * Shortcut to set both position and size of the icon
         *
         * @param x    The x coordinate to which to animate to
         * @param y    The y coordinate to which to animate to
         * @param size The size to which to animate to and display the icon in
         */
        public void place (float x, float y, int size, float scale) {
            desired_icon_scale = scale;
            set_position (x, y);
            icon_size = size;
        }

        /**
         * Fades out the old icon and fades in the new icon
         */
        private void fade_new_icon () {
            var new_icon = new WindowIcon (window, icon_size, (int)Math.round (cur_icon_scale));
            new_icon.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.SIZE, 0));
            new_icon.opacity = 0;

            add_child (new_icon);

            new_icon.save_easing_state ();
            new_icon.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
            new_icon.set_easing_duration (wm.enable_animations ? 500 : 0);
            new_icon.restore_easing_state ();

            if (icon == null) {
                icon = new_icon;
            } else {
                old_icon = icon;
            }

            new_icon.opacity = 255;

            if (old_icon != null) {
                old_icon.opacity = 0;
                var transition = old_icon.get_transition ("opacity");
                if (transition != null) {
                    transition.completed.connect (() => {
                        old_icon.destroy ();
                        old_icon = null;
                    });
                } else {
                    old_icon.destroy ();
                    old_icon = null;
                }
            }

            icon = new_icon;
        }
    }
}

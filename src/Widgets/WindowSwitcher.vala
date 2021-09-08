//  Modified by Aral Balkan [mail@ar.al], 2021
//  Modified by Mark Story [mark@mark-story.com], 2020
//  Modified by Popye [sailor3101@gmail.com], 2017
//
//  Original copyright ⓒ 2014, Tom Beckmann
//  https://github.com/tom95/gala-alternate-alt-tab
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
    public class WindowSwitcher : Clutter.Actor {
        public const int ICON_SIZE = 64;
        public const int WRAPPER_BORDER_RADIUS = 12;
        public const int WRAPPER_PADDING = 12;
        public const string CAPTION_FONT_NAME = "Inter";

        const int MIN_OFFSET = 64;
        const int FIX_TIMEOUT_INTERVAL = 100;

        public bool opened { get; private set; default = false; }

        public Gala.WindowManager? wm { get; construct; }
        Gala.ModalProxy modal_proxy = null;

        private Granite.Settings granite_settings;
        private Clutter.Canvas canvas;
        Clutter.Actor container;
        RoundedActor indicator;
        Clutter.Text caption;

        int modifier_mask;

        WindowIcon? cur_icon = null;

        private int scaling_factor = 1;

        // For some reason, on Odin, the height of the caption loses
        // its padding after the first time the switcher displays. As a
        // workaround, I store the initial value here once we have it.
        float caption_height = -1.0f;

        public WindowSwitcher (Gala.WindowManager wm) {
            Object (wm: wm);
        }

        construct {
            granite_settings = Granite.Settings.get_default ();

            scaling_factor = InternalUtils.get_ui_scaling_factor ();

            canvas = new Clutter.Canvas ();
            set_content (canvas);

            // Carry out the initial draw
            create_components ();

            // Redraw the components if the colour scheme changes.
            granite_settings.notify["prefers-color-scheme"].connect (() => {
                create_components ();
            });

            Meta.MonitorManager.@get ().monitors_changed.connect (() => {
                var cur_scale = InternalUtils.get_ui_scaling_factor ();
                if (cur_scale != scaling_factor) {
                    scaling_factor = cur_scale;
                    create_components ();
                }
            });

            canvas.draw.connect (draw);
        }

        private bool draw (Cairo.Context ctx) {
            Granite.Drawing.BufferSurface buffer;
            buffer = new Granite.Drawing.BufferSurface ((int)this.width, (int)this.height);

            // Set the colours based on the person’s light/dark scheme preference.
            var wrapper_background_color = "#fafafa";

            var rgba = InternalUtils.get_theme_accent_color ();
            var accent_color = new Clutter.Color ();
            accent_color.init (
                (uint8) (rgba.red * 255),
                (uint8) (rgba.green * 255),
                (uint8) (rgba.blue * 255),
                (uint8) (rgba.alpha * 255)
            );

            if (granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK) {
                wrapper_background_color = "#333333";
            }

            var back_color = Clutter.Color.from_string (wrapper_background_color);
            var rect_radius = WRAPPER_BORDER_RADIUS * scaling_factor;

            buffer.context.clip ();
            buffer.context.reset_clip ();

            // draw rect
            Clutter.cairo_set_source_color (buffer.context, back_color);
            Granite.Drawing.Utilities.cairo_rounded_rectangle (buffer.context, 0, 0, (int)this.width, (int)this.height, rect_radius);
            buffer.context.fill ();

            //clear surface to transparent
            ctx.set_operator (Cairo.Operator.SOURCE);
            ctx.set_source_rgba (0, 0, 0, 0);
            ctx.paint ();

            //now paint our buffer on
            ctx.set_source_surface (buffer.surface, 0, 0);
            ctx.paint ();

            return true;
        }

        private void create_components () {
            // We've already been constructed once, start again
            if (container != null) {
                caption_height = -1.0f;
                destroy_all_children ();
            }

            var rgba = InternalUtils.get_theme_accent_color ();
            var accent_color = new Clutter.Color ();
            accent_color.init (
                (uint8) (rgba.red * 255),
                (uint8) (rgba.green * 255),
                (uint8) (rgba.blue * 255),
                (uint8) (rgba.alpha * 255)
            );

            var caption_color = "#2e2e31";

            if (granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK) {
                caption_color = "#fafafa";
            }

            var layout = new Clutter.FlowLayout (Clutter.FlowOrientation.HORIZONTAL);
            container = new Clutter.Actor ();
            container.layout_manager = layout;
            container.reactive = true;
            container.button_press_event.connect (container_mouse_press);
            container.motion_event.connect (container_motion_event);

            indicator = new RoundedActor (accent_color, WRAPPER_BORDER_RADIUS * scaling_factor);

            indicator.margin_left = indicator.margin_top =
                indicator.margin_right = indicator.margin_bottom = 0;
            indicator.set_pivot_point (0.5f, 0.5f);

            caption = new Clutter.Text.full (CAPTION_FONT_NAME, "", Clutter.Color.from_string (caption_color));
            caption.set_pivot_point (0.5f, 0.5f);
            caption.set_ellipsize (Pango.EllipsizeMode.END);
            caption.set_line_alignment (Pango.Alignment.CENTER);

            add_child (indicator);
            add_child (container);
            add_child (caption);
        }

        [CCode (instance_pos = -1)]
        public void handle_switch_windows (
            Meta.Display display, Meta.Window? window,
            Clutter.KeyEvent event, Meta.KeyBinding binding
        ) {
            var workspace = display.get_workspace_manager ().get_active_workspace ();

            // copied from gnome-shell, finds the primary modifier in the mask
            var mask = binding.get_mask ();
            if (mask == 0) {
                modifier_mask = 0;
            } else {
                modifier_mask = 1;
                while (mask > 1) {
                    mask >>= 1;
                    modifier_mask <<= 1;
                }
            }

            if (!opened) {
                var windows_exist = collect_windows (display, workspace);
                if (!windows_exist) {
                    return;
                }

                open_switcher ();
                update_indicator_position (true);
            }

            var binding_name = binding.get_name ();
            var backward = binding_name.has_suffix ("-backward");

            next_window (display, workspace, backward);
        }

        bool collect_windows (Meta.Display display, Meta.Workspace? workspace) {
            var windows = display.get_tab_list (Meta.TabList.NORMAL, workspace);

            if (windows == null) {
                return false;
            }

            var current_window = display.get_tab_current (Meta.TabList.NORMAL, workspace);

            container.width = -1;
            container.destroy_all_children ();

            foreach (var window in windows) {
                var icon = new WindowIcon (window, ICON_SIZE * scaling_factor);
                if (window == current_window) {
                    cur_icon = icon;
                }

                icon.set_pivot_point (0.5f, 0.5f);
                container.add_child (icon);
            }

            return true;
        }

        void open_switcher () {
            var display = wm.get_display ();

            if (container.get_n_children () == 0) {
                Utils.bell (display);
                return;
            }

            if (opened) {
                return;
            }

            indicator.set_easing_duration (200);

            container.margin_left = container.margin_top =
                container.margin_right = container.margin_bottom = (WRAPPER_PADDING * 2 * scaling_factor);

            var l = container.layout_manager as Clutter.FlowLayout;
            l.column_spacing = l.row_spacing = WRAPPER_PADDING * scaling_factor;

            indicator.visible = false;
            indicator.resize (
                (ICON_SIZE + WRAPPER_PADDING * 2) * scaling_factor,
                (ICON_SIZE + WRAPPER_PADDING * 2) * scaling_factor
            );
            caption.visible = false;
            caption.margin_bottom = caption.margin_top = WRAPPER_PADDING * scaling_factor;

            var monitor = display.get_primary_monitor ();
            var geom = display.get_monitor_geometry (monitor);

            float container_width;
            container.get_preferred_width (
                ICON_SIZE * scaling_factor + container.margin_left + container.margin_right,
                null,
                out container_width
            );
            if (container_width + MIN_OFFSET * scaling_factor * 2 > geom.width) {
                container.width = geom.width - MIN_OFFSET * scaling_factor * 2;
            }

            float nat_width, nat_height;
            container.get_preferred_size (null, null, out nat_width, null);

            if (container.get_n_children () == 1) {
                nat_width -= WRAPPER_PADDING * scaling_factor;
            }

            container.get_preferred_size (null, null, null, out nat_height);

            // For some reason, on Odin, the height of the caption loses
            // its padding after the first time the switcher displays. As a
            // workaround, I store the initial value here once we have it
            // and use that correct value on subsequent attempts.
            if (caption_height == -1.0f) {
                caption_height = caption.height;
            }

            opacity = 0;

            set_size ((int) nat_width, (int) (nat_height + caption_height / 2 - container.margin_bottom + WRAPPER_PADDING * 3 * scaling_factor));
            canvas.set_size ((int) nat_width, (int) (nat_height + caption_height / 2 - container.margin_bottom + WRAPPER_PADDING * 3 * scaling_factor));
            canvas.invalidate ();

            set_position (
                geom.x + (geom.width - width) / 2,
                geom.y + (geom.height - height) / 2
            );

            save_easing_state ();
            set_easing_duration (200);
            opacity = 255;
            restore_easing_state ();

            modal_proxy = wm.push_modal ();
            modal_proxy.keybinding_filter = (binding) => {
                // if it's not built-in, we can block it right away
                if (!binding.is_builtin ())
                    return true;

                // otherwise we determine by name if it's meant for us
                var name = binding.get_name ();

                return !(name == "switch-applications" || name == "switch-applications-backward"
                    || name == "switch-windows" || name == "switch-windows-backward");
            };

            opened = true;

            grab_key_focus ();

            // if we did not have the grab before the key was released, close immediately
            if ((get_current_modifiers () & modifier_mask) == 0) {
                close_switcher (wm.get_display ().get_current_time ());
            }
        }

        void close_switcher (uint32 time, bool cancel = false) {
            if (!opened) {
                return;
            }

            wm.pop_modal (modal_proxy);
            opened = false;

            var window = cur_icon.window;
            if (window == null) {
                return;
            }

            if (!cancel) {
                var workspace = window.get_workspace ();
                if (workspace != wm.get_display ().get_workspace_manager ().get_active_workspace ()) {
                    workspace.activate_with_focus (window, time);
                } else {
                    window.activate (time);
                }
            }

            save_easing_state ();
            set_easing_duration (100);
            opacity = 0;
            restore_easing_state ();
        }

        void next_window (Meta.Display display, Meta.Workspace? workspace, bool backward) {
            Clutter.Actor actor;
            var current = cur_icon;

            if (container.get_n_children () == 1) {
                Utils.bell (display);
                return;
            }

            if (!backward) {
                actor = current.get_next_sibling ();
                if (actor == null) {
                    actor = container.get_first_child ();
                }
            } else {
                actor = current.get_previous_sibling ();
                if (actor == null) {
                    actor = container.get_last_child ();
                }
            }

            cur_icon = (WindowIcon) actor;
            update_indicator_position ();
        }

        void update_caption_text () {
            var current_window = cur_icon.window;
            var current_caption = "n/a";
            if (current_window != null) {
                current_caption = current_window.get_title ();
            }
            caption.set_text (current_caption);
            caption.visible = true;

            // Make caption smaller than the wrapper, so it doesn't overflow.
            caption.width = width - WRAPPER_PADDING * 2 * scaling_factor;
            caption.set_position (WRAPPER_PADDING * scaling_factor, height - caption_height / 2 - (WRAPPER_PADDING * scaling_factor * 2));
        }

        void update_indicator_position (bool initial = false) {
            // FIXME there are some troubles with layouting, in some cases we
            //       are here too early, in which case all the children are at
            //       (0|0), so we can easily check for that and come back later
            if (container.get_n_children () > 1
                && container.get_child_at_index (1).allocation.x1 < 1) {

                GLib.Timeout.add (FIX_TIMEOUT_INTERVAL, () => {
                    update_indicator_position (initial);
                    return false;
                }, GLib.Priority.DEFAULT);
                return;
            }

            float x, y;
            cur_icon.allocation.get_origin (out x, out y);

            if (initial) {
                indicator.visible = true;
            }

            // Move the indicator without animating it.
            indicator.save_easing_state ();
            indicator.set_easing_duration (0);
            indicator.x = container.margin_left + (container.get_n_children () > 1 ? x : 0) - (WRAPPER_PADDING * scaling_factor);
            indicator.y = container.margin_top + y - (WRAPPER_PADDING * scaling_factor);
            indicator.restore_easing_state ();
            update_caption_text ();
        }

        public override void key_focus_out () {
            close_switcher (wm.get_display ().get_current_time ());
        }

        bool container_motion_event (Clutter.MotionEvent event) {
            var actor = event.stage.get_actor_at_pos (Clutter.PickMode.ALL, (int)event.x, (int)event.y);
            if (actor == null) {
                return true;
            }

            var selected = actor as WindowIcon;
            if (selected == null) {
                return true;
            }

            if (cur_icon != selected) {
                cur_icon = selected;
                update_indicator_position ();
            }

            return true;
        }

        bool container_mouse_press (Clutter.ButtonEvent event) {
            if (opened && event.button == Gdk.BUTTON_PRIMARY) {
                close_switcher (event.time);
            }

            return true;
        }

        public override bool key_release_event (Clutter.KeyEvent event) {
            if ((get_current_modifiers () & modifier_mask) == 0) {
                close_switcher (event.time);
                return true;
            }

            switch (event.keyval) {
                case Clutter.Key.Escape:
                    close_switcher (event.time, true);
                    return true;
            }

            return false;
        }

        Gdk.ModifierType get_current_modifiers () {
            Gdk.ModifierType modifiers;
            double[] axes = {};
            Gdk.Display.get_default ()
                .get_device_manager ()
                .get_client_pointer ()
                .get_state (Gdk.get_default_root_window (), axes, out modifiers);

            return modifiers;
        }
    }
}

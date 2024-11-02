/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

namespace AnimationsSettings {
    private GLib.Settings? animations_settings;
    private bool enable_animations = true;

    /**
     * Whether animations should be displayed.
     */
    public bool get_enable_animations () {
        if (animations_settings == null) {
            animations_settings = new GLib.Settings ("io.elementary.desktop.wm.animations");
            animations_settings.changed["enable-animations"].connect (() => {
                enable_animations = animations_settings.get_boolean ("enable-animations");
            });

            enable_animations = animations_settings.get_boolean ("enable-animations");
        }

        return enable_animations;
    }

    /**
     * Utility that returns the given duration or 0 if animations are disabled.
     */
    public inline uint get_animation_duration (uint duration) {
        return enable_animations ? duration : 0;
    }
}

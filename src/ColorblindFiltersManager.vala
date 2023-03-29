/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.ColorblindFiltersManager : Object {
    private const string EFFECT_NAME = "colorblindness-filter";

    private static ColorblindFiltersManager instance;
    private static GLib.Settings settings;
    public WindowManager wm { get; construct; }

    public static void init (WindowManager wm) {
        if (instance != null) {
            return;
        }

        instance = new ColorblindFiltersManager (wm);
    }

    private ColorblindFiltersManager (WindowManager wm) {
        Object (wm: wm);
    }

    static construct {
        settings = new GLib.Settings ("io.elementary.desktop.wm.accessibility");
    }

    construct {
        settings.changed["colorblindness-filter"].connect (load_filter);
        load_filter ();
    }

    private void load_filter () {
        // We add effect to the stage because adding effect to ui_group causes glitches
        if (wm.stage.get_effect (EFFECT_NAME) != null) {
            wm.stage.remove_effect_by_name (EFFECT_NAME);
        }

        var filter_variant = settings.get_enum ("colorblindness-filter");
        if (filter_variant != 0) {
            var new_effect = new ColorblindCorrectionEffect (filter_variant);
            wm.stage.add_effect_with_name (EFFECT_NAME, new_effect);
        }
    }
}

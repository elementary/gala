/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.FilterManager : Object {
    private const string TRANSITION_NAME = "strength-transition";

    private static FilterManager instance;
    private static GLib.Settings settings;
    public WindowManager wm { get; construct; }

    public static void init (WindowManager wm) {
        if (instance != null) {
            return;
        }

        instance = new FilterManager (wm);
    }

    private FilterManager (WindowManager wm) {
        Object (wm: wm);
    }

    static construct {
        settings = new GLib.Settings ("io.elementary.desktop.wm.accessibility");
    }

    construct {
        settings.changed["colorblindness-correction-filter"].connect (() => load_colorblindness_filter ());
        settings.changed["colorblindness-correction-filter-strength"].connect (() => load_colorblindness_filter ());
        settings.changed["enable-monochrome-filter"].connect (() => load_monochrome_filter ());
        settings.changed["monochrome-filter-strength"].connect (() => load_monochrome_filter ());

        load_filters ();
    }

    private void load_filters () {
        load_colorblindness_filter (true);
        load_monochrome_filter (true);
    }

    private void load_colorblindness_filter (bool initial = false) {
        if (initial) {
            // When gala launches and there is an effect active, it shouldn't be faded in
            var filter_variant = settings.get_enum ("colorblindness-correction-filter");
            var strength = settings.get_double ("colorblindness-correction-filter-strength");
            if (filter_variant != 0 && strength > 0.0) {
                wm.stage.add_effect_with_name (
                    ColorblindnessCorrectionEffect.EFFECT_NAME,
                    new ColorblindnessCorrectionEffect (filter_variant, strength)
                );
            }
        } else {
            // Fade out applied effects
            foreach (unowned var _effect in wm.stage.get_effects ()) {
                if (_effect.name == ColorblindnessCorrectionEffect.EFFECT_NAME) {
                    warning ("here");
                    var effect = (ColorblindnessCorrectionEffect) _effect;

                    // Since you can't add a transition to an effect
                    // add it to a dummy actor and bind one of its properties to the effect

                    // stop transition (if there is one in progress)
                    if (effect.transition_actor != null) {
                        effect.transition_actor.destroy ();
                    }

                    // create a new transition
                    var transition = new Clutter.PropertyTransition ("scale_x") {
                        duration = 1000, // TODO: Maybe use some constant?
                        progress_mode = Clutter.AnimationMode.EASE_OUT_QUAD,
                        remove_on_complete = true
                    };
                    transition.set_from_value (effect.strength);
                    transition.set_to_value (0.0);

                    // create a transition actor and bind its `scale_x` to effect's `strength`
                    effect.transition_actor = new Clutter.Actor () {
                        visible = false
                    };
                    wm.ui_group.add_child (effect.transition_actor);
                    effect.transition_actor.bind_property ("scale_x", effect, "strength");

                    transition.completed.connect (() => {
                        effect.transition_actor.destroy ();
                        wm.stage.remove_effect (effect);
                        warning ("OMG");
                    });

                    effect.transition_actor.add_transition (TRANSITION_NAME, transition);
                }
            }

            // Apply a new filter
            var filter_variant = settings.get_enum ("colorblindness-correction-filter");
            var strength = settings.get_double ("colorblindness-correction-filter-strength");
            if (filter_variant != 0 && strength > 0.0) {
                var new_effect = new ColorblindnessCorrectionEffect (filter_variant, 0.0);
                wm.stage.add_effect_with_name (ColorblindnessCorrectionEffect.EFFECT_NAME, new_effect);

                // Transition new effect in the same way
                var transition = new Clutter.PropertyTransition ("scale_x") {
                    duration = 1000, // TODO: Maybe use some constant?
                    progress_mode = Clutter.AnimationMode.EASE_OUT_QUAD,
                    remove_on_complete = true
                };
                transition.set_from_value (0.0);
                transition.set_to_value (1.0);

                new_effect.transition_actor = new Clutter.Actor () {
                    visible = false
                };
                wm.ui_group.add_child (new_effect.transition_actor);
                new_effect.transition_actor.bind_property ("scale_x", new_effect, "strength");

                transition.completed.connect (() => {
                    new_effect.transition_actor.destroy ();
                });

                new_effect.transition_actor.add_transition (TRANSITION_NAME, transition);
            }
        }
    }


    private void load_monochrome_filter (bool initial = false) {
        if (initial) {
            // When gala launches and there is an effect active, it shouldn't be faded in
            var enable = settings.get_boolean ("enable-monochrome-filter");
            var strength = settings.get_double ("monochrome-filter-strength");
            if (enable && strength > 0.0) {
                wm.stage.add_effect_with_name (
                    MonochromeEffect.EFFECT_NAME,
                    new MonochromeEffect (strength)
                );
            }
        } else {
            // Fade out applied effects
            foreach (unowned var _effect in wm.stage.get_effects ()) {
                if (_effect is MonochromeEffect) {
                    var effect = (MonochromeEffect) _effect;

                    // Since you can't add a transition to an effect
                    // add it to a dummy actor and bind one of its properties to the effect

                    // stop transition (if there is one in progress)
                    if (effect.transition_actor != null) {
                        effect.transition_actor.destroy ();
                    }

                    // create a new transition
                    var transition = new Clutter.PropertyTransition ("scale_x") {
                        duration = 1000, // TODO: Maybe use some constant?
                        progress_mode = Clutter.AnimationMode.EASE_OUT_QUAD,
                        remove_on_complete = true
                    };
                    transition.set_from_value (effect.strength);
                    transition.set_to_value (0.0);

                    // create a transition actor and bind its `scale_x` to effect's `strength`
                    effect.transition_actor = new Clutter.Actor () {
                        visible = false
                    };
                    wm.ui_group.add_child (effect.transition_actor);
                    effect.transition_actor.bind_property ("scale_x", effect, "strength");

                    transition.completed.connect (() => {
                        effect.transition_actor.destroy ();
                        wm.stage.remove_effect (effect);
                    });

                    effect.transition_actor.add_transition (TRANSITION_NAME, transition);
                }
            }

            // Apply a new filter
            var enable = settings.get_boolean ("enable-monochrome-filter");
            var strength = settings.get_double ("monochrome-filter-strength");
            if (enable && strength > 0.0) {
                warning ("Right here");
                var new_effect = new MonochromeEffect (0.0);
                wm.stage.add_effect_with_name (MonochromeEffect.EFFECT_NAME, new_effect);

                // Transition new effect in the same way
                var transition = new Clutter.PropertyTransition ("scale_x") {
                    duration = 1000, // TODO: Maybe use some constant?
                    progress_mode = Clutter.AnimationMode.EASE_OUT_QUAD,
                    remove_on_complete = true
                };
                transition.set_from_value (0.0);
                transition.set_to_value (1.0);

                new_effect.transition_actor = new Clutter.Actor () {
                    visible = false
                };
                wm.ui_group.add_child (new_effect.transition_actor);
                new_effect.transition_actor.bind_property ("scale_x", new_effect, "strength");

                transition.completed.connect (() => {
                    new_effect.transition_actor.destroy ();
                });

                new_effect.transition_actor.add_transition (TRANSITION_NAME, transition);
            }
        }
    }
}

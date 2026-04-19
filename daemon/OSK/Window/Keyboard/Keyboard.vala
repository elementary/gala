/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.Keyboard : Granite.Bin {
    private const ActionEntry [] ACTIONS = {
        { Key.ACTION_TYPE_KEY_VAL, on_type_key_val, "u" },
        { Key.ACTION_ERASE, on_erase },
        { Key.ACTION_SET_VIEW, on_set_view, "s" },
        { Key.ACTION_LATCH_VIEW, on_latch_view, "s" },
    };

    public ModelManager model_manager { get; construct; }
    public InputManager input_manager { get; construct; }

    private ViewContainer view_container;

    private KeyboardView? current_view;
    /* Can be the same as current_view or a different one if another view is latched */
    private KeyboardView? _active_view;
    private KeyboardView? active_view {
        get { return _active_view; }
        set {
            _active_view = value;

            view_container.view = value?.rows;
        }
    }

    public Keyboard (ModelManager model_manager, InputManager input_manager) {
        Object (model_manager: model_manager, input_manager: input_manager);
    }

    construct {
        view_container = new ViewContainer ();
        child = view_container;
        vexpand = true;

        var action_group = new SimpleActionGroup ();
        action_group.add_action_entries (ACTIONS, this);

        insert_action_group (Key.ACTION_GROUP_PREFIX, action_group);

        model_manager.notify["current-model"].connect (on_current_model_changed);
    }

    private void on_current_model_changed () {
        current_view = model_manager.current_model?.find_default_view ();
        active_view = current_view;
    }

    private void on_type_key_val (SimpleAction action, Variant? param) {
        var keyval = (uint) param.get_uint32 ();

        input_manager.send_keyval (keyval);

        if (active_view != current_view) {
            /* Reset a latched view */
            active_view = current_view;
        }
    }

    private void on_erase () {
        input_manager.erase ();
    }

    private void on_set_view (SimpleAction action, Variant? param) {
        var view_name = param.get_string ();
        var view = model_manager.current_model.get_view_by_name (view_name);

        if (view == null) {
            warning ("Tried to set view to '%s' but no such view exists", view_name);
            return;
        }

        current_view = view;
        active_view = view;
    }

    private void on_latch_view (SimpleAction action, Variant? param) {
        var view_name = param.get_string ();

        var view = model_manager.current_model.get_view_by_name (view_name);

        if (view == null) {
            warning ("Tried to latch view to '%s' but no such view exists", view_name);
            return;
        }

        active_view = view;
    }
}

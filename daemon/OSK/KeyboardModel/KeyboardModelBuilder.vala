/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.KeyboardModelBuilder : Object {
    private KeyboardModel model;
    private ListStore views_store;

    private string? current_view_name;
    private ListStore? current_view_store;
    private bool current_view_is_default = false;

    private ListStore? current_row;

    private double current_key_left_offset = 0.0;
    private double current_key_width = 1.0;
    private double current_key_height = 1.0;
    private string? current_key_detailed_action_name; // Mandatory to set
    private ListStore? current_key_popup_keys;
    private string? current_key_label;
    private Icon? current_key_icon;

    construct {
        views_store = new ListStore (typeof (KeyboardView));
        model = new KeyboardModel (views_store);
    }

    public KeyboardModel end () {
        return model;
    }

    public void begin_view (string name) requires (current_view_name == null && current_view_store == null) {
        current_view_name = name;
        current_view_store = new ListStore (typeof (ListStore));
    }

    public void set_view_default () requires (current_view_name != null && current_view_store != null) {
        current_view_is_default = true;
    }

    public void end_view () requires (current_view_name != null && current_view_store != null) {
        var view = new KeyboardView (current_view_name, current_view_store, current_view_is_default);
        views_store.append (view);


        current_view_name = null;
        current_view_store = null;
        current_view_is_default = false;
    }

    public void begin_row () requires (current_view_store != null && current_row == null) {
        current_row = new ListStore (typeof (Key));
    }

    public void end_row () requires (current_view_store != null && current_row != null) {
        current_view_store.append (current_row);
        current_row = null;
    }

    public void begin_key () requires (current_row != null && current_key_detailed_action_name == null) {
        current_key_popup_keys = new ListStore (typeof (Key));
    }

    public void set_key_left_offset (double left_offset) {
        current_key_left_offset = left_offset;
    }

    public void set_key_width (double width) {
        current_key_width = width;
    }

    public void set_key_height (double height) {
        current_key_height = height;
    }

    public void set_key_val_action (uint val) {
        current_key_detailed_action_name = Action.print_detailed_name (Key.ACTION_PREFIX + Key.ACTION_TYPE_KEY_VAL, new Variant.uint32 (val));
    }

    public void set_erase_action () {
        current_key_detailed_action_name = Action.print_detailed_name (Key.ACTION_PREFIX + Key.ACTION_ERASE, null);
    }

    public void set_latch_view_action (string view_name) {
        current_key_detailed_action_name = Action.print_detailed_name (Key.ACTION_PREFIX + Key.ACTION_LATCH_VIEW, new Variant.string (view_name));
    }

    public void set_set_view_action (string view_name) {
        current_key_detailed_action_name = Action.print_detailed_name (Key.ACTION_PREFIX + Key.ACTION_SET_VIEW, new Variant.string (view_name));
    }

    public void set_key_label (string label) {
        current_key_label = label;
    }

    public void set_key_icon (Icon icon) {
        current_key_icon = icon;
    }

    public void set_key_icon_name (string icon_name) {
        current_key_icon = new ThemedIcon (icon_name);
    }

    public void add_popup_key (string popup_key_string) requires (current_key_popup_keys != null) {
        //  var popup_key = new Key (
        //      1.0f,
        //      1.0f,
        //      ACTION_PREFIX + "popup." + popup_key_string,
        //      null,
        //      popup_key_string,
        //      null
        //  );
        //  current_key_popup_keys.append (popup_key);
    }

    public void end_key () requires (current_row != null) {
        if (current_key_label != null && current_key_icon != null) {
            critical ("A key should have at least an icon or label.");
        }

        var key = new Key (
            current_key_left_offset,
            current_key_width,
            current_key_height,
            current_key_detailed_action_name ?? "none",
            current_key_popup_keys,
            current_key_label,
            current_key_icon
        );
        current_row.append (key);

        current_key_left_offset = 0.0;
        current_key_width = 1.0;
        current_key_height = 1.0;
        current_key_detailed_action_name = null;
        current_key_popup_keys = null;
        current_key_label = null;
        current_key_icon = null;
    }
}

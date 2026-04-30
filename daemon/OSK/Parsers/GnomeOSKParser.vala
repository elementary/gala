/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.GnomeOSKParser : Object {
    private HashTable<string, string> level_modes = new HashTable<string, string> (str_hash, str_equal);

    public async KeyboardModel parse (File file) throws Error {
        var stream = yield file.read_async (Priority.DEFAULT);

        var parser = new Json.Parser ();
        yield parser.load_from_stream_async (stream, null);

        var root = parser.get_root ().get_object ();
        var builder = new KeyboardModelBuilder ();

        var levels = root.get_array_member ("levels");
        parse_levels (levels, builder);

        return builder.end ();
    }

    private void parse_levels (Json.Array json, KeyboardModelBuilder builder) throws Error {
        level_modes.remove_all ();

        for (uint i = 0; i < json.get_length (); i++) {
            var level_node = json.get_object_element (i);
            parse_level (level_node, builder);
        }
    }

    private void parse_level (Json.Object json, KeyboardModelBuilder builder) throws Error {
        var level_name = json.get_string_member ("level");

        /* For GNOME every level has a set mode (locked or latched) but for us every level can be in every mode */
        var level_mode = json.get_string_member ("mode");
        level_modes[level_name] = level_mode;

        builder.begin_view (level_name);

        if (level_mode == "default") {
            builder.set_view_default ();
        }

        var rows = json.get_array_member ("rows");
        for (uint i = 0; i < rows.get_length (); i++) {
            var row_node = rows.get_array_element (i);
            parse_row (row_node, builder);
        }

        builder.end_view ();
    }

    private void parse_row (Json.Array json, KeyboardModelBuilder builder) throws Error {
        builder.begin_row ();

        for (uint i = 0; i < json.get_length (); i++) {
            var key_node = json.get_object_element (i);
            parse_key (key_node, builder);
        }

        builder.end_row ();
    }

    private void parse_key (Json.Object json, KeyboardModelBuilder builder) throws Error {
        builder.begin_key ();

        if (json.has_member ("strings")) {
            var strings = json.get_array_member ("strings");
            for (uint i = 0; i < strings.get_length (); i++) {
                var str = strings.get_string_element (i);

                if (i == 0) {
                    builder.set_key_val_action (Gdk.unicode_to_keyval (str[0]));
                    builder.set_key_label (str);
                } else {
                    builder.add_popup_key (str);
                }
            }
        }

        if (json.has_member ("leftOffset")) {
            builder.set_key_left_offset (json.get_double_member ("leftOffset"));
        }

        if (json.has_member ("width")) {
            builder.set_key_width (json.get_double_member ("width"));
        }

        if (json.has_member ("height")) {
            builder.set_key_height (json.get_double_member ("height"));
        }

        if (json.has_member ("label")) {
            var label = json.get_string_member ("label");
            builder.set_key_label (label);
        }

        if (json.has_member ("iconName")) {
            var icon_name = json.get_string_member ("iconName");
            builder.set_key_icon_name (icon_name);
        }

        if (json.has_member ("keyval")) {
            var keyval = json.get_string_member ("keyval");
            builder.set_key_val_action (0);
            // TODO: This is in hex so convert to uint
        }

        if (json.has_member ("action")) {
            var action = json.get_string_member ("action");
            switch (action) {
                case "delete":
                    builder.set_erase_action ();
                    break;

                case "levelSwitch":
                    var level = json.get_string_member ("level");
                    var level_mode = level_modes[level];

                    switch  (level_mode) {
                        case null:
                            builder.set_set_view_action (level);
                            break;

                        case "latched":
                            builder.set_latch_view_action (level);
                            break;

                        case "default":
                        case "locked":
                            builder.set_set_view_action (level);
                            break;
                    }
                    break;

                case "emoji":
                    // TODO
                    break;

                case "languageMenu":
                    // TODO
                    break;

                case "hide":
                    // TODO
                    break;
            }
        }

        builder.end_key ();
    }
}

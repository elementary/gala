/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.ModelManager : Object {
    public OSKService service { private get; construct; }

    public KeyboardModel? current_model { get; private set; }

    private Settings settings;

    public ModelManager (OSKService service) {
        Object (service: service);
    }

    construct {
        settings = new Settings ("org.gnome.desktop.input-sources");
        settings.changed["current"].connect (update_model);
        settings.changed["sources"].connect (update_model);

        update_model.begin ();
    }

    private async void update_model () {
        var input_sources = settings.get_value ("sources");

        var current_source_index = settings.get_uint ("current");

        var current_source = input_sources.get_child_value (current_source_index);

        string type, id;
        current_source.get ("(ss)", out type, out id);

        var group_name = get_group_name (type, id);

        var eligible_models = get_eligible_models (group_name);

        foreach (var model in eligible_models) {
            warning ("Load keyboard model: %s", model);
            if (yield load_model (model)) {
                return;
            }
        }
    }

    private string get_group_name (string type, string id) {
        return id;
    }

    private string[] get_eligible_models (string current_group_name) {
        switch (service.osk_input_purpose) {
            case DIGITS:
                return { "digits" };
            case NUMBER:
                return { "number" };
            case PHONE:
                return { "phone" };
            case EMAIL:
                return { "email" };
            case URL:
                return { "url" };

            default:
                break;
        }

        string[] groups = { current_group_name };

        if ("+" in current_group_name) {
            try {
                groups += (/\+.*/).replace (current_group_name, current_group_name.length, 0, "");
            } catch (Error e) {
                warning ("Failed to parse group name: %s", e.message);
            }
        }

        groups += "us";

        if (service.osk_input_purpose == TERMINAL) {
            for (int i = 0; i < groups.length; i++) {
                groups[i] += "-extended";
            }
        }

        return groups;
    }

    private async bool load_model (string name) {
        var file = File.new_for_path ("/home/leonhard/Projects/gnome-shell/data/osk-layouts/%s.json".printf (name));
        var parser = new GnomeOSKParser ();

        try {
            current_model = yield parser.parse (file);
            return true;
        } catch (Error e) {
            warning ("Failed to load keyboard model: %s", e.message);
            return false;
        }
    }
}

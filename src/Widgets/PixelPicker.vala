/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2020 elementary, Inc. (https://elementary.io)
 */

public class Gala.PixelPicker : Clutter.Actor {
    public signal void closed ();

    public WindowManager wm { get; construct; }
    public bool cancelled { get; private set; }
    public Graphene.Point point { get; private set; }

    private ModalProxy? modal_proxy;

    public PixelPicker (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        point.init (0, 0);
        visible = true;
        reactive = true;

        int screen_width, screen_height;
        wm.get_display ().get_size (out screen_width, out screen_height);
        width = screen_width;
        height = screen_height;
    }

    public override bool key_press_event (Clutter.Event e) {
        if (e.get_key_symbol () == Clutter.Key.Escape) {
            cancelled = true;
            close ();

            return true;
        }

        return false;
    }

    public override bool button_release_event (Clutter.Event e) {
        if (e.get_button () != Clutter.Button.PRIMARY) {
            return true;
        }

        float x, y;
        e.get_coords (out x, out y);
        point = Graphene.Point () { x = x, y = y };

        hide ();
        close ();

        return true;
    }

    private void close () {
        wm.get_display ().set_cursor (Meta.Cursor.DEFAULT);
        if (modal_proxy != null) {
            wm.pop_modal (modal_proxy);
        }

        closed ();
    }

    public void start_selection () {
        wm.get_display ().set_cursor (Meta.Cursor.CROSSHAIR);
        grab_key_focus ();

        modal_proxy = wm.push_modal (this);
    }
}

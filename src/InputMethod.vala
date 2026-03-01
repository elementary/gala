/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.InputMethod : Clutter.InputMethod {
    public Meta.Display display { private get; construct; }
    public Graphene.Rect cursor_location { get; private set; }

    private IBus.Bus bus;
    private IBus.InputContext context;

    public InputMethod (Meta.Display display) {
        Object (display: display);
    }

    construct {
        bus = new IBus.Bus.async ();
        bus.connected.connect (on_connected);

        if (bus.is_connected ()) {
            on_connected ();
        }
    }

    private void on_connected () {
        bus.create_input_context_async.begin ("gala", -1, null, on_input_context_created);
    }

    private void on_input_context_created (Object? obj, AsyncResult res) {
        try {
            context = bus.create_input_context_async_finish (res);
        } catch (Error e) {
            warning ("Failed to create IBus input context: %s", e.message);
        }

        context.commit_text.connect (on_commit_text);
        context.delete_surrounding_text.connect (on_delete_surrounding_text);
        context.update_preedit_text_with_mode.connect (on_update_preedit_text_with_mode);
        context.show_preedit_text.connect (on_show_preedit_text);
        context.hide_preedit_text.connect (on_hide_preedit_text);
        context.forward_key_event.connect (on_forward_key_event);
    }

    private void on_commit_text (IBus.Text text) {
        commit (text.text);
    }

    private void on_delete_surrounding_text (int offset, uint length) {
        delete_surrounding (offset, length);
    }

    private void on_update_preedit_text_with_mode (IBus.Text text, uint cursor_pos, bool visible, uint mode) {
        set_preedit_text (text.text, cursor_pos, cursor_pos, mode);
    }

    private void on_show_preedit_text () {
        set_preedit_text ("my text", 0, 0, 0);
    }

    private void on_hide_preedit_text () {
        set_preedit_text (null, 0, 0, 0);
    }

    private void on_forward_key_event (uint keyval, uint keycode, uint _modifiers) {
        var modifiers = (IBus.ModifierType) _modifiers;
        var press = !(IBus.ModifierType.RELEASE_MASK in modifiers);
        modifiers &= ~IBus.ModifierType.RELEASE_MASK;

        var time = display.get_current_time ();

        forward_key (keyval, keycode + 8, modifiers & Clutter.ModifierType.MODIFIER_MASK, time, press);
    }

    public override void focus_in (Clutter.InputFocus actor) {
        context.focus_in ();
    }

    public override void focus_out () {
        context.focus_out ();
    }

    public override void reset () {
        context.reset ();
    }

    public override void set_cursor_location (Graphene.Rect rect) {
        context.set_cursor_location ((int) rect.origin.x, (int) rect.origin.y, (int) rect.size.width, (int) rect.size.height);
        cursor_location = rect;
    }

    public override void set_surrounding (string text, uint cursor_index, uint anchor_index) {
        var ibus_text = new IBus.Text.from_string (text);
        context.set_surrounding_text (ibus_text, cursor_index, anchor_index);
    }

    public override bool filter_key_event (Clutter.Event event) {
        var state = (IBus.ModifierType) event.get_state ();

        if (IBus.ModifierType.IGNORED_MASK in state) {
            return false;
        }

        if (event.get_type () == Clutter.EventType.KEY_RELEASE) {
            state |= IBus.ModifierType.RELEASE_MASK;
        }

        context.process_key_event_async.begin (
            event.get_key_symbol (), event.get_key_code () - 8, state, -1, null,
            (obj, res) => {
                try {
                    var handled = context.process_key_event_async_finish (res);
                    notify_key_event (event, handled);
                } catch (Error e) {
                    warning ("Failed to process key event on IM: %s", e.message);
                }
            }
        );

        return true;
    }
}

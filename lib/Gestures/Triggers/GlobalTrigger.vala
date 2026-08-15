/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

/**
 * A trigger that triggers when a globally configured gesture has been recognized.
 * These are the typical three or four finger multi touch gestures configurable in the settings.
 * It enables touchpad and touchscreen backends for the whole stage.
 */
public class Gala.GlobalTrigger : Object, GestureTrigger {
    public GestureAction action { get; construct; }
    public WindowManager wm { get; construct; }

    private Variant? _action_info;
    public Variant? action_info { get { return _action_info; } }

    public GlobalTrigger (GestureAction action, WindowManager wm) {
        Object (action: action, wm: wm);
    }

    internal bool triggers (Gesture gesture) {
        var action = GestureSettings.get_action (gesture, out _action_info);
        return !wm.filter_action (action.to_modal_action ()) && this.action == action;
    }

    internal void enable_backends (GestureController controller) {
        var group = action == MULTITASKING_VIEW || action == SWITCH_WORKSPACE ? TouchpadSwipeBackend.Group.MULTITASKING_VIEW : TouchpadSwipeBackend.Group.NONE;
        controller.enable_backend (ToucheggBackend.get_default ());
        controller.enable_backend (new TouchpadSwipeBackend (wm.stage, group));
#if HAS_MUTTER49
        // On mutter < 49 there is a bug that pinch gestures aren't delivered when over a window so rely on touch egg there
        controller.enable_backend (new TouchpadPinchBackend (wm.stage));
#endif
    }
}

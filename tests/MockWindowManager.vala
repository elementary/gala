/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.MockWindowManager : Meta.Plugin, WindowManager {
    public Clutter.Actor ui_group { get; protected set; }
    public Clutter.Stage stage { get; protected set; }
    public Clutter.Actor window_group { get; protected set; }
    public Clutter.Actor top_window_group { get; protected set; }
    public Meta.BackgroundGroup background_group { get; protected set; }

    public virtual ModalProxy push_modal (Clutter.Actor actor, bool grab) {
        return new ModalProxy ();
    }

    public virtual void pop_modal (ModalProxy proxy) {
    }

    public virtual bool is_modal () {
        return false;
    }

    public virtual bool modal_proxy_valid (ModalProxy proxy) {
        return true;
    }

    public virtual void perform_action (ActionType type) {
    }

    public virtual void move_window (Meta.Window? window, Meta.Workspace workspace, uint32 timestamp) {
    }

    public virtual void switch_to_next_workspace (Meta.MotionDirection direction, uint32 timestamp) {
    }

    public virtual void launch_action (string action_key) {
    }

    public virtual bool filter_action (GestureAction action) {
        return false;
    }
}

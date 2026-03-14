/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.ShellGroup : ActorTarget {
    private HashTable<Meta.WindowActor, ShellWindow> windows;

    construct {
        windows = new HashTable<Meta.WindowActor, ShellWindow> (null, null);

        child_removed.connect (on_child_removed);
    }

    private void on_child_removed (Clutter.Actor actor) requires (
        actor is Meta.WindowActor && ((Meta.WindowActor) actor) in windows
    ) {
        var shell_window = windows.take ((Meta.WindowActor) actor);
        remove_target (shell_window);
    }

    public void add_shell_window (Meta.WindowActor actor, ShellWindow shell_window) {
        windows[actor] = shell_window;

        add_target (shell_window);

        InternalUtils.clutter_actor_reparent (actor, this);
    }

    public void add_transient_window (Meta.WindowActor actor) {
        InternalUtils.clutter_actor_reparent (actor, this);
    }
}

/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

/**
 * An {@link GestureTarget} implementation that derives from a {@link Clutter.Actor}.
 * It will propagate gesture events to all direct descendants that are also {@link ActorTarget}s.
 * If a new child (or target via {@link add_target}) is added, its progress will be synced.
 */
public class Gala.ActorTarget : Clutter.Actor, GestureTarget {
    public Clutter.Actor? actor {
        get {
            return this;
        }
    }

    private HashTable<string, double?> current_progress;
    private Gee.List<GestureTarget> targets;

    construct {
        current_progress = new HashTable<string, double?> (str_hash, str_equal);
        targets = new Gee.ArrayList<GestureTarget> ();

        child_added.connect (on_child_added);
    }

    private void sync_target (GestureTarget target) {
        foreach (var id in current_progress.get_keys ()) {
            target.propagate (UPDATE, id, current_progress[id]);
        }
    }

    public void add_target (GestureTarget target) {
        targets.add (target);
        sync_target (target);
    }

    public void remove_target (GestureTarget target) {
        targets.remove (target);
    }

    public void remove_all_targets () {
        targets.clear ();
    }

    public double get_current_progress (string id) {
        return current_progress[id] ?? 0;
    }

    public virtual void start_progress (string id) {}
    public virtual void update_progress (string id, double progress) {}
    public virtual void commit_progress (string id, double to) {}
    public virtual void end_progress (string id) {}

    public override void propagate (UpdateType update_type, string id, double progress) {
        current_progress[id] = progress;

        switch (update_type) {
            case START:
                start_progress (id);
                break;
            case UPDATE:
                update_progress (id, progress);
                break;
            case COMMIT:
                commit_progress (id, progress);
                break;
            case END:
                end_progress (id);
                break;
        }

        foreach (var target in targets) {
            target.propagate (update_type, id, progress);
        }

        for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
            if (child is ActorTarget) {
                child.propagate (update_type, id, progress);
            }
        }
    }

    private void on_child_added (Clutter.Actor child) {
        if (child is ActorTarget) {
            sync_target ((GestureTarget) child);
        }
    }
}

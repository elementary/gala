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
public class Gala.ActorTarget : Focusable, GestureTarget {
    public bool animating { get { return ongoing_animations > 0; } }

    private double[] current_progress;
    private double[] current_commit;
    private Gee.List<GestureTarget> targets;

    private int ongoing_animations = 0;

    construct {
        current_progress = new double[GestureAction.N_ACTIONS];
        current_commit = new double[GestureAction.N_ACTIONS];
        targets = new Gee.ArrayList<GestureTarget> ();

#if HAS_MUTTER46
        child_added.connect (on_child_added);
#else
        actor_added.connect (on_child_added);
#endif
    }

    private void sync_target (GestureTarget target) {
        for (int action = 0; action < current_progress.length; action++) {
            target.propagate (COMMIT, action, current_commit[action]);
            target.propagate (UPDATE, action, current_progress[action]);
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

    public double get_current_progress (GestureAction action) {
        return current_progress[action];
    }

    public double get_current_commit (GestureAction action) {
        return current_commit[action];
    }

    public virtual void start_progress (GestureAction action) {}
    public virtual void update_progress (GestureAction action, double progress) {}
    public virtual void commit_progress (GestureAction action, double to) {}
    public virtual void end_progress (GestureAction action) {}

    public void propagate (UpdateType update_type, GestureAction action, double progress) {
        if (update_type == COMMIT) {
            current_commit[action] = progress;
        } else {
            current_progress[action] = progress;
        }

        foreach (var target in targets) {
            target.propagate (update_type, action, progress);
        }

        for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
            if (child is ActorTarget) {
                child.propagate (update_type, action, progress);
            }
        }

        switch (update_type) {
            case START:
                ongoing_animations++;
                notify_property ("animating");
                start_progress (action);
                break;
            case UPDATE:
                update_progress (action, progress);
                break;
            case COMMIT:
                commit_progress (action, progress);
                break;
            case END:
                ongoing_animations--;
                notify_property ("animating");
                end_progress (action);
                break;
        }
    }

    private void on_child_added (Clutter.Actor child) {
        if (child is ActorTarget) {
            sync_target ((GestureTarget) child);
        }
    }
}

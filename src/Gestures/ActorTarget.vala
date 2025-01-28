


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

    public void add_target (GestureTarget target) {
        targets.add (target);
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

    public void start (string id) {
        start_progress (id);

        foreach (var target in targets) {
            target.start (id);
        }

        for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
            if (child is ActorTarget) {
                child.start (id);
            }
        }
    }

    public void update (string id, double progress) {
        current_progress[id] = progress;

        update_progress (id, progress);

        foreach (var target in targets) {
            target.update (id, progress);
        }

        for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
            if (child is ActorTarget) {
                child.update (id, progress);
            }
        }
    }

    public void commit (string id, double to) {
        commit_progress (id, to);

        foreach (var target in targets) {
            target.commit (id, to);
        }

        for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
            if (child is ActorTarget) {
                child.commit (id, to);
            }
        }
    }

    public void end (string id) {
        end_progress (id);

        foreach (var target in targets) {
            target.end (id);
        }

        for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
            if (child is ActorTarget) {
                child.end (id);
            }
        }
    }

    private void on_child_added (Clutter.Actor child) {
        foreach (var id in current_progress.get_keys ()) {
            if (child is ActorTarget) {
                child.update (id, current_progress[id]);
            }
        }
    }
}


public class Gala.DesktopWorkspaceClone : Clutter.Actor {
    public unowned DesktopWorkspaceSwitcher switcher { get; construct; }
    public Meta.Workspace workspace { get; construct; }

    public DesktopWorkspaceClone (DesktopWorkspaceSwitcher switcher, Meta.Workspace workspace) {
        Object (switcher: switcher, workspace: workspace);
    }

    construct {
        // insert background clone

        unowned var display = workspace.get_display ();
        var monitor = display.get_primary_monitor ();
        var monitor_geom = display.get_monitor_geometry (monitor);

        width = monitor_geom.width;
        height = monitor_geom.height;

        foreach (var window in workspace.list_windows ()) { //TODO: sort by stacking.
            if (switcher.is_static (window)) {
                continue;
            }

            var window_actor = (Meta.WindowActor) window.get_compositor_private ();

            var clone = new Clutter.Clone (window_actor);
            clone.x = window_actor.x - monitor_geom.x;
            clone.y = window_actor.y - monitor_geom.y;

            add_child (clone);
        }
    }
}

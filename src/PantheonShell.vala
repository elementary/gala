/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * Copyright 2023 Corentin Noël <tintou@noel.tf>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Gala {
#if !HAS_MUTTER45
    [Compact]
    public class FakeMetaWaylandCompositor : GLib.Object {
        // It is the third field and Vala adds a FakeMetaWaylandCompositorPrivate *priv
        public Wl.Display wayland_display;

        [CCode (cname = "meta_context_get_wayland_compositor")]
        public extern static unowned Gala.FakeMetaWaylandCompositor from_context (Meta.Context context);
    }
#endif
    public static inline unowned Wl.Display? get_display_from_context (Meta.Context context) {
#if HAS_MUTTER45
        unowned Meta.WaylandCompositor? compositor = context.get_wayland_compositor ();
        if (compositor == null) {
            return null;
        }

        return (Wl.Display) compositor.get_wayland_display ();
#else
        unowned FakeMetaWaylandCompositor compositor = Gala.FakeMetaWaylandCompositor.from_context (context);
        if (compositor == null) {
            return null;
        }

        return compositor.wayland_display;
#endif
    }

    private static Pantheon.Desktop.ShellInterface wayland_pantheon_shell_interface;
    private static Pantheon.Desktop.PanelInterface wayland_pantheon_panel_interface;
    private static Pantheon.Desktop.WidgetInterface wayland_pantheon_widget_interface;
    private static Pantheon.Desktop.ExtendedBehaviorInterface wayland_pantheon_extended_behavior_interface;
    private static Wl.Global shell_global;

    public void init_pantheon_shell (Meta.Context context) {
        unowned Wl.Display? wl_disp = get_display_from_context (context);
        if (wl_disp == null) {
            debug ("Not running under Wayland, no Pantheon Shell protocol");
            return;
        }

        wayland_pantheon_shell_interface = {
            get_panel,
            get_widget,
            get_extended_behavior,
        };

        wayland_pantheon_panel_interface = {
            destroy_panel_surface,
            set_anchor,
            focus_panel,
            set_size,
            set_hide_mode,
        };

        wayland_pantheon_widget_interface = {
            destroy_widget_surface,
        };

        wayland_pantheon_extended_behavior_interface = {
            destroy_extended_behavior_surface,
            set_keep_above,
            make_centered,
            focus_extended_behavior,
        };

        PanelSurface.quark = GLib.Quark.from_string ("-gala-wayland-panel-surface-data");
        WidgetSurface.quark = GLib.Quark.from_string ("-gala-wayland-widget-surface-data");
        ExtendedBehaviorSurface.quark = GLib.Quark.from_string ("-gala-wayland-extended-behavior-surface-data");

        shell_global = Wl.Global.create (wl_disp, ref Pantheon.Desktop.ShellInterface.iface, 1, (client, version, id) => {
            unowned var resource = client.create_resource (ref Pantheon.Desktop.ShellInterface.iface, (int) version, id);
            resource.set_implementation (&wayland_pantheon_shell_interface, null, (res) => {});
        });
    }

    public class PanelSurface : GLib.Object {
        public static GLib.Quark quark = 0;
        public unowned GLib.Object? wayland_surface;

        public PanelSurface (GLib.Object wayland_surface) {
            this.wayland_surface = wayland_surface;
        }

        ~PanelSurface () {
            if (wayland_surface != null) {
                wayland_surface.steal_qdata<unowned GLib.Object> (quark);
            }
        }

        public void on_wayland_surface_disposed () {
            wayland_surface = null;
        }
    }

    public class WidgetSurface : GLib.Object {
        public static GLib.Quark quark = 0;
        public unowned GLib.Object? wayland_surface;

        public WidgetSurface (GLib.Object wayland_surface) {
            this.wayland_surface = wayland_surface;
        }

        ~WidgetSurface () {
            if (wayland_surface != null) {
                wayland_surface.steal_qdata<unowned GLib.Object> (quark);
            }
        }

        public void on_wayland_surface_disposed () {
            wayland_surface = null;
        }
    }

    public class ExtendedBehaviorSurface : GLib.Object {
        public static GLib.Quark quark = 0;
        public unowned GLib.Object? wayland_surface;

        public ExtendedBehaviorSurface (GLib.Object wayland_surface) {
            this.wayland_surface = wayland_surface;
        }

        ~ExtendedBehaviorSurface () {
            if (wayland_surface != null) {
                wayland_surface.steal_qdata<unowned GLib.Object> (quark);
            }
        }

        public void on_wayland_surface_disposed () {
            wayland_surface = null;
        }
    }

    static void unref_obj_on_destroy (Wl.Resource resource) {
        resource.get_user_data<GLib.Object> ().unref ();
    }

    internal static void get_panel (Wl.Client client, Wl.Resource resource, uint32 output, Wl.Resource surface_resource) {
        unowned GLib.Object? wayland_surface = surface_resource.get_user_data<GLib.Object> ();
        PanelSurface? panel_surface = wayland_surface.get_qdata (PanelSurface.quark);
        if (panel_surface != null) {
            surface_resource.post_error (
                Wl.DisplayError.INVALID_OBJECT,
                "io_elementary_pantheon_shell_v1_interface::get_panel already requested"
            );
            return;
        }

        panel_surface = new PanelSurface (wayland_surface);
        unowned var panel_resource = client.create_resource (
            ref Pantheon.Desktop.PanelInterface.iface,
            resource.get_version (),
            output
        );
        panel_resource.set_implementation (
            &wayland_pantheon_panel_interface,
            panel_surface.ref (),
            unref_obj_on_destroy
        );
        wayland_surface.set_qdata_full (
            PanelSurface.quark,
            panel_surface,
            (GLib.DestroyNotify) PanelSurface.on_wayland_surface_disposed
        );
    }

    internal static void get_widget (Wl.Client client, Wl.Resource resource, uint32 output, Wl.Resource surface_resource) {
        unowned GLib.Object? wayland_surface = surface_resource.get_user_data<GLib.Object> ();
        WidgetSurface? widget_surface = wayland_surface.get_qdata (WidgetSurface.quark);
        if (widget_surface != null) {
            surface_resource.post_error (
                Wl.DisplayError.INVALID_OBJECT,
                "io_elementary_pantheon_shell_v1_interface::get_widget already requested"
            );
            return;
        }

        widget_surface = new WidgetSurface (wayland_surface);
        unowned var widget_resource = client.create_resource (
            ref Pantheon.Desktop.WidgetInterface.iface,
            resource.get_version (),
            output
        );
        widget_resource.set_implementation (
            &wayland_pantheon_widget_interface,
            widget_surface.ref (),
            unref_obj_on_destroy
        );
        wayland_surface.set_qdata_full (
            WidgetSurface.quark,
            widget_surface,
            (GLib.DestroyNotify) WidgetSurface.on_wayland_surface_disposed
        );
    }

    internal static void get_extended_behavior (Wl.Client client, Wl.Resource resource, uint32 output, Wl.Resource surface_resource) {
        unowned GLib.Object? wayland_surface = surface_resource.get_user_data<GLib.Object> ();
        ExtendedBehaviorSurface? eb_surface = wayland_surface.get_qdata (ExtendedBehaviorSurface.quark);
        if (eb_surface != null) {
            surface_resource.post_error (
                Wl.DisplayError.INVALID_OBJECT,
                "io_elementary_pantheon_shell_v1_interface::get_extended_behavior already requested"
            );
            return;
        }

        eb_surface = new ExtendedBehaviorSurface (wayland_surface);
        unowned var eb_resource = client.create_resource (
            ref Pantheon.Desktop.ExtendedBehaviorInterface.iface,
            resource.get_version (),
            output
        );
        eb_resource.set_implementation (
            &wayland_pantheon_extended_behavior_interface,
            eb_surface.ref (),
            unref_obj_on_destroy
        );
        wayland_surface.set_qdata_full (
            ExtendedBehaviorSurface.quark,
            eb_surface,
            (GLib.DestroyNotify) ExtendedBehaviorSurface.on_wayland_surface_disposed
        );
    }

    internal static void set_anchor (Wl.Client client, Wl.Resource resource, [CCode (type = "uint32_t")] Pantheon.Desktop.Anchor anchor) {
        unowned PanelSurface? panel_surface = resource.get_user_data<PanelSurface> ();
        if (panel_surface.wayland_surface == null) {
            warning ("Window tried to set anchor but wayland surface is null.");
            return;
        }

        Meta.Window? window;
        panel_surface.wayland_surface.get ("window", out window, null);
        if (window == null) {
            warning ("Window tried to set anchor but wayland surface had no associated window.");
            return;
        }

        Meta.Side side = TOP;
        switch (anchor) {
            case TOP:
                break;

            case BOTTOM:
                side = BOTTOM;
                break;

            case LEFT:
                side = LEFT;
                break;

            case RIGHT:
                side = RIGHT;
                break;
        }

        ShellClientsManager.get_instance ().set_anchor (window, side);
    }

    internal static void focus_panel (Wl.Client client, Wl.Resource resource) {
        unowned PanelSurface? panel_surface = resource.get_user_data<PanelSurface> ();
        if (panel_surface.wayland_surface == null) {
            warning ("Window tried to focus but wayland surface is null.");
            return;
        }

        focus (panel_surface.wayland_surface);
    }

    internal static void focus_extended_behavior (Wl.Client client, Wl.Resource resource) {
        unowned ExtendedBehaviorSurface? extended_behavior_surface = resource.get_user_data<ExtendedBehaviorSurface> ();
        if (extended_behavior_surface.wayland_surface == null) {
            warning ("Window tried to focus but wayland surface is null.");
            return;
        }

        focus (extended_behavior_surface.wayland_surface);
    }

    internal static void focus (Object wayland_surface) {
        Meta.Window? window;
        wayland_surface.get ("window", out window, null);
        if (window == null) {
            warning ("Window tried to focus but wayland surface had no associated window.");
            return;
        }

        window.focus (window.get_display ().get_current_time ());
    }

    internal static void set_size (Wl.Client client, Wl.Resource resource, int width, int height) {
        unowned PanelSurface? panel_surface = resource.get_user_data<PanelSurface> ();
        if (panel_surface.wayland_surface == null) {
            warning ("Window tried to set size but wayland surface is null.");
            return;
        }

        Meta.Window? window;
        panel_surface.wayland_surface.get ("window", out window, null);
        if (window == null) {
            warning ("Window tried to set size but wayland surface had no associated window.");
            return;
        }

        ShellClientsManager.get_instance ().set_size (window, width, height);
    }

    internal static void set_hide_mode (Wl.Client client, Wl.Resource resource, [CCode (type = "uint32_t")] Pantheon.Desktop.HideMode hide_mode) {
        unowned PanelSurface? panel_surface = resource.get_user_data<PanelSurface> ();
        if (panel_surface.wayland_surface == null) {
            warning ("Window tried to set hide mode but wayland surface is null.");
            return;
        }

        Meta.Window? window;
        panel_surface.wayland_surface.get ("window", out window, null);
        if (window == null) {
            warning ("Window tried to set hide mode but wayland surface had no associated window.");
            return;
        }

        ShellClientsManager.get_instance ().set_hide_mode (window, hide_mode);
    }

    internal static void set_keep_above (Wl.Client client, Wl.Resource resource) {
        unowned ExtendedBehaviorSurface? eb_surface = resource.get_user_data<ExtendedBehaviorSurface> ();
        if (eb_surface.wayland_surface == null) {
            return;
        }

        Meta.Window? window;
        eb_surface.wayland_surface.get ("window", out window, null);
        if (window == null) {
            return;
        }

        window.make_above ();
    }

    internal static void make_centered (Wl.Client client, Wl.Resource resource) {
        unowned ExtendedBehaviorSurface? eb_surface = resource.get_user_data<ExtendedBehaviorSurface> ();
        if (eb_surface.wayland_surface == null) {
            return;
        }

        Meta.Window? window;
        eb_surface.wayland_surface.get ("window", out window, null);
        if (window == null) {
            return;
        }

        ShellClientsManager.get_instance ().make_centered (window);
    }

    internal static void destroy_panel_surface (Wl.Client client, Wl.Resource resource) {
        resource.destroy ();
    }

    internal static void destroy_widget_surface (Wl.Client client, Wl.Resource resource) {
        resource.destroy ();
    }

    internal static void destroy_extended_behavior_surface (Wl.Client client, Wl.Resource resource) {
        resource.destroy ();
    }
}

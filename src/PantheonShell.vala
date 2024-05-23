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
        };

        wayland_pantheon_widget_interface = {
            destroy_widget_surface,
        };

        wayland_pantheon_extended_behavior_interface = {
            destroy_extended_behavior_surface,
            set_keep_above,
        };

        PanelSurface.quark = GLib.Quark.from_string ("-gala-wayland-panel-surface-data");

        shell_global = Wl.Global.create (wl_disp, ref Pantheon.Desktop.ShellInterface.iface, 1, (client, version, id) => {
            // Resources are manually destroyed by the client so we can't keep owned references on them because
            // then vala ends up destroying them twice. So instead just prevent vala from automatically managing them
            Wl.Resource* resource = new Wl.Resource (client, ref Pantheon.Desktop.ShellInterface.iface, (int) version, id);
            resource->set_implementation (&wayland_pantheon_shell_interface, null, (res) => {});
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
            warning ("EXTENDED GETS DESTROYED");
            if (wayland_surface != null) {
                wayland_surface.steal_qdata<unowned GLib.Object> (quark);
            }
        }

        public void on_wayland_surface_disposed () {
            wayland_surface = null;
        }
    }

    private static void unref_obj_on_destroy (Wl.Resource resource) {
        warning ("UNREF");
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
        Wl.Resource* panel_resource = new Wl.Resource (
            client,
            ref Pantheon.Desktop.PanelInterface.iface,
            resource.get_version (),
            output
        );
        panel_resource->set_implementation (
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
        Wl.Resource* widget_resource = new Wl.Resource (
            client,
            ref Pantheon.Desktop.WidgetInterface.iface,
            resource.get_version (),
            output
        );
        widget_resource->set_implementation (
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
        Wl.Resource* eb_resource = new Wl.Resource (
            client,
            ref Pantheon.Desktop.ExtendedBehaviorInterface.iface,
            resource.get_version (),
            output
        );
        eb_resource->set_implementation (
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
            return;
        }

        Meta.Window? window;
        panel_surface.wayland_surface.get ("window", out window, null);
        if (window == null) {
            return;
        }

        // TODO
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

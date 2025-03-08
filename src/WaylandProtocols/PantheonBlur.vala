/*
 * Copyright 2023-2025 elementary, Inc. <https://elementary.io>
 * Copyright 2023 Corentin Noël <tintou@noel.tf>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Gala {
    private static Pantheon.Blur.BlurManagerInterface wayland_pantheon_blur_manager_interface;
    private static Pantheon.Blur.BlurInterface wayland_pantheon_blur_interface;
    private static Wl.Global blur_global;

    public void init_pantheon_blur (Meta.Context context) {
        unowned Wl.Display? wl_disp = get_display_from_context (context);
        if (wl_disp == null) {
            debug ("Not running under Wayland, no Pantheon Blur protocol");
            return;
        }

        wayland_pantheon_blur_manager_interface = {
            get_blur
        };

        wayland_pantheon_blur_interface = {
            destroy_blur_surface,
            (Pantheon.Blur.SetRegion) set_region
        };

        BlurSurface.quark = GLib.Quark.from_string ("-gala-wayland-blur-surface-data");

        blur_global = Wl.Global.create (wl_disp, ref Pantheon.Blur.BlurManagerInterface.iface, 1, (client, version, id) => {
            unowned var resource = client.create_resource (ref Pantheon.Blur.BlurManagerInterface.iface, (int) version, id);
            resource.set_implementation (&wayland_pantheon_blur_manager_interface, null, (res) => {});
        });
    }

    public class BlurSurface : GLib.Object {
        public static GLib.Quark quark = 0;
        public unowned GLib.Object? wayland_surface;

        public BlurSurface (GLib.Object wayland_surface) {
            this.wayland_surface = wayland_surface;
        }

        ~BlurSurface () {
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

    internal static void get_blur (Wl.Client client, Wl.Resource resource, uint32 output, Wl.Resource surface_resource) {
        unowned GLib.Object? wayland_surface = surface_resource.get_user_data<GLib.Object> ();
        BlurSurface? blur_surface = wayland_surface.get_qdata (BlurSurface.quark);
        if (blur_surface != null) {
            surface_resource.post_error (
                Wl.DisplayError.INVALID_OBJECT,
                "io_elementary_pantheon_blur_manager_v1_interface::get_blur already requested"
            );
            return;
        }

        blur_surface = new BlurSurface (wayland_surface);
        unowned var blur_resource = client.create_resource (
            ref Pantheon.Blur.BlurInterface.iface,
            resource.get_version (),
            output
        );
        blur_resource.set_implementation (
            &wayland_pantheon_blur_interface,
            blur_surface.ref (),
            unref_obj_on_destroy
        );
        wayland_surface.set_qdata_full (
            BlurSurface.quark,
            blur_surface,
            (GLib.DestroyNotify) BlurSurface.on_wayland_surface_disposed
        );
    }

    internal static void set_region (Wl.Client client, Wl.Resource resource, uint x, int y, uint width, uint height, uint clip_radius) {
        unowned BlurSurface? blur_surface = resource.get_user_data<BlurSurface> ();
        if (blur_surface.wayland_surface == null) {
            warning ("Window tried to set blur region but wayland surface is null.");
            return;
        }

        Meta.Window? window;
        blur_surface.wayland_surface.get ("window", out window, null);
        if (window == null) {
            warning ("Window tried to set blur region but wayland surface had no associated window.");
            return;
        }

        BlurManager.get_instance ().set_region (window, x, y, width, height, clip_radius);
    }

    internal static void destroy_blur_surface (Wl.Client client, Wl.Resource resource) {
        unowned BlurSurface? blur_surface = resource.get_user_data<BlurSurface> ();

        if (blur_surface.wayland_surface == null) {
            warning ("Window tried to set blur region but wayland surface is null.");
            resource.destroy ();
            return;
        }

        Meta.Window? window;
        blur_surface.wayland_surface.get ("window", out window, null);
        if (window == null) {
            warning ("Window tried to set blur region but wayland surface had no associated window.");
            resource.destroy ();
            return;
        }

        BlurManager.get_instance ().remove_blur (window);
        resource.destroy ();
    }
}

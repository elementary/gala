/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * Copyright 2023 Corentin Noël <tintou@noel.tf>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Pantheon.Desktop {
    [CCode (cheader_filename = "pantheon-desktop-shell-server-protocol.h", cname = "struct io_elementary_pantheon_shell_v1_interface")]
    public struct ShellInterface {
        [CCode (cheader_filename = "pantheon-desktop-shell-server-protocol.h", cname = "io_elementary_pantheon_shell_v1_interface")]
        public static Wl.Interface iface;
        public Pantheon.Desktop.GetPanel get_panel;
        public Pantheon.Desktop.GetWidget get_widget;
        public Pantheon.Desktop.GetExtendedBehavior get_extended_behavior;

    }

    [CCode (cheader_filename = "pantheon-desktop-shell-server-protocol.h", cname = "enum io_elementary_pantheon_panel_v1_anchor", cprefix="IO_ELEMENTARY_PANTHEON_PANEL_V1_ANCHOR_", has_type_id = false)]
    public enum Anchor {
        TOP,
        BOTTOM,
        LEFT,
        RIGHT,
    }

    [CCode (cheader_filename = "pantheon-desktop-shell-server-protocol.h", cname = "enum io_elementary_pantheon_panel_v1_hide_mode", cprefix="IO_ELEMENTARY_PANTHEON_PANEL_V1_HIDE_MODE_", has_type_id = false)]
    public enum HideMode {
        NEVER,
        MAXIMIZED_FOCUS_WINDOW,
        OVERLAPPING_FOCUS_WINDOW,
        OVERLAPPING_WINDOW,
        ALWAYS
    }

    [CCode (cheader_filename = "pantheon-desktop-shell-server-protocol.h", cname = "struct io_elementary_pantheon_panel_v1_interface")]
    public struct PanelInterface {
        [CCode (cheader_filename = "pantheon-desktop-shell-server-protocol.h", cname = "io_elementary_pantheon_panel_v1_interface")]
        public static Wl.Interface iface;
        public Destroy destroy;
        public SetAnchor set_anchor;
        public Focus focus;
        public SetSize set_size;
        public SetHideMode set_hide_mode;
    }

    [CCode (cheader_filename = "pantheon-desktop-shell-server-protocol.h", cname = "struct io_elementary_pantheon_widget_v1_interface")]
    public struct WidgetInterface {
        [CCode (cheader_filename = "pantheon-desktop-shell-server-protocol.h", cname = "io_elementary_pantheon_widget_v1_interface")]
        public static Wl.Interface iface;
        public Destroy destroy;
    }

    [CCode (cheader_filename = "pantheon-desktop-shell-server-protocol.h", cname = "struct io_elementary_pantheon_extended_behavior_v1_interface")]
    public struct ExtendedBehaviorInterface {
        [CCode (cheader_filename = "pantheon-desktop-shell-server-protocol.h", cname = "io_elementary_pantheon_extended_behavior_v1_interface")]
        public static Wl.Interface iface;
        public Destroy destroy;
        public SetKeepAbove set_keep_above;
        public MakeCentered make_centered;
        public Focus focus;
    }

    [CCode (has_target = false, has_typedef = false)]
    public delegate void GetPanel (Wl.Client client, Wl.Resource resource, uint32 output, Wl.Resource surface);
    [CCode (has_target = false, has_typedef = false)]
    public delegate void GetWidget (Wl.Client client, Wl.Resource resource, uint32 output, Wl.Resource surface);
    [CCode (has_target = false, has_typedef = false)]
    public delegate void GetExtendedBehavior (Wl.Client client, Wl.Resource resource, uint32 output, Wl.Resource surface);
    [CCode (has_target = false, has_typedef = false)]
    public delegate void SetAnchor (Wl.Client client, Wl.Resource resource, [CCode (type = "uint32_t")] Anchor anchor);
    [CCode (has_target = false, has_typedef = false)]
    public delegate void Focus (Wl.Client client, Wl.Resource resource);
    [CCode (has_target = false, has_typedef = false)]
    public delegate void SetSize (Wl.Client client, Wl.Resource resource, int width, int height);
    [CCode (has_target = false, has_typedef = false)]
    public delegate void SetHideMode (Wl.Client client, Wl.Resource resource, [CCode (type = "uint32_t")] HideMode hide_mode);
    [CCode (has_target = false, has_typedef = false)]
    public delegate void SetKeepAbove (Wl.Client client, Wl.Resource resource);
    [CCode (has_target = false, has_typedef = false)]
    public delegate void MakeCentered (Wl.Client client, Wl.Resource resource);
    [CCode (has_target = false, has_typedef = false)]
    public delegate void Destroy (Wl.Client client, Wl.Resource resource);
}

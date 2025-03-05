/*
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Pantheon.Blur {
    [CCode (cheader_filename = "pantheon-blur-server-protocol.h", cname = "struct io_elementary_pantheon_blur_manager_v1_interface")]
    public struct BlurManagerInterface {
        [CCode (cheader_filename = "pantheon-blur-server-protocol.h", cname = "io_elementary_pantheon_blur_manager_v1_interface")]
        public static Wl.Interface iface;
        public Pantheon.Blur.Create create;

    }

    [CCode (cheader_filename = "pantheon-blur-server-protocol.h", cname = "struct io_elementary_pantheon_blur_v1_interface")]
    public struct BlurInterface {
        [CCode (cheader_filename = "pantheon-blur-server-protocol.h", cname = "io_elementary_pantheon_blur_v1_interface")]
        public static Wl.Interface iface;
        public Destroy destroy;
        public SetRegion set_region;
    }

    [CCode (has_target = false, has_typedef = false)]
    public delegate void Create (Wl.Client client, Wl.Resource resource, uint32 output, Wl.Resource surface);
    [CCode (has_target = false, has_typedef = false)]
    public delegate void SetRegion (Wl.Client client, Wl.Resource resource, uint x, uint y, uint width, uint height, uint clip_radius);
    [CCode (has_target = false, has_typedef = false)]
    public delegate void Destroy (Wl.Client client, Wl.Resource resource);
}

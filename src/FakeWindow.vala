/*
 * 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Gala {
    public enum MetaTileMode {
        TILE_NONE,
        TILE_LEFT,
        TILE_RIGHT,
        TILE_MAXIMIZED
    }

    [CCode (cname = "meta_window_tile")]
    public extern static void meta_window_tile (Meta.Window window, MetaTileMode tile_mode);

    [CCode (cname = "meta_window_untile")]
    public extern static void meta_window_untile (Meta.Window window);

    [CCode (cname = "meta_window_is_tiled_left")]
    public extern static bool meta_window_is_tiled_left (Meta.Window window);

    [CCode (cname = "meta_window_is_tiled_right")]
    public extern static bool meta_window_is_tiled_right (Meta.Window window);
}

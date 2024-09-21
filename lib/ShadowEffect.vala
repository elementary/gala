/*
 * Copyright 2014 Tom Beckmann
 * Copyright 2023-2024 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public enum Gala.ShadowParamsType {
    DEFAULT,
    WINDOW,
    WORKSPACE,
    WINDOW_SWITCHER
}

public class Gala.ShadowEffect : Clutter.Effect {
    private class ShadowParams {
        public string css_class;
        public Meta.ShadowParams meta_params;

        private int _shadow_spread = -1;
        public int shadow_spread {
            get {
                if (_shadow_spread != -1) {
                    return _shadow_spread;
                }

                if (meta_params.radius == 0) {
                    _shadow_spread = 0;
                }

                var d = (int) (0.5 + meta_params.radius * (0.75 * Math.sqrt (2 * Math.PI)));

                _shadow_spread =  3 * (d / 2);

                if (d % 2 == 0) {
                    _shadow_spread -= 1;
                }

                return _shadow_spread;
            }
        }

        public ShadowParams (string _css_class, Meta.ShadowParams _meta_params) {
            css_class = _css_class;
            meta_params = _meta_params;
        }
    }

    private static ShadowParams[] all_shadow_params = {};

    public ShadowParamsType shadow_param_type { get; construct; }
    public float scale_factor { get; set; default = 1.0f; }
    public float opacity_multiplier { get; set; default = 1.0f; }

    private ShadowParams shadow_params;

    static construct {
        Meta.ShadowParams default_meta_params = { 4, -1, 0, 3, 128 };
        var default_params = new ShadowParams ("default", default_meta_params);

        all_shadow_params += default_params;

        Meta.ShadowParams window_meta_params = { 4, -1, 0, 3, 128 };
        var window_params = new ShadowParams ("window", window_meta_params);

        all_shadow_params += window_params;

        Meta.ShadowParams workspace_meta_params = { 4, -1, 0, 3, 128 };
        var workspace_params = new ShadowParams ("workspace", workspace_meta_params);

        all_shadow_params += workspace_params;

        Meta.ShadowParams window_switcher_meta_params = { 4, -1, 0, 3, 128 };
        var window_switcher_params = new ShadowParams ("window-switcher", window_switcher_meta_params);

        all_shadow_params += window_switcher_params;
    }

    public ShadowEffect (ShadowParamsType shadow_param_type) {
        Object (shadow_param_type: shadow_param_type);
    }

    construct {
        shadow_params = all_shadow_params[shadow_param_type];
    }

    public override void paint (Clutter.PaintNode node, Clutter.PaintContext context, Clutter.EffectPaintFlags flags) {
        var actor_width = (int) actor.width;
        var actor_height = (int) actor.height;

        Mtk.Rectangle rectangle = { 0, 0, actor_width, actor_height };
        var region = Mtk.Region.create_rectangle (rectangle);
        var window_shape = new Meta.WindowShape (region);
    
        // FIXME: obtain shadow only when size or position changes
        unowned var shadow_factory = Meta.ShadowFactory.get_default ();
        var shadow = shadow_factory.get_shadow (window_shape, actor_width, actor_height, shadow_params.css_class, true);

        var opacity = (uint8) ((shadow_params.meta_params.opacity / 255.0f) * (actor.get_paint_opacity () / 255.0f) * opacity_multiplier * 255.0f);

        shadow.paint (context.get_framebuffer (), 0, 0, actor_width, actor_height, opacity, null, false);

        actor.continue_paint (context);
    }

    public virtual Clutter.ActorBox get_bounding_box () {
        var size = shadow_params.shadow_spread * scale_factor;
        var bounding_box = Clutter.ActorBox ();

        bounding_box.set_origin (-size, -size);
        bounding_box.set_size (actor.width + size * 2, actor.height + size * 2);

        return bounding_box;
    }

    public override bool modify_paint_volume (Clutter.PaintVolume volume) {
        var bounding_box = get_bounding_box ();

        volume.set_width (bounding_box.get_width ());
        volume.set_height (bounding_box.get_height ());

        float origin_x, origin_y;
        bounding_box.get_origin (out origin_x, out origin_y);
        var origin = volume.get_origin ();
        origin.x += origin_x;
        origin.y += origin_y;
        volume.set_origin (origin);

        return true;
    }
}

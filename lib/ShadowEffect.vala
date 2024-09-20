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
    //  private Meta.Shadow shadow;

    //  private ShadowParams? shadow_params;

    //  private string _css_class;
    //  public string css_class {
    //      get {
    //          return _css_class;
    //      }

    //      construct set {
    //          _css_class = value;
    //          switch (value) {
    //              case "workspace-switcher":
    //                  shadow_size = 6;
    //                  break;
    //              case "window":
    //                  shadow_size = 55;
    //                  break;
    //              default:
    //                  shadow_size = 18;
    //                  break;
    //          }
    //      }
    //  }

    //  private int shadow_size;

    static construct {
        Meta.ShadowParams default_meta_params = { 0, 0, 0, 4, 100 };
        var default_params = new ShadowParams ("default", default_meta_params);

        all_shadow_params += default_params;

        Meta.ShadowParams window_meta_params = { 0, 200, 0, 4, 100 };
        var window_params = new ShadowParams ("window", window_meta_params);

        all_shadow_params += window_params;

        Meta.ShadowParams workspace_meta_params = { 0, 0, 0, 4, 100 };
        var workspace_params = new ShadowParams ("workspace", workspace_meta_params);

        all_shadow_params += workspace_params;

        Meta.ShadowParams window_switcher_meta_params = { 0, 0, 0, 4, 100 };
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
        var bounding_box = get_bounding_box ();
        var x = (int) bounding_box.x1;
        var y = (int) bounding_box.y1;
        var width = (int) (bounding_box.x2 - bounding_box.x1);
        var height = (int) (bounding_box.y2 - bounding_box.y1);

        Mtk.Rectangle rectangle = { x, y, width, height };
        var region = Mtk.Region.create_rectangle (rectangle);
        var window_shape = new Meta.WindowShape (region);
    
        // FIXME: obtain shadow only when size or position changes
        unowned var shadow_factory = Meta.ShadowFactory.get_default ();
        var shadow = shadow_factory.get_shadow (window_shape, width, height, shadow_params.css_class, true);

        var opacity = (uint8) (shadow_params.meta_params.opacity * actor.opacity / 255.0f);
        shadow.paint (context.get_framebuffer (), 0, 0, width, height, opacity, null, false);

        actor.continue_paint (context);
    }

    public virtual Clutter.ActorBox get_bounding_box () {
        var size = 0 * scale_factor;
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

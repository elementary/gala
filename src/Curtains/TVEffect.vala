/*
 * Copyright 2026 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

public class Gala.TVEffect : Clutter.ShaderEffect {
    private float _occlusion = 0.0f;
    public float occlusion { get {
        return _occlusion;
    } set {
        _occlusion = value;
        set_uniform_value ("OCCLUSION", value);
        queue_repaint ();
    }}

    private float _height = 512.0f;
    public float height { get {
        return _height;
    } set {
        _height = value;
        set_uniform_value ("HEIGHT", value);
        queue_repaint ();
    }}

    public TVEffect (float occlusion = 0.0f) {
        Object (
#if HAS_MUTTER48
            shader_type: Cogl.ShaderType.FRAGMENT,
#else
            shader_type: Clutter.ShaderType.FRAGMENT_SHADER,
#endif
            occlusion: occlusion
        );

        try {
            var bytes = GLib.resources_lookup_data (
                "/io/elementary/desktop/gala/shaders/tv-effect.frag",
                GLib.ResourceLookupFlags.NONE
            );
            set_shader_source ((string) bytes.get_data ());
        } catch (Error e) {
            warning ("Failed to load TV effect shader: %s", e.message);
        }
    }
}

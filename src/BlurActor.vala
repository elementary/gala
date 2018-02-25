//
//  Copyright (C) 2018 Adam Bieńkowski
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

// Original blur algorithm and shaders by Marius Bjørge,
// available on https://community.arm.com/cfs-file/__key/communityserver-blogs-components-weblogfiles/00-00-00-20-66/siggraph2015_2D00_mmg_2D00_marius_2D00_notes.pdf

// Reference implementation by Alex Nemeth for KDE: https://phabricator.kde.org/D9848

namespace Gala
{ 
    class FramebufferContainer
    {
        public Cogl.Offscreen fbo;
        public Cogl.Texture texture;
    
        public FramebufferContainer (Cogl.Texture texture)
        {
            this.texture = texture;
            fbo = new Cogl.Offscreen.to_texture (texture);
        }
    }    

    const string DOWNSAMPLE_FRAG_SHADER = """
        uniform float halfwidth;
        uniform float halfheight;
        uniform sampler2D tex;
        uniform float offset;

        void main () {
            vec2 uv = cogl_tex_coord0_in.xy;
            vec2 halfpixel = vec2(halfwidth, halfheight);

            vec4 sum = texture2D (tex, uv) * 4.0;
            sum += texture2D (tex, uv - halfpixel.xy * offset);
            sum += texture2D (tex, uv + halfpixel.xy * offset);
            sum += texture2D (tex, uv + vec2(halfpixel.x, -halfpixel.y) * offset);
            sum += texture2D (tex, uv - vec2(halfpixel.x, -halfpixel.y) * offset);
            cogl_color_out = sum / 8.0;
        }
    """;

    const string UPSAMPLE_FRAG_SHADER = """
        uniform float halfwidth;
        uniform float halfheight;
        uniform sampler2D tex;
        uniform float offset;

        void main () {
            vec2 uv = cogl_tex_coord0_in.xy;
            vec2 halfpixel = vec2(halfwidth, halfheight);

            vec4 sum = texture2D (tex, uv + vec2(-halfpixel.x * 2.0, 0.0) * offset);
            sum += texture2D (tex, uv + vec2(-halfpixel.x, halfpixel.y) * offset) * 2.0;
            sum += texture2D (tex, uv + vec2(0.0, halfpixel.y * 2.0) * offset);
            sum += texture2D (tex, uv + vec2(halfpixel.x, halfpixel.y) * offset) * 2.0;
            sum += texture2D (tex, uv + vec2(halfpixel.x * 2.0, 0.0) * offset);
            sum += texture2D (tex, uv + vec2(halfpixel.x, -halfpixel.y) * offset) * 2.0;
            sum += texture2D (tex, uv + vec2(0.0, -halfpixel.y * 2.0) * offset);
            sum += texture2D (tex, uv + vec2(-halfpixel.x, -halfpixel.y) * offset) * 2.0;

            cogl_color_out = sum / 12.0;
        }
    """;

    public class BlurActor : Clutter.Actor
    {
        static int down_width_location;
        static int down_height_location;
    
        static int up_width_location;
        static int up_height_location;
    
        static Cogl.Program down_program;
        static Cogl.Program up_program;
    
        static int down_offset_location;
        static int up_offset_location;
        static int down_scale_location;

        static GlCopyTexSubFunc? copy_tex_sub_image;
        static GlBindTextureFunc? bind_texture;

        delegate void GlCopyTexSubFunc (uint target, int level,
                                        int xoff, int yoff,
                                        int x, int y,
                                        int width, int height);
        delegate void GlBindTextureFunc (uint target, uint texture);

        public int iterations { get; construct; }
        public int expand_size { get; construct; }

        public Meta.WindowActor? window_actor { get; construct; }
        public unowned Clutter.Actor ui_group { get; construct; }

        Meta.Window? window;

        float stage_width;
        float stage_height;

        int tex_height;

        Cogl.Material material;
        Cogl.Material down_material;
        Cogl.Material up_material;
        Gee.ArrayList<FramebufferContainer> textures;

        uint handle; 
        uint target;

        static construct
        {
            var fragment = new Cogl.Shader (Cogl.ShaderType.FRAGMENT);
            fragment.source (DOWNSAMPLE_FRAG_SHADER);
    
            down_program = new Cogl.Program ();
            down_program.attach_shader (fragment);
            down_program.link ();
    
            fragment = new Cogl.Shader (Cogl.ShaderType.FRAGMENT);
            fragment.source (UPSAMPLE_FRAG_SHADER);
    
            up_program = new Cogl.Program ();
            up_program.attach_shader (fragment);
            up_program.link ();

            int tex_location = down_program.get_uniform_location ("tex");
            CoglFixes.set_uniform_1i (down_program, tex_location, 0);
    
            tex_location = up_program.get_uniform_location ("tex");
            CoglFixes.set_uniform_1i (up_program, tex_location, 0);
    
            down_width_location = down_program.get_uniform_location ("halfwidth");     
            down_height_location = down_program.get_uniform_location ("halfheight");
            down_offset_location = down_program.get_uniform_location ("offset");
    
            up_width_location = up_program.get_uniform_location ("halfwidth");     
            up_height_location = up_program.get_uniform_location ("halfheight");
            up_offset_location = up_program.get_uniform_location ("offset");

            copy_tex_sub_image = (GlCopyTexSubFunc)Cogl.get_proc_address ("glCopyTexSubImage2D");
            bind_texture = (GlBindTextureFunc)Cogl.get_proc_address ("glBindTexture");
        }    

        construct
        {
            textures = new Gee.ArrayList<FramebufferContainer> ();

            down_material = new Cogl.Material ();
            down_material.set_layer_filters (0, Cogl.MaterialFilter.LINEAR, Cogl.MaterialFilter.LINEAR);
            CoglFixes.material_set_layer_wrap_mode (down_material, 0, Cogl.MaterialWrapMode.CLAMP_TO_EDGE);
            CoglFixes.set_user_program (down_material, down_program);
    
            up_material = new Cogl.Material ();
            up_material.set_layer_filters (0, Cogl.MaterialFilter.LINEAR, Cogl.MaterialFilter.LINEAR);
            CoglFixes.material_set_layer_wrap_mode (up_material, 0, Cogl.MaterialWrapMode.CLAMP_TO_EDGE);
            CoglFixes.set_user_program (up_material, up_program);
    
            material = new Cogl.Material ();
            material.set_layer_filters (0, Cogl.MaterialFilter.LINEAR_MIPMAP_LINEAR, Cogl.MaterialFilter.LINEAR);

            if (window_actor != null) {
                window = window_actor.get_meta_window ();
            }

            var stage = ui_group.get_stage ();
            stage.get_size (out stage_width, out stage_height);
            stage.allocation_changed.connect (() => init_fbo_textures ());

            init_fbo_textures ();
        }

        public BlurActor (Meta.WindowActor? window_actor, int iterations, float offset, int expand_size, Clutter.Actor ui_group)
        {
            Object (window_actor: window_actor, iterations: iterations, expand_size: expand_size, ui_group: ui_group);

            CoglFixes.set_uniform_1f (down_program, down_offset_location, offset);
            CoglFixes.set_uniform_1f (up_program, up_offset_location, offset);
        }

        void init_fbo_textures ()
        {
            textures.clear ();

            for (int i = 0; i <= iterations; i++) {
                int downscale = 1 << i;
    
                int width = (int)(stage_width / downscale);
                int height = (int)(stage_height / downscale);

                var texture = new Cogl.Texture.with_size (width, height,
                    Cogl.TextureFlags.NO_AUTO_MIPMAP, Cogl.PixelFormat.RGBA_8888);
                textures.add (new FramebufferContainer (texture));
            }

            for (int i = iterations - 1; i >= 0; i--) {
                int downscale = 1 << i;

                int width = (int)(stage_width / downscale);
                int height = (int)(stage_height / downscale);

                var texture = new Cogl.Texture.with_size (width, height,
                    Cogl.TextureFlags.NO_AUTO_MIPMAP, Cogl.PixelFormat.RGBA_8888);
                textures.add (new FramebufferContainer (texture));
            }

            CoglFixes.texture_get_gl_texture ((Cogl.Handle)textures[0].texture, out handle, out target);
        }

        public override void allocate (Clutter.ActorBox box, Clutter.AllocationFlags flags)
        {
            if (window != null) {
                float x, y;
                window_actor.get_position (out x, out y);

                var rect = window.get_frame_rect ();
                float width = rect.width;
                float height = rect.height;

                box.set_size (width, height);
                box.set_origin (rect.x - x, rect.y - y);
            }

            base.allocate (box, flags);
        }

        public override void paint ()
        {
            float width, height, x, y;
            get_size (out width, out height);
            get_transformed_position (out x, out y);

            float actor_x = x;
            float actor_y = y;

            double sx, sy;
            ui_group.get_scale (out sx, out sy);

            x = float.max (0, x - expand_size);
            y = float.max (0, y - expand_size);
            
            int tex_width = int.min ((int)((width + expand_size * 2) * sx), (int)stage_width);
            tex_height = int.min ((int)((height + expand_size * 2) * sy), (int)stage_height);

            int tex_x = int.min ((int)x, (int)stage_width);
            int tex_y = int.min ((int)(stage_height - y - tex_height), (int)stage_height);

            copy_target_texture (tex_x, tex_y, tex_width, tex_height);

            downsample ();
            upsample ();

            var res = textures.last ();
            uint8 paint_opacity = get_paint_opacity ();

            material.set_layer (0, res.texture);
            material.set_color4ub (paint_opacity, paint_opacity, paint_opacity, paint_opacity);

            CoglFixes.framebuffer_push_rectangle_clip (Cogl.get_draw_framebuffer (), 0, 0, width, height);

            Cogl.set_source (material);
            if (x >= expand_size && y >= expand_size) {
                Cogl.translate (-expand_size / (float)sx, -expand_size / (float)sy, 0);
            } else {
                float tx = actor_x < expand_size ? -actor_x / (float)sx : -expand_size / (float)sx;
                float ty = actor_y < expand_size ? -actor_y / (float)sy : -expand_size / (float)sy;
                Cogl.translate (tx, ty, 0);
            }

            Cogl.rectangle_with_texture_coords (0, 0, stage_width / (float)sx, stage_height / (float)sy, 0, 0, 1, 1);
            CoglFixes.framebuffer_pop_clip (Cogl.get_draw_framebuffer ());
        }

        void copy_target_texture (int x, int y, int width, int height)
        {
            Cogl.begin_gl ();
            bind_texture (target, handle);
            copy_tex_sub_image (target, 0, 0, 0, x, y, width, height);
            bind_texture (target, 0);
            Cogl.end_gl ();
        }

        void downsample ()
        {
            Cogl.set_source (down_material);
            for (int i = 1; i <= iterations; i++) {
                var source_cont = textures[i - 1];
                var dest_cont = textures[i];

                render_to_fbo ((Cogl.Framebuffer)dest_cont.fbo, dest_cont.texture,
                            source_cont.texture, down_material,
                            down_program, down_width_location, down_height_location, i == 1);
            }
        }
    
        void upsample ()
        {
            Cogl.set_source (up_material);
            for (int i = iterations; i < textures.size - 1; i++) {
                var source_cont = textures[i];
                var dest_cont = textures[i + 1];

                render_to_fbo ((Cogl.Framebuffer)dest_cont.fbo, dest_cont.texture,
                            source_cont.texture, up_material,
                            up_program, up_width_location, up_height_location);
    
            }
        }
        
        void render_to_fbo (Cogl.Framebuffer target, Cogl.Texture target_texture,
                            Cogl.Texture source, Cogl.Material material,
                            Cogl.Program program, int width_location,
                            int height_location, bool y_flip = false)
        {
            CoglFixes.set_uniform_1f (program, width_location, 0.5f / source.get_width ());
            CoglFixes.set_uniform_1f (program, height_location, 0.5f / source.get_height ());    
    
            material.set_layer (0, source);

            Cogl.push_framebuffer ((Cogl.Framebuffer)target);

            if (y_flip) {
                float y_translate = (float)source.get_height () - tex_height;

                Cogl.push_matrix ();
                Cogl.scale (1.0f, -1.0f, 1.0f);
                Cogl.translate (0.0f, y_translate / target_texture.get_height (), 0.0f);
                Cogl.rectangle_with_texture_coords (-1, -1, 1, 1, 0, 0, 1, 1);
                Cogl.pop_matrix ();
            } else {
                Cogl.rectangle_with_texture_coords (-1, -1, 1, 1, 0, 0, 1, 1);
            }

            Cogl.pop_framebuffer ();
        }
    }    
}
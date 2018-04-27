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
    /**
     * Contains the offscreen framebuffer and the target texture that's
     * attached to it.
     */
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

    /**
     * Workaround for Vala not supporting static signals.
     */
    class HandleNotifier
    {
        public signal void updated ();
    }

    const string DOWNSAMPLE_FRAG_SHADER = """
        uniform sampler2D tex;
        uniform float half_width;
        uniform float half_height;
        uniform float offset;

        void main () {
            vec2 uv = cogl_tex_coord0_in.xy;
            vec2 halfpixel = vec2(half_width, half_height);

            vec4 sum = texture2D (tex, uv) * 4.0;
            sum += texture2D (tex, uv - halfpixel.xy * offset);
            sum += texture2D (tex, uv + halfpixel.xy * offset);
            sum += texture2D (tex, uv + vec2(halfpixel.x, -halfpixel.y) * offset);
            sum += texture2D (tex, uv - vec2(halfpixel.x, -halfpixel.y) * offset);
            cogl_color_out = sum / 8.0;
        }
    """;

    const string UPSAMPLE_FRAG_SHADER = """
        uniform sampler2D tex;
        uniform float half_width;
        uniform float half_height;
        uniform float offset;
        uniform float saturation;
		uniform float brightness;

        vec3 saturate (vec3 rgb, float adjustment) {
            const vec3 W = vec3(0.2125, 0.7154, 0.0721);
            vec3 intensity = vec3(dot(rgb, W));
            return mix (intensity, rgb, adjustment);
        }

        void main () {
            vec2 uv = cogl_tex_coord0_in.xy;
            vec2 halfpixel = vec2(half_width, half_height);

            vec4 sum = texture2D (tex, uv + vec2(-halfpixel.x * 2.0, 0.0) * offset);
            sum += texture2D (tex, uv + vec2(-halfpixel.x, halfpixel.y) * offset) * 2.0;
            sum += texture2D (tex, uv + vec2(0.0, halfpixel.y * 2.0) * offset);
            sum += texture2D (tex, uv + vec2(halfpixel.x, halfpixel.y) * offset) * 2.0;
            sum += texture2D (tex, uv + vec2(halfpixel.x * 2.0, 0.0) * offset);
            sum += texture2D (tex, uv + vec2(halfpixel.x, -halfpixel.y) * offset) * 2.0;
            sum += texture2D (tex, uv + vec2(0.0, -halfpixel.y * 2.0) * offset);
            sum += texture2D (tex, uv + vec2(-halfpixel.x, -halfpixel.y) * offset) * 2.0;
            sum /= 12.0;

            vec3 mixed = saturate (sum.rgb, saturation) + vec3 (brightness, brightness, brightness);
            cogl_color_out = vec4 (mixed, sum.a) * cogl_color_in;
        }
    """;

    const string COPYSAMPLE_FRAG_SHADER = """
        uniform sampler2D tex;
        uniform float tex_x1;
        uniform float tex_y1;
        uniform float tex_x2;
        uniform float tex_y2;

        void main () {
            vec2 uv = cogl_tex_coord0_in.xy;
            vec2 min = vec2(tex_x1, tex_y1);
            vec2 max = vec2(tex_x2, tex_y2);
            cogl_color_out = texture2D(tex, clamp (uv, min, max));
        }
    """;

    public class BlurActor : Clutter.Actor
    {
        const int DOCK_SHRINK_AREA = 1;
        const uint GL_TEXTURE_2D = 0x0DE1;

        static int down_width_location;
        static int down_height_location;
    
        static int up_width_location;
        static int up_height_location;
    
        static Cogl.Program down_program;
        static Cogl.Program up_program;
        static Cogl.Program copysample_program;

        static Cogl.Material down_material;
        static Cogl.Material up_material;
        static Cogl.Material copysample_material;

        static int down_offset_location;
        static int up_offset_location;

        static int saturation_location;
        static int brightness_location;

        static int copysample_tex_x_location;
        static int copysample_tex_y_location;
        static int copysample_tex_width_location;
        static int copysample_tex_height_location;

        static GlCopyTexSubFunc? copy_tex_sub_image;
        static GlBindTextureFunc? bind_texture;
        static GlGenQueries? gen_queries;
        static GlQueryCounter? query_counter;
        static GlGetQueryObjectui64v? get_query_object;

        static uint* queries;
        
        static float min_cpu;
        static float min_gpu;

        static float max_cpu;
        static float max_gpu;
        static bool first_paint = true;

        static Cogl.Texture copysample_texture;
        static Gee.ArrayList<FramebufferContainer> textures;

        static HandleNotifier handle_notifier;
        static uint handle; 
        static uint copysample_handle;

        static int iterations;
        static int expand_size;

        static float stage_width;
        static float stage_height;

        static unowned Clutter.Actor ui_group;

        delegate void GlCopyTexSubFunc (uint target, int level,
                                        int xoff, int yoff,
                                        int x, int y,
                                        int width, int height);
        delegate void GlBindTextureFunc (uint target, uint texture);

        delegate void GlGenQueries (uint n, uint* ids);
        delegate void GlQueryCounter (uint id, uint target);
        delegate void GlGetQueryObjectui64v (uint id, uint pname, uint* params);

        public signal void clip_updated ();

        public Meta.WindowActor? window_actor { get; construct; }
        public Meta.Rectangle blur_clip_rect { get; set; }

        Meta.Window? window;

        Meta.Rectangle actor_rect;
        Meta.Rectangle tex_rect;

        bool is_dock = false;
        uint current_handle;

        public static void init (int _iterations, float offset, int _expand_size, Clutter.Actor _ui_group)
        {
            iterations = _iterations;
            ui_group = _ui_group;
            expand_size = _expand_size;

            handle_notifier = new HandleNotifier ();

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

            fragment = new Cogl.Shader (Cogl.ShaderType.FRAGMENT);
            fragment.source (COPYSAMPLE_FRAG_SHADER);

            copysample_program = new Cogl.Program ();
            copysample_program.attach_shader (fragment);
            copysample_program.link ();

            down_material = new Cogl.Material ();
            down_material.set_layer_filters (0, Cogl.MaterialFilter.LINEAR, Cogl.MaterialFilter.LINEAR);
            CoglFixes.material_set_layer_wrap_mode (down_material, 0, Cogl.MaterialWrapMode.CLAMP_TO_EDGE);
            CoglFixes.set_user_program (down_material, down_program);
    
            up_material = new Cogl.Material ();
            up_material.set_layer_filters (0, Cogl.MaterialFilter.LINEAR, Cogl.MaterialFilter.LINEAR);
            CoglFixes.material_set_layer_wrap_mode (up_material, 0, Cogl.MaterialWrapMode.CLAMP_TO_EDGE);
            CoglFixes.set_user_program (up_material, up_program);

            copysample_material = new Cogl.Material ();
            copysample_material.set_layer_filters (0, Cogl.MaterialFilter.LINEAR, Cogl.MaterialFilter.LINEAR);
            CoglFixes.set_user_program (copysample_material, copysample_program);

            int tex_location = down_program.get_uniform_location ("tex");
            CoglFixes.set_uniform_1i (down_program, tex_location, 0);
    
            tex_location = up_program.get_uniform_location ("tex");
            CoglFixes.set_uniform_1i (up_program, tex_location, 0);
    
            tex_location = copysample_program.get_uniform_location ("tex");
            CoglFixes.set_uniform_1i (copysample_program, tex_location, 0);
    
            down_width_location = down_program.get_uniform_location ("half_width");     
            down_height_location = down_program.get_uniform_location ("half_height");
            down_offset_location = down_program.get_uniform_location ("offset");
    
            up_width_location = up_program.get_uniform_location ("half_width");     
            up_height_location = up_program.get_uniform_location ("half_height");
            up_offset_location = up_program.get_uniform_location ("offset");

            saturation_location = up_program.get_uniform_location ("saturation");     
            brightness_location = up_program.get_uniform_location ("brightness");
            up_offset_location = up_program.get_uniform_location ("offset");

            copysample_tex_x_location = copysample_program.get_uniform_location ("tex_x1");
            copysample_tex_y_location = copysample_program.get_uniform_location ("tex_y1");
            copysample_tex_width_location = copysample_program.get_uniform_location ("tex_x2");
            copysample_tex_height_location = copysample_program.get_uniform_location ("tex_y2");

            CoglFixes.set_uniform_1f (down_program, down_offset_location, offset);
            CoglFixes.set_uniform_1f (up_program, up_offset_location, offset);

            CoglFixes.set_uniform_1f (up_program, saturation_location, 1.0f);
            CoglFixes.set_uniform_1f (up_program, brightness_location, 0.0f);

            copy_tex_sub_image = (GlCopyTexSubFunc)Cogl.get_proc_address ("glCopyTexSubImage2D");
            bind_texture = (GlBindTextureFunc)Cogl.get_proc_address ("glBindTexture");
            gen_queries = (GlGenQueries)Cogl.get_proc_address ("glGenQueries");
            query_counter = (GlQueryCounter)Cogl.get_proc_address ("glQueryCounter");
            get_query_object = (GlGetQueryObjectui64v)Cogl.get_proc_address ("glGetQueryObjectui64v");

            queries = new uint[2];
            gen_queries (2, queries);

            min_cpu = float.MAX;
            min_gpu = float.MAX;

            max_cpu = float.MIN;
            max_gpu = float.MIN;

            textures = new Gee.ArrayList<FramebufferContainer> ();

            var stage = ui_group.get_stage ();
            stage.notify["allocation"].connect (() => init_fbo_textures ());

            init_fbo_textures ();
        }

        public static void deinit ()
        {
            if (!is_initted ()) {
                return;
            }

            textures.clear ();
        }

        public static bool is_initted ()
        {
            return textures != null && textures.size > 0;
        }

        public static bool get_supported ()
        {
            return Cogl.features_available (Cogl.FeatureFlags.OFFSCREEN |
                                            Cogl.FeatureFlags.SHADERS_GLSL |
                                            Cogl.FeatureFlags.TEXTURE_RECTANGLE |
                                            Cogl.FeatureFlags.TEXTURE_NPOT);
        }

        construct
        {
            if (window_actor != null) {
                window = window_actor.get_meta_window ();
                window.notify["window-type"].connect (update_window_type);
            }

            handle_notifier.updated.connect (update_current_handle);
            update_window_type ();
        }

        public BlurActor (Meta.WindowActor? window_actor)
        {
            Object (window_actor: window_actor);
        }

        static void init_fbo_textures ()
        {
            textures.clear ();

            var stage = ui_group.get_stage ();
            stage.get_size (out stage_width, out stage_height);

            copysample_texture = new Cogl.Texture.with_size ((int)stage_width, (int)stage_height,
                    Cogl.TextureFlags.NO_AUTO_MIPMAP, Cogl.PixelFormat.RGBA_8888);
            copysample_material.set_layer (0, copysample_texture);

            CoglFixes.texture_get_gl_texture ((Cogl.Handle)copysample_texture, out copysample_handle, null);

            for (int i = 0; i <= iterations; i++) {
                int downscale = 1 << i;
    
                uint width = (int)(stage_width / downscale);
                uint height = (int)(stage_height / downscale);

                var texture = new Cogl.Texture.with_size (width, height,
                    Cogl.TextureFlags.NO_AUTO_MIPMAP, Cogl.PixelFormat.RGBA_8888);
                textures.add (new FramebufferContainer (texture));
            }

            CoglFixes.texture_get_gl_texture ((Cogl.Handle)textures[0].texture, out handle, null);

            handle_notifier.updated ();
        }

        public override void allocate (Clutter.ActorBox box, Clutter.AllocationFlags flags)
        {
            if (window != null) {
                float x, y;
                window_actor.get_position (out x, out y);

                var rect = window.get_frame_rect ();
                float width = blur_clip_rect.width > 0 ? blur_clip_rect.width : rect.width;
                float height = blur_clip_rect.height > 0 ? blur_clip_rect.height : rect.height;

                width = width.clamp (1, width - blur_clip_rect.x);
                height = height.clamp (1, height - blur_clip_rect.y);

                box.set_size (width, height);
                box.set_origin (rect.x - x + blur_clip_rect.x, rect.y - y + blur_clip_rect.y);
            }

            base.allocate (box, flags);
        }

        public override void paint ()
        {
            query_counter (queries[0], 0x8E28);
            
            var t = new Timer ();
            t.start ();

            if (!is_visible () || textures.size == 0) {
                return;
            }

            ui_group.get_stage ().ensure_viewport ();

            float width, height, x, y;
            get_size (out width, out height);
            get_transformed_position (out x, out y);

            double sx, sy;
            ui_group.get_scale (out sx, out sy);

            actor_rect = {
                (int)x, (int)y,
                (int)(width * (float)sx), (int)(height * (float)sy)
            };

            x = float.max (0, x - expand_size);
            y = float.max (0, y - expand_size);

            int tex_width = int.min ((int)(actor_rect.width + expand_size * 2), (int)(stage_width - x));
            int tex_height = int.min ((int)(actor_rect.height + expand_size * 2), (int)(stage_height - y));

            int tex_x = int.min ((int)x, (int)stage_width);
            int tex_y = int.min ((int)(stage_height - y - tex_height), (int)stage_height);

            tex_rect = {
                tex_x, tex_y,
                tex_width, tex_height
            };

            copy_target_texture ();

            downsample ();
            Cogl.flush ();
            upsample ();

            CoglFixes.set_uniform_1f (up_program, up_width_location, 0.5f / stage_width);
            CoglFixes.set_uniform_1f (up_program, up_height_location, 0.5f / stage_height);    

            uint8 paint_opacity = get_paint_opacity ();

            var texture = textures[1].texture;
            up_material.set_layer (0, texture);
            up_material.set_color4ub (paint_opacity, paint_opacity, paint_opacity, paint_opacity);

            CoglFixes.set_uniform_1f (up_program, saturation_location, 1.4f);
            CoglFixes.set_uniform_1f (up_program, brightness_location, 1.3f);

            unowned Cogl.Framebuffer draw_fbo = Cogl.get_draw_framebuffer ();
            CoglFixes.framebuffer_push_rectangle_clip (draw_fbo, 0, 0, width, height);
            CoglFixes.framebuffer_translate (draw_fbo, (float)(-actor_rect.x / sx), (float)(-actor_rect.y / sy), 0);
            CoglFixes.framebuffer_draw_textured_rectangle (draw_fbo, up_material, 0, 0, stage_width / (float)sx, stage_height / (float)sy, 0, 0, 1, 1);
            CoglFixes.framebuffer_pop_clip (draw_fbo);

            CoglFixes.set_uniform_1f (up_program, saturation_location, 1.0f);
            CoglFixes.set_uniform_1f (up_program, brightness_location, 0.0f);

            up_material.set_color4ub (255, 255, 255, 255);

            float cpu_time = (float)(t.elapsed () * 1000);
            query_counter (queries[1], 0x8E28);

            uint start_time = 0, stop_time = 0;

            get_query_object (queries[0], 0x8866, &start_time);
            get_query_object (queries[1], 0x8866, &stop_time);

            float gpu_time = (stop_time - start_time) / 1000000.0f;

            if (!first_paint) {
                if (cpu_time > max_cpu) {
                    max_cpu = cpu_time;
                }

                if (cpu_time < min_cpu) {
                    min_cpu = cpu_time;
                }

                if (gpu_time > max_gpu) {
                    max_gpu = gpu_time;
                }

                if (gpu_time < min_gpu) {
                    min_gpu = gpu_time;
                }

                print ("\nPaint cycle:\n");
                print ("CPU Min. time: %f\n", min_cpu);
                print ("CPU Max. time: %f\n", max_cpu);
                print ("\n");
                print ("GPU Min. time: %f\n", min_gpu);
                print ("GPU Max. time: %f\n", max_gpu);
            } else {
                first_paint = false;
            }
        }

        void update_window_type ()
        {
            is_dock = window != null && window.get_window_type () == Meta.WindowType.DOCK;
            update_current_handle ();
        }

        inline void update_current_handle ()
        {
            current_handle = is_dock ? copysample_handle : handle;
        }

        void copy_target_texture ()
        {
            int xoff = tex_rect.x;
            int yoff = tex_rect.y;

            Cogl.begin_gl ();
            bind_texture (GL_TEXTURE_2D, current_handle);

            copy_tex_sub_image (GL_TEXTURE_2D, 0, xoff, yoff,
                xoff, yoff, (int)tex_rect.width, (int)tex_rect.height);

            bind_texture (GL_TEXTURE_2D, 1);
            Cogl.end_gl ();

            if (is_dock) {
                float x1 = (xoff + DOCK_SHRINK_AREA) / stage_width;
                float x2 = (xoff + actor_rect.width - DOCK_SHRINK_AREA) / stage_width;

                float y_target = float.min (actor_rect.y, expand_size);
                float y1 = (yoff + tex_rect.height - actor_rect.height - y_target + DOCK_SHRINK_AREA) / stage_height;
                float y2 = (yoff + tex_rect.height - y_target - DOCK_SHRINK_AREA) / stage_height;

                CoglFixes.set_uniform_1f (copysample_program, copysample_tex_x_location, x1);
                CoglFixes.set_uniform_1f (copysample_program, copysample_tex_y_location, y1);
                CoglFixes.set_uniform_1f (copysample_program, copysample_tex_width_location, x2);
                CoglFixes.set_uniform_1f (copysample_program, copysample_tex_height_location, y2);

                unowned Cogl.Framebuffer target = (Cogl.Framebuffer)textures[0].fbo;
                
                CoglFixes.framebuffer_push_matrix (target); 
                CoglFixes.framebuffer_scale (target, 1.0f, -1.0f, 1.0f);
                CoglFixes.framebuffer_draw_textured_rectangle (target, copysample_material, 
                    -1, -1, 1, 1, 0, 0, 1, 1);
                CoglFixes.framebuffer_pop_matrix (target);
            }
        }

        void downsample ()
        {
            for (int i = 1; i <= iterations; i++) {
                var source_cont = textures[i - 1];
                var dest_cont = textures[i];

                render_to_fbo (source_cont, dest_cont, down_material,
                            down_program, down_width_location, down_height_location);
            }
        }
    
        void upsample ()
        {
            for (int i = textures.size - 1; i > 1; i--) {
                var source_cont = textures[i];
                var dest_cont = textures[i - 1];

                render_to_fbo (source_cont, dest_cont, up_material,
                            up_program, up_width_location, up_height_location);
    
            }
        }

        void render_to_fbo (FramebufferContainer source, FramebufferContainer dest, Cogl.Material material,
                            Cogl.Program program, int width_location, int height_location)
        {
            var source_texture = source.texture;
            material.set_layer (0, source_texture);

            unowned Cogl.Framebuffer target = (Cogl.Framebuffer)dest.fbo;
            
            var target_texture = dest.texture;
            uint target_width = target_texture.get_width ();
            uint target_height = target_texture.get_height ();

            CoglFixes.set_uniform_1f (program, width_location, 0.5f / target_width);
            CoglFixes.set_uniform_1f (program, height_location, 0.5f / target_height);    

            CoglFixes.framebuffer_draw_textured_rectangle (target, material,
                -1, -1, 1, 1, 0, 0, 1, 1);
        }
    }    
}
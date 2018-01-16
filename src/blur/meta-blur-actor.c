//
//  Copyright (C) 2015 Deepin Technology Co., Ltd.
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

#include <config.h>

#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <GL/gl.h>
#include <clutter/clutter.h>

#include "cogl-utils.h"
#include "blur-utils.h"
#include <meta/errors.h>
#include <meta/screen.h>
#include <meta/compositor-mutter.h>
#include <meta-blur-actor.h>

static void _stage_add_always_redraw_actor(ClutterStage *stage, ClutterActor *actor)
    __attribute__((weakref("clutter_stage_add_always_redraw_actor")));
static void _stage_remove_always_redraw_actor(ClutterStage *stage, ClutterActor *actor)
    __attribute__((weakref("clutter_stage_remove_always_redraw_actor")));

enum
{
    PROP_META_SCREEN = 1,
    PROP_WINDOW_ACTOR,
    PROP_RADIUS,
    PROP_ROUNDS,
};

typedef enum {
    CHANGED_EFFECTS = 1 << 1,
    CHANGED_SIZE    = 1 << 2,
    CHANGED_ALL = 0xFFFF
} ChangedFlags;

static void build_gaussian_blur_kernel(int* pradius, float* offset, float* weight)
{
    int radius = *pradius;
    radius += (radius + 1) % 2;
    int sz = (radius+2)*2-1;
    int N = sz-1;
    float sigma = 1.0f;

    float sum = powf(2, N);
    weight[radius+1] = 1.0;
    for (int i = 1; i < radius+2; i++) {
        weight[radius-i+1] = weight[radius-i+2] * (N-i+1) / i;
    }
    sum -= (weight[radius+1] + weight[radius]) * 2.0;

    for (int i = 0; i < radius; i++) {
        offset[i] = (float)i*sigma;
        weight[i] /= sum;
    }

    *pradius = radius;

    radius = (radius+1)/2;
    for (int i = 1; i < radius; i++) {
        float w = weight[i*2] + weight[i*2-1];
        float off = (offset[i*2] * weight[i*2] + offset[i*2-1] * weight[i*2-1]) / w;
        offset[i] = off;
        weight[i] = w;
    }
    
    *pradius = radius;
}

struct _MetaBlurActorPrivate
{
    guint enabled: 1;

    MetaScreen *screen;
    MetaWindowActor *window_actor;
    MetaWindow *window;

    gboolean blurred;
    int radius;
    float kernel[101];
    int rounds;

    ChangedFlags changed;
    CoglPipeline *template;
    CoglPipeline *pl_passthrough;
    CoglPipeline *pl_masked; // masked by shape 

    CoglPipeline *pipeline;
    CoglPipeline *pipeline2;

    CoglTexture* texture;

    CoglTexture* blur_mask_texture; // for shaped region blur 
    cairo_surface_t *blur_mask; 

    CoglTexture* fbTex, *fbTex2;
    CoglOffscreen* fb, *fb2;
    float fb_width;
    float fb_height;

    cairo_rectangle_int_t clip_rect;

    int queued_redraw;
    int pipeline_res_location;
    int pipeline2_res_location;

    unsigned int gl_handle;
    unsigned int gl_target;
};

G_DEFINE_TYPE (MetaBlurActor, meta_blur_actor,
        CLUTTER_TYPE_ACTOR);

void (*meta_bind_texture)( GLenum      target,
            GLuint      texture);
void (*meta_copy_sub_tex)( GLenum      target, 
            GLint level, 
            GLint xoffset, 
            GLint yoffset,
            GLint x,
            GLint y,
            GLsizei width,
            GLsizei height);

gboolean meta_blur_actor_get_supported (void)
{
    CoglContext *ctx = clutter_backend_get_cogl_context (clutter_get_default_backend ());

    return cogl_has_features (ctx, 
            COGL_FEATURE_ID_OFFSCREEN,
            COGL_FEATURE_ID_GLSL,
            COGL_FEATURE_ID_TEXTURE_RECTANGLE,
            NULL);
}

static void invalidate_pipeline (MetaBlurActor *self,
        ChangedFlags         changed)
{
    MetaBlurActorPrivate *priv = self->priv;

    priv->changed |= changed;
}

static void meta_blur_actor_dispose (GObject *object)
{
    MetaBlurActor *self = META_BLUR_ACTOR (object);
    MetaBlurActorPrivate *priv = self->priv;

    if (priv->fbTex) {
        cogl_object_unref (priv->fbTex);
        cogl_object_unref (priv->fbTex2);
        cogl_object_unref (priv->fb);
        cogl_object_unref (priv->fb2);
        cogl_object_unref (priv->texture);
        priv->fbTex = NULL;
    }
    if (priv->pipeline) {
        cogl_object_unref (priv->pipeline);
        cogl_object_unref (priv->pipeline2);
        cogl_object_unref (priv->pl_passthrough);
        cogl_object_unref (priv->pl_masked);
        priv->pipeline = NULL;
        priv->pipeline2 = NULL;
    }

    g_clear_pointer (&priv->blur_mask_texture, cogl_object_unref);
    g_clear_pointer (&priv->blur_mask, cairo_surface_destroy);

   // g_clear_pointer (&priv->clip_region, cairo_region_destroy);

    if (_stage_remove_always_redraw_actor)
       _stage_remove_always_redraw_actor (meta_get_stage_for_screen (priv->screen), self);
    G_OBJECT_CLASS (meta_blur_actor_parent_class)->dispose (object);
}

static void make_pipeline (MetaBlurActor* self)
{
    MetaBlurActorPrivate* priv = self->priv;
    if (priv->template == NULL) {
        /* Cogl automatically caches pipelines with no eviction policy,
         * so we need to prevent identical pipelines from getting cached
         * separately, by reusing the same shader snippets.
         */
        priv->template = COGL_PIPELINE (meta_create_texture_pipeline (NULL));
        CoglSnippet* snippet = cogl_snippet_new (COGL_SNIPPET_HOOK_FRAGMENT_GLOBALS,
                gaussian_blur_global_definition, NULL);
        cogl_pipeline_add_snippet (priv->template, snippet);
        cogl_object_unref (snippet);
    }

    priv->pl_passthrough = cogl_pipeline_copy (priv->template);
    priv->pl_masked = cogl_pipeline_copy (priv->template);
    cogl_pipeline_set_layer_combine (priv->pl_masked, 1,
            "RGBA = MODULATE (PREVIOUS, TEXTURE[A])", NULL);

}

static void create_texture (MetaBlurActor* self)
{
    MetaBlurActorPrivate* priv = self->priv;
    int scale = 2;

    CoglContext *ctx = clutter_backend_get_cogl_context(clutter_get_default_backend());

    int fb_width, fb_height;

    ClutterActorBox box;
    clutter_actor_get_allocation_box (CLUTTER_ACTOR (self), &box);

    float width, height;
    clutter_actor_box_get_size (&box, &width, &height);

    fb_width = width;
    fb_height = height;

    fb_width = MAX (1, fb_width);
    fb_height = MAX (1, fb_height);

    fb_width >>= scale;
    fb_height >>= scale;

    if (priv->fbTex2 != NULL && (priv->fb_width == fb_width && priv->fb_height == fb_height)) {
        return;
    }

    if (priv->fbTex2) {
        g_clear_pointer (&priv->fbTex2, cogl_object_unref);
        g_clear_pointer (&priv->fbTex, cogl_object_unref);
        g_clear_pointer (&priv->fb, cogl_object_unref);
        g_clear_pointer (&priv->fb2, cogl_object_unref);
    }

    priv->fb_width = fb_width;
    priv->fb_height = fb_height;

    priv->fbTex = cogl_texture_2d_new_with_size(ctx, priv->fb_width, priv->fb_height);
    cogl_texture_set_components(priv->fbTex, COGL_TEXTURE_COMPONENTS_RGBA);
    cogl_primitive_texture_set_auto_mipmap(priv->fbTex, FALSE);

    CoglError *error = NULL;
    if (cogl_texture_allocate(priv->fbTex, &error) == FALSE) {
        meta_warning ("cogl_texture_allocat failed: %s\n", error->message);
        goto _error;
    }

    priv->fb = cogl_offscreen_new_with_texture(priv->fbTex);
    if (cogl_framebuffer_allocate(priv->fb, &error) == FALSE) {
        meta_warning ("cogl_framebuffer_allocate failed: %s\n", error->message);
        goto _error;
    }

    cogl_framebuffer_orthographic(priv->fb, 0, 0,
            priv->fb_width, priv->fb_height, -1., 1.);

    priv->fbTex2 = cogl_texture_2d_new_with_size(ctx, priv->fb_width, priv->fb_height);
    cogl_texture_set_components(priv->fbTex2, COGL_TEXTURE_COMPONENTS_RGBA);
    cogl_primitive_texture_set_auto_mipmap(priv->fbTex2, FALSE);

    if (cogl_texture_allocate(priv->fbTex2, &error) == FALSE) {
        meta_warning ("cogl_texture_allocat failed: %s\n", error->message);
        goto _error;
    }

    priv->fb2 = cogl_offscreen_new_with_texture(priv->fbTex2);
    if (cogl_framebuffer_allocate(priv->fb2, &error) == FALSE) {
        meta_warning ("cogl_framebuffer_allocate failed: %s\n", error->message);
        goto _error;
    }

    cogl_framebuffer_orthographic(priv->fb2, 0, 0,
            priv->fb_width, priv->fb_height, -1., 1.);
    return;

_error:
    g_clear_pointer (&priv->fbTex2, cogl_object_unref);
    g_clear_pointer (&priv->fbTex, cogl_object_unref);
    g_clear_pointer (&priv->fb, cogl_object_unref);
    g_clear_pointer (&priv->fb2, cogl_object_unref);
}

static void preblur_texture(MetaBlurActor* self)
{
    MetaBlurActorPrivate *priv = self->priv;

    float resolution[2] = {priv->fb_width, priv->fb_height};
    cogl_pipeline_set_uniform_float(priv->pipeline, priv->pipeline_res_location, 2, 1, resolution);
    cogl_pipeline_set_uniform_float(priv->pipeline2, priv->pipeline2_res_location, 2, 1, resolution);

    for (int i = 0; i < priv->rounds; i++) {
        CoglTexture* tex1 = i == 0 ? priv->texture : priv->fbTex2;
        cogl_pipeline_set_layer_texture (priv->pipeline, 0, tex1);

        cogl_framebuffer_draw_textured_rectangle (priv->fb, priv->pipeline, 
                0.0f, 0.0f, priv->fb_width, priv->fb_height,
                0.0f, 0.0f, 1.00f, 1.00f);

        if (i > 0) cogl_framebuffer_finish(priv->fb);

        cogl_pipeline_set_layer_texture (priv->pipeline2, 0, priv->fbTex);
        cogl_framebuffer_draw_textured_rectangle (
                priv->fb2, priv->pipeline2,
                0.0f, 0.0f, priv->fb_width, priv->fb_height,
                0.0f, 0.0f, 1.00f, 1.00f);

        if (i > 0) cogl_framebuffer_finish(priv->fb2);
    }
}

static gboolean prepare_texture(MetaBlurActor* self)
{
    MetaBlurActorPrivate *priv = self->priv;
    CoglContext *ctx = clutter_backend_get_cogl_context(clutter_get_default_backend());
    float x, y;
    float width, height;
    int fw, fh;
    

    if (!clutter_actor_is_visible(self)) {
        return TRUE;
    }

    clutter_actor_get_size (self, &width, &height);
    width = MAX(width, 1.0);
    height = MAX(height, 1.0);

    clutter_actor_get_transformed_position (self, &x, &y);

    fw = cogl_framebuffer_get_width (cogl_get_draw_framebuffer ());
    fh = cogl_framebuffer_get_height (cogl_get_draw_framebuffer ());

#if 1
    if (priv->texture == NULL) {
        priv->texture = cogl_texture_2d_new_with_size(ctx, width, height);
        cogl_texture_set_components(priv->texture, COGL_TEXTURE_COMPONENTS_RGBA);
        cogl_primitive_texture_set_auto_mipmap(priv->texture, TRUE);

        CoglError *error = NULL;
        if (cogl_texture_allocate(priv->texture, &error) == FALSE) {
            meta_warning ("cogl_texture_allocat failed: %s\n", error->message);
            g_clear_pointer (&priv->texture, cogl_object_unref);
            priv->gl_target = 0;
            priv->gl_handle = 0;
            return FALSE;
        }

        cogl_texture_get_gl_texture (priv->texture, &priv->gl_handle, &priv->gl_target);

        cogl_pipeline_set_layer_texture (priv->pipeline, 0, priv->texture);
        cogl_pipeline_set_layer_filters (priv->pipeline, 0,
                COGL_PIPELINE_FILTER_LINEAR_MIPMAP_LINEAR,
                COGL_PIPELINE_FILTER_LINEAR);
    } else {
        uint twidth, theight;
        twidth = cogl_texture_get_width (priv->texture);
        theight = cogl_texture_get_height (priv->texture);

        int size = twidth * theight * 4;
        uint8_t data[size];
        memset (data, 0, size * sizeof (uint8_t));

        CoglError* error = NULL;
        cogl_texture_set_data (priv->texture, COGL_PIXEL_FORMAT_RGBA_8888_PRE, 0, data, 0, &error);

        if (error) {
            meta_warning ("clearing blur texture data failed: %s\n", error->message);
        }
    }

    clutter_stage_ensure_current (clutter_actor_get_stage (self));
    x = fminf(x, fw);
    y = fminf(fh - y - height, fh);

    cogl_flush ();
    meta_bind_texture (priv->gl_target, priv->gl_handle);
    meta_copy_sub_tex (priv->gl_target, 0, 0, 0, x, y, width, height);
    meta_bind_texture (priv->gl_target, 0);

#else
    // slow version, which works....
    static CoglPixelBuffer *pixbuf = NULL;
    static CoglBitmap *source_bmp = NULL;

    //FIXME: honor size change
    
    if (pixbuf == NULL)
        pixbuf = cogl_pixel_buffer_new (ctx, width * height * 4, NULL);

    if (source_bmp == NULL)
        source_bmp = cogl_bitmap_new_from_buffer (pixbuf,
                COGL_PIXEL_FORMAT_RGBA_8888,
                width, height,
                0,
                0);

#define COGL_READ_PIXELS_NO_FLIP (1L << 30)

    cogl_framebuffer_read_pixels_into_bitmap (cogl_get_draw_framebuffer (),
            x, y, 
            COGL_READ_PIXELS_NO_FLIP | COGL_READ_PIXELS_COLOR_BUFFER,
            source_bmp);

    if (priv->texture != NULL) {
        cogl_object_unref (priv->texture);
        priv->texture = NULL;
    }
    priv->texture = cogl_texture_2d_new_from_bitmap (source_bmp);
    cogl_pipeline_set_layer_texture (priv->pipeline, 0, priv->texture);
    cogl_pipeline_set_layer_filters (priv->pipeline, 0,
            COGL_PIPELINE_FILTER_LINEAR_MIPMAP_LINEAR,
            COGL_PIPELINE_FILTER_LINEAR);
    /*cogl_object_unref (source_bmp);*/
    /*cogl_object_unref (pixbuf);*/
#endif

    return TRUE;
}


static void setup_pipeline (MetaBlurActor   *self, cairo_rectangle_int_t *rect)
{
    MetaBlurActorPrivate *priv = self->priv;

    if (priv->changed & CHANGED_SIZE) {
        g_clear_pointer (&priv->texture, cogl_object_unref);
        priv->changed &= ~CHANGED_SIZE;
    }

    prepare_texture(self);
    if (priv->radius && priv->texture) {
        create_texture (self);

        cogl_pipeline_set_layer_texture (priv->pipeline2, 0, priv->fbTex);
        cogl_pipeline_set_layer_filters (priv->pipeline2, 0,
                COGL_PIPELINE_FILTER_LINEAR_MIPMAP_LINEAR,
                COGL_PIPELINE_FILTER_LINEAR);

        preblur_texture (self);
    }
}

static gboolean meta_blur_actor_get_paint_volume (
        ClutterActor       *actor,
        ClutterPaintVolume *volume)
{
    return clutter_paint_volume_set_from_allocation (volume, actor);
}

static void
meta_blur_actor_allocate (ClutterActor        *actor,
                       const ClutterActorBox  *box,
                       ClutterAllocationFlags  flags)
{
    MetaBlurActor *self = META_BLUR_ACTOR (actor);
    MetaBlurActorPrivate *priv = self->priv;
    ClutterActorClass *parent_class;

    if (priv->window) {
        float x, y;
        clutter_actor_get_position (self->priv->window_actor, &x, &y);

        MetaRectangle rect;
        meta_window_get_frame_rect (priv->window, &rect);

        float width = rect.width, height = rect.height;
        if (priv->clip_rect.width > 0) {
            width = priv->clip_rect.width;
        }

        if (priv->clip_rect.height > 0) {
            height = priv->clip_rect.height;
        }

        clutter_actor_box_set_size (box, width, height);
        clutter_actor_box_set_origin (box, rect.x - x + priv->clip_rect.x, rect.y - y + priv->clip_rect.y);
    }

    invalidate_pipeline (self, CHANGED_SIZE);
    CLUTTER_ACTOR_CLASS (meta_blur_actor_parent_class)->allocate (actor, box, flags);
}

void meta_blur_actor_set_blur_mask (MetaBlurActor *self, cairo_surface_t* blur_mask)
{
    MetaBlurActorPrivate *priv = self->priv;

    g_clear_pointer (&priv->blur_mask, cairo_surface_destroy);
    g_clear_pointer (&priv->blur_mask_texture, cogl_object_unref);

    if (blur_mask) {
        priv->blur_mask = cairo_surface_reference (blur_mask);

        CoglError *error = NULL;
        CoglContext *ctx = clutter_backend_get_cogl_context(clutter_get_default_backend());

        CoglTexture* mask_texture = COGL_TEXTURE (cogl_texture_2d_new_from_data (ctx, 
                    cairo_image_surface_get_width (priv->blur_mask),
                    cairo_image_surface_get_height (priv->blur_mask),
                    COGL_PIXEL_FORMAT_A_8, 
                    cairo_image_surface_get_stride (priv->blur_mask),
                    cairo_image_surface_get_data (priv->blur_mask), 
                    &error));
        if (error) {
            g_warning ("Failed to allocate mask texture: %s", error->message);
            cogl_error_free (error);
            mask_texture = NULL;
        }

        if (mask_texture)
            priv->blur_mask_texture = mask_texture;
    }
}

static void meta_blur_actor_paint (ClutterActor *actor)
{
    MetaBlurActor *self = META_BLUR_ACTOR (actor);
    MetaBlurActorPrivate *priv = self->priv;
    ClutterActorBox actor_box, transformed;
    cairo_rectangle_int_t bounding;
    float tx, ty, tw, th;

    priv->queued_redraw = 0;

    if (!priv->enabled) {
        CLUTTER_ACTOR_CLASS (meta_blur_actor_parent_class)->paint (actor);
        return;
    }

    clutter_actor_get_transformed_position (actor, &tx, &ty);
    clutter_actor_get_transformed_size (actor, &tw, &th);
    transformed.x1 = tx;
    transformed.y1 = ty;
    transformed.x2 = tx + tw;
    transformed.y2 = ty + th;

    clutter_actor_get_content_box (actor, &actor_box);
    bounding.x = actor_box.x1;
    bounding.y = actor_box.y1;
    bounding.width = actor_box.x2 - actor_box.x1;
    bounding.height = actor_box.y2 - actor_box.y1;

    CoglPipeline* pipeline = priv->pl_passthrough;

    if (priv->blur_mask_texture) {
        pipeline = priv->pl_masked;
        cogl_pipeline_set_layer_texture (priv->pl_masked, 1, priv->blur_mask_texture);
    }

    cogl_framebuffer_push_rectangle_clip (cogl_get_draw_framebuffer (),
            bounding.x, bounding.y, bounding.width, bounding.height);

    guint8 opacity;
    opacity = clutter_actor_get_paint_opacity (CLUTTER_ACTOR (self));
    cogl_pipeline_set_color4ub (pipeline,
            opacity, opacity, opacity, opacity);

    setup_pipeline (self, &bounding);

    if (priv->texture == NULL) {
        cogl_framebuffer_pop_clip (cogl_get_draw_framebuffer ());
        CLUTTER_ACTOR_CLASS (meta_blur_actor_parent_class)->paint (actor);
        return;
    }

    if (priv->radius > 0) {
        cogl_pipeline_set_layer_texture (pipeline, 0, priv->fbTex2);

    } else {
        cogl_pipeline_set_layer_texture (pipeline, 0, priv->texture);
    }

    if (pipeline == priv->pl_passthrough) {
        cogl_framebuffer_draw_textured_rectangle (
                cogl_get_draw_framebuffer (), pipeline,
                bounding.x, bounding.y, bounding.width, bounding.height,
                0.0f, 0.0f, 1.00f, 1.00f);
    } else {
        // blur with blur_mask
        float tex[8];
        tex[0] = 0.0;
        tex[1] = 0.0;
        tex[2] = 1.0;
        tex[3] = 1.0;


        tex[4] = 0.0;
        tex[5] = 0.0;
        tex[6] = 1.0;
        tex[7] = 1.0;


        if (transformed.x1 < 0.0f) {
            float sx = fabsf(transformed.x1) / (transformed.x2 - transformed.x1);
            bounding.x = sx * bounding.width;
            tex[4] = sx;
            tex[2] = 1.0 - sx;
        }

        if (transformed.y1 < 0.0f) {
            float sy = fabsf(transformed.y1) / (transformed.y2 - transformed.y1);
            bounding.y = sy * bounding.height;
            tex[5] = sy;
            tex[3] = 1.0 - sy;
        }

#ifdef DEBUG
        fprintf(stderr, "%s: %f, %f, %f, %f, (%d, %d, %d, %d)\n", __func__, transformed.x1,
                transformed.y1, transformed.x2 - transformed.x1,
                transformed.y2 - transformed.y1, 
                bounding.x, bounding.y, bounding.width, bounding.height);

        CoglColor clr;
        cogl_color_init_from_4ub(&clr, 0, 255, 0, 255);
        cogl_framebuffer_clear (cogl_get_draw_framebuffer (),
                COGL_BUFFER_BIT_COLOR, &clr);

        cogl_pipeline_set_color4f(pipeline, 1.0, 0.0, 0.0, 1.0);

        cogl_framebuffer_draw_rectangle (cogl_get_draw_framebuffer (),
                pipeline,
                bounding.x, bounding.y, bounding.width, bounding.height);

#else

        cogl_framebuffer_draw_multitextured_rectangle (
                cogl_get_draw_framebuffer (), pipeline,
                bounding.x, bounding.y, bounding.width, bounding.height,
                &tex[0], 8);
#endif
    }

  cogl_framebuffer_pop_clip (cogl_get_draw_framebuffer ());

  CLUTTER_ACTOR_CLASS (meta_blur_actor_parent_class)->paint (actor);
}

static void meta_blur_actor_set_property (GObject      *object,
        guint         prop_id,
        const GValue *value,
        GParamSpec   *pspec)
{
    MetaBlurActor *self = META_BLUR_ACTOR (object);
    MetaBlurActorPrivate *priv = self->priv;

    switch (prop_id)
    {
        case PROP_META_SCREEN:
            priv->screen = g_value_get_object (value);
            break;
        case PROP_RADIUS:
            meta_blur_actor_set_radius (self,
                    g_value_get_int (value));
            break;
        case PROP_ROUNDS:
            meta_blur_actor_set_rounds (self,
                    g_value_get_int (value));
            break;
        default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
            break;
    }
}

static void meta_blur_actor_get_property (GObject      *object,
        guint         prop_id,
        GValue       *value,
        GParamSpec   *pspec)
{
    MetaBlurActorPrivate *priv = META_BLUR_ACTOR (object)->priv;

    switch (prop_id)
    {
        case PROP_META_SCREEN:
            g_value_set_object (value, priv->screen);
            break;
        case PROP_WINDOW_ACTOR:
            g_value_set_object (value, priv->window_actor);
        case PROP_RADIUS:
            g_value_set_int (value, priv->radius);
            break;
        case PROP_ROUNDS:
            g_value_set_int (value, priv->rounds);
            break;
        default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
            break;
    }
}

    static void
meta_blur_actor_class_init (MetaBlurActorClass *klass)
{
    GObjectClass *object_class = G_OBJECT_CLASS (klass);
    ClutterActorClass *actor_class = CLUTTER_ACTOR_CLASS (klass);
    GParamSpec *param_spec;

    g_type_class_add_private (klass, sizeof (MetaBlurActorPrivate));

    object_class->dispose = meta_blur_actor_dispose;
    object_class->set_property = meta_blur_actor_set_property;
    object_class->get_property = meta_blur_actor_get_property;

    actor_class->get_paint_volume = meta_blur_actor_get_paint_volume;
    actor_class->paint = meta_blur_actor_paint;
    actor_class->allocate = meta_blur_actor_allocate;

    param_spec = g_param_spec_object ("meta-screen",
            "MetaScreen",
            "MetaScreen",
            META_TYPE_SCREEN,
            G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY);

    g_object_class_install_property (object_class,
            PROP_META_SCREEN,
            param_spec);

    param_spec = g_param_spec_int ("radius",
                "blur radius",
                "blur radius",
                0,
                META_BLUR_ACTOR_MAX_BLUR_RADIUS,
                META_BLUR_ACTOR_DEFAULT_BLUR_RADIUS,
                G_PARAM_READWRITE);

    g_object_class_install_property (object_class,
            PROP_RADIUS,
            param_spec);

    param_spec = g_param_spec_int ("rounds",
                "blur rounds",
                "blur rounds",
                1,
                META_BLUR_ACTOR_MAX_BLUR_ROUNDS,
                META_BLUR_ACTOR_DEFAULT_BLUR_ROUNDS,
                G_PARAM_READWRITE);

    g_object_class_install_property (object_class,
            PROP_ROUNDS,
            param_spec);
}

static void on_parent_queue_redraw (ClutterActor *actor,
        ClutterActor *origin,
        gpointer      user_data)
{
    MetaBlurActor *self = META_BLUR_ACTOR (user_data);
    if (self->priv->queued_redraw) return;

    self->priv->queued_redraw = 1;

    clutter_actor_queue_redraw (CLUTTER_ACTOR (self));

    g_signal_stop_emission_by_name (actor, "queue-redraw");

}

static void on_parent_changed (ClutterActor *actor,
        ClutterActor *old_parent,
        gpointer      user_data)
{
    if (old_parent != NULL) {
        g_signal_handlers_disconnect_by_func (old_parent, on_parent_queue_redraw, actor);
    }

    ClutterActor *parent = clutter_actor_get_parent (actor);
    if (parent != NULL)
        g_signal_connect (parent, "queue-redraw", on_parent_queue_redraw, actor);
}

static void meta_blur_actor_init (MetaBlurActor *self)
{
    MetaBlurActorPrivate *priv;

    priv = self->priv = G_TYPE_INSTANCE_GET_PRIVATE (self,
            META_TYPE_BLUR_ACTOR,
            MetaBlurActorPrivate);

    priv->radius = 0; // means no blur
    priv->rounds = 1;
    priv->enabled = TRUE;

    meta_bind_texture = cogl_get_proc_address ("glBindTexture");
    meta_copy_sub_tex = cogl_get_proc_address ("glCopyTexSubImage2D");

    // if clutter is not patched, use this hack instead
    if (_stage_add_always_redraw_actor == NULL) {
        meta_warning ("clutter is not patched, visual artifacts may happen.");
        g_signal_connect (G_OBJECT(self), "parent-set", on_parent_changed, NULL);
    }
}

ClutterActor * meta_blur_actor_new (MetaScreen *screen)
{
    MetaBlurActor *self;

    self = g_object_new (META_TYPE_BLUR_ACTOR, "meta-screen", screen, NULL);

    make_pipeline (self);

    if (_stage_add_always_redraw_actor)
        _stage_add_always_redraw_actor (meta_get_stage_for_screen (screen), self);
    return CLUTTER_ACTOR (self);
}

void meta_blur_actor_set_radius (MetaBlurActor *self, int radius)
{
    MetaBlurActorPrivate *priv = self->priv;

    g_return_if_fail (META_IS_BLUR_ACTOR (self));
    g_return_if_fail (radius >= 0 && radius <= 49);

    if (priv->radius != radius) {
        priv->radius = radius;
        if (radius > 0) {
            build_gaussian_blur_kernel(&radius, &priv->kernel[1], &priv->kernel[51]);
            priv->radius = radius;
            priv->kernel[0] = radius;

            char *vs = build_shader(VERTICAL, radius, &priv->kernel[1], &priv->kernel[51]);

            if (priv->pipeline) {
                g_clear_pointer (&priv->pipeline, cogl_object_unref);
            }

            priv->pipeline = cogl_pipeline_copy (priv->template);

            CoglSnippet* snippet = cogl_snippet_new (COGL_SNIPPET_HOOK_TEXTURE_LOOKUP,
                    gaussian_blur_glsl_declarations, NULL);
            cogl_snippet_set_replace (snippet, vs);
            cogl_pipeline_add_layer_snippet (priv->pipeline, 0, snippet);
            cogl_object_unref (snippet);

            priv->pipeline_res_location = cogl_pipeline_get_uniform_location (priv->pipeline, "resolution");

            free(vs);

            char *hs = build_shader(HORIZONTAL, radius, &priv->kernel[1], &priv->kernel[51]);

            if (priv->pipeline2) {
                g_clear_pointer (&priv->pipeline2, cogl_object_unref);
            }

            priv->pipeline2 = cogl_pipeline_copy (priv->template);

            snippet = cogl_snippet_new (COGL_SNIPPET_HOOK_TEXTURE_LOOKUP,
                    gaussian_blur_glsl_declarations, NULL);
            cogl_snippet_set_replace (snippet, hs);
            cogl_pipeline_add_layer_snippet (priv->pipeline2, 0, snippet);
            cogl_object_unref (snippet);

            priv->pipeline2_res_location = cogl_pipeline_get_uniform_location(priv->pipeline2, "resolution");

            free(hs);
        }

        invalidate_pipeline (self, CHANGED_EFFECTS);
        clutter_actor_queue_redraw (CLUTTER_ACTOR (self));
    }
}

void meta_blur_actor_set_rounds (MetaBlurActor *self, int rounds)
{
    MetaBlurActorPrivate *priv = self->priv;

    g_return_if_fail (META_IS_BLUR_ACTOR (self));
    g_return_if_fail (rounds >= 1 && rounds <= META_BLUR_ACTOR_MAX_BLUR_ROUNDS);

    if (priv->rounds != rounds) {
        priv->rounds = rounds;
        if (rounds > 0) {
            priv->rounds = rounds;
        }

        invalidate_pipeline (self, CHANGED_EFFECTS);
        clutter_actor_queue_redraw (CLUTTER_ACTOR (self));
    }
}

void meta_blur_actor_set_window_actor (MetaBlurActor *self, MetaWindowActor *window_actor)
{
    MetaBlurActorPrivate *priv = self->priv;
    g_return_if_fail (META_IS_BLUR_ACTOR (self));
    
    if (priv->window_actor == window_actor) {
        return;
    }

    priv->window_actor = META_WINDOW_ACTOR (g_object_ref (window_actor));
    if (priv->window_actor)
    {
        priv->window = meta_window_actor_get_meta_window (priv->window_actor);
    } else {
        priv->window = NULL;
    }

    clutter_actor_queue_relayout (CLUTTER_ACTOR (self));
    clutter_actor_queue_redraw (CLUTTER_ACTOR (self));
}

void meta_blur_actor_set_clip_rect (MetaBlurActor *self, const cairo_rectangle_int_t *clip_rect)
{
    MetaBlurActorPrivate *priv = self->priv;
    g_return_if_fail (META_IS_BLUR_ACTOR (self));

    if (priv->clip_rect.x == clip_rect->x &&
        priv->clip_rect.y == clip_rect->y &&
        priv->clip_rect.width == clip_rect->width &&
        priv->clip_rect.height == clip_rect->height)
    {
        return;
    }

    priv->clip_rect = *clip_rect;
    clutter_actor_queue_relayout (CLUTTER_ACTOR (self));
    clutter_actor_queue_redraw (CLUTTER_ACTOR (self));
}

void meta_blur_actor_set_enabled (MetaBlurActor *self, gboolean val)
{
    MetaBlurActorPrivate *priv = self->priv;

    if (priv->enabled != val) {
        if (!val) {
            // free resources
            g_clear_pointer (&priv->fbTex2, cogl_object_unref);
            g_clear_pointer (&priv->fbTex, cogl_object_unref);
            g_clear_pointer (&priv->fb, cogl_object_unref);
            g_clear_pointer (&priv->fb2, cogl_object_unref);
            g_clear_pointer (&priv->texture, cogl_object_unref);
        }

        invalidate_pipeline (self, CHANGED_EFFECTS);
        clutter_actor_queue_redraw (CLUTTER_ACTOR (self));
        priv->enabled = val;
    }
}


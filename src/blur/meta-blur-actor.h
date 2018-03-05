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

#ifndef META_BLUR_ACTOR_H
#define META_BLUR_ACTOR_H

#include <clutter/clutter.h>
#include <meta/screen.h>
#include <meta/meta-window-actor.h>
#include <cairo.h>

#define META_TYPE_BLUR_ACTOR            (meta_blur_actor_get_type ())
#define META_BLUR_ACTOR(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), META_TYPE_BLUR_ACTOR, MetaBlurActor))
#define META_BLUR_ACTOR_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), META_TYPE_BLUR_ACTOR, MetaBlurActorClass))
#define META_IS_BLUR_ACTOR(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), META_TYPE_BLUR_ACTOR))
#define META_IS_BLUR_ACTOR_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), META_TYPE_BLUR_ACTOR))
#define META_BLUR_ACTOR_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj), META_TYPE_BLUR_ACTOR, MetaBlurActorClass))

typedef struct _MetaBlurActor        MetaBlurActor;
typedef struct _MetaBlurActorClass   MetaBlurActorClass;
typedef struct _MetaBlurActorPrivate MetaBlurActorPrivate;

struct _MetaBlurActorClass
{
  /*< private >*/
  ClutterActorClass parent_class;
};

struct _MetaBlurActor
{
  ClutterActor parent;

  MetaBlurActorPrivate *priv;
};

GType meta_blur_actor_get_type (void);

ClutterActor *meta_blur_actor_new    (MetaScreen *screen);

gboolean meta_blur_actor_get_supported (void);

/* radius should be odd now, if == 0, means disable */
void meta_blur_actor_set_radius (MetaBlurActor *self, int radius);
void meta_blur_actor_set_rounds (MetaBlurActor *self, int rounds);
void meta_blur_actor_set_window_actor (MetaBlurActor *self, MetaWindowActor *window_actor);
void meta_blur_actor_set_blur_mask (MetaBlurActor *self, cairo_surface_t* mask);
void meta_blur_actor_set_enabled (MetaBlurActor *self, gboolean val);
void meta_blur_actor_set_clip_rect (MetaBlurActor *self, const cairo_rectangle_int_t *clip_rect);
void meta_blur_actor_set_texture_downscale (MetaBlurActor *self, int scale);

#define META_BLUR_ACTOR_MAX_BLUR_RADIUS 49
#define META_BLUR_ACTOR_MAX_BLUR_ROUNDS 99
#define META_BLUR_ACTOR_MAX_TEXTURE_DOWNSCALE 16
#define META_BLUR_ACTOR_DEFAULT_BLUR_RADIUS 7
#define META_BLUR_ACTOR_DEFAULT_BLUR_ROUNDS 1
#define META_BLUR_ACTOR_DEFAULT_TEXTURE_DOWNSCALE 16

#endif /* META_BLUR_ACTOR_H */


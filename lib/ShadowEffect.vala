/*
 * Copyright 2014 Tom Beckmann
 * Copyright 2023-2024 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.ShadowEffect : Clutter.Effect {
    public string css_class {
        construct set {
            switch (value) {
                case "workspace-switcher":
                    shadow_size = 6;
                    break;
                case "window":
                    shadow_size = 55;
                    break;
                default:
                    shadow_size = 18;
                    break;
            }
        }
    }

    public float scale_factor { get; set; default = 1; }
    public uint8 shadow_opacity { get; set; default = 255; }
    public int border_radius { get; set; default = 9;}

    private int shadow_size;

    private Cogl.Pipeline pipeline;
    private int current_width = 0;
    private int current_height = 0;

    private int radius {
        get {
            //  return shadow_size / 2;
            return 10;
        }
    }

    private int box_filter_size {
        get {
            return (int) (0.5 + radius * (0.75 * Math.sqrt (2 * Math.PI)));
        }
    }

    /* The "spread" of the filter is the number of pixels from an original
     * pixel that it's blurred image extends. (A no-op blur that doesn't
     * blur would have a spread of 0.) See comment in blur_rows() for why the
     * odd and even cases are different
     */
    private int shadow_spread {
        get {
            if (radius == 0) {
                return 0;
            }
    
            var d = box_filter_size;
    
            if (d % 2 == 1) {
                return 3 * (d / 2);
            } else {
                return 3 * (d / 2) - 1;
            }
        }
    }

    public ShadowEffect (string css_class = "") {
        Object (css_class: css_class);
    }

    construct {
        pipeline = new Cogl.Pipeline (Clutter.get_default_backend ().get_cogl_context ());
    }

    /* Returns null when there was an error generating the texture or when the texture shouldn't change */
    private Cogl.Texture? get_shadow (Cogl.Context context, int width, int height) {
        if (width == current_width && height == current_height) {
            return null;
        }

        current_width = width;
        current_height = height;

        Mtk.Rectangle rect = { 0, 0, width, height };
        return make_shadow (rect);
    }

    public override void paint (Clutter.PaintNode node, Clutter.PaintContext context, Clutter.EffectPaintFlags flags) {
        var shadow = get_shadow (context.get_framebuffer ().get_context (), (int) actor.width, (int) actor.height);
        if (shadow != null) {
            pipeline.set_layer_texture (0, shadow);
        }

        var opacity = actor.get_paint_opacity () * shadow_opacity / 255.0f;
        var alpha = Cogl.Color.from_4f (1.0f, 1.0f, 1.0f, opacity / 255.0f);
        alpha.premultiply ();

        pipeline.set_color (alpha);

        //  var bounding_box = get_bounding_box ();
        //  warning ("Drawing %f %f %f %f", bounding_box.x1, bounding_box.y1, bounding_box.x2, bounding_box.y2);
        context.get_framebuffer ().draw_rectangle (pipeline, 0, 0, actor.width, actor.height);

        actor.continue_paint (context);
    }

    //  private Clutter.ActorBox get_bounding_box () {
    //      // FIXME: THIS IS VERY VERY BROKEN
    //      var size = shadow_size * scale_factor;
    //      var bounding_box = Clutter.ActorBox ();

    //      bounding_box.set_origin (-size, -size);
    //      bounding_box.set_size (actor.width + size * 2, actor.height + size * 2);

    //      return bounding_box;
    //  }

    //  public override bool modify_paint_volume (Clutter.PaintVolume volume) {
    //      var bounding_box = get_bounding_box ();

    //      volume.set_width (bounding_box.get_width ());
    //      volume.set_height (bounding_box.get_height ());

    //      float origin_x, origin_y;
    //      bounding_box.get_origin (out origin_x, out origin_y);
    //      var origin = volume.get_origin ();
    //      origin.x += origin_x;
    //      origin.y += origin_y;
    //      volume.set_origin (origin);

    //      return true;
    //  }
    
    /* We emulate a 1D Gaussian blur by using 3 consecutive box blurs;
    * this produces a result that's within 3% of the original and can be
    * implemented much faster for large filter sizes because of the
    * efficiency of implementation of a box blur. Idea and formula
    * for choosing the box blur size come from:
    *
    * http://www.w3.org/TR/SVG/filters.html#feGaussianBlurElement
    *
    * The 2D blur is then done by blurring the rows, flipping the
    * image and blurring the columns. (This is possible because the
    * Gaussian kernel is separable - it's the product of a horizontal
    * blur and a vertical blur.)
    */

    /* This applies a single box blur pass to a horizontal range of pixels;
    * since the box blur has the same weight for all pixels, we can
    * implement an efficient sliding window algorithm where we add
    * in pixels coming into the window from the right and remove
    * them when they leave the windw to the left.
    *
    * d is the filter width; for even d shift indicates how the blurred
    * result is aligned with the original - does ' x ' go to ' yy' (shift=1)
    * or 'yy ' (shift=-1)
    */
    private void blur_xspan (
        uint8* row,
        int buffer_width,
        int x0,
        int x1,
        int d,
        int shift,
        int offset
    ) {       
        var tmp_buffer = new uint8[buffer_width];

        /* All the conditionals in here look slow, but the branches will
        * be well predicted and there are enough different possibilities
        * that trying to write this as a series of unconditional loops
        * is hard and not an obvious win. The main slow down here seems
        * to be the integer division per pixel; one possible optimization
        * would be to accumulate into two 16-bit integer buffers and
        * only divide down after all three passes. (SSE parallel implementation
        * of the divide step is possible.)
        */
        int sum = 0;
        for (var i = 0; i < buffer_width; i++) {
            if (i >= 0 && i < buffer_width) {
                sum += row[i];
            }

            if (i >= x0 + offset) {
                if (i >= d) {
                    sum -= row[i - d];
                }

                tmp_buffer[i - offset] = (uint8) ((sum + d / 2) / d);
                //  tmp_buffer[i - offset] = 255;
            }
        }

        Memory.copy (row + x0, &tmp_buffer[0] + x0, x1 - x0);
    }

    private void blur_rows (
        Mtk.Rectangle[] border_rects,
        int x_offset,
        int y_offset,
        uint8[] buffer,
        int buffer_width,
        int buffer_height,
        int d
    ) {
        var n_rects = border_rects.length;
        for (var rect_i = 0; rect_i < n_rects; rect_i++) {
            var rect = border_rects[rect_i];

            warning ("Blurring from %d go %d", y_offset + rect.y, y_offset + rect.y + rect.height);
            for (var row_i = y_offset + rect.y; row_i < y_offset + rect.y + rect.height; row_i++) {
                uint8 *row = &buffer[0] + buffer_width * row_i;
                int x0 = x_offset + rect.x;
                int x1 = x0 + rect.width;

                /* We want to produce a symmetric blur that spreads a pixel
                 * equally far to the left and right. If d is odd that happens
                 * naturally, but for d even, we approximate by using a blur
                 * on either side and then a centered blur of size d + 1.
                 * (technique also from the SVG specification)
                 */
                if (d % 2 == 1) {
                    blur_xspan (row, buffer_width, x0, x1, d, 0, x_offset);
                    //  blur_xspan (row, buffer_width, x0, x1, d, 0, x_offset);
                    //  blur_xspan (row, buffer_width, x0, x1, d, 0, x_offset);
                } else {
                    blur_xspan (row, buffer_width, x0, x1, d, 1, x_offset);
                    //  blur_xspan (row, buffer_width, x0, x1, d, -1, x_offset);
                    //  blur_xspan (row, buffer_width, x0, x1, d + 1, 0, x_offset);
                }
            }
        }
    }

    /**
     * make_border_rects:
     * @rect: a #Mtk.Rectangle
     * @x_amount: distance from the border to extend horizontally
     * @y_amount: distance from the border to extend vertically
     *
     * Computes the "border region" of a given region, which is roughly
     * speaking the set of points near the boundary of the region.  If we
     * define the operation of growing a region as computing the set of
     * points within a given manhattan distance of the region, then the
     * border is 'grow(region) intersect grow(inverse(region))'.
     *
     * If we create an image by filling the region with a solid color,
     * the border is the region affected by blurring the region.
     *
     * Return value: a new region which is the border of the given region
     */
    private Mtk.Rectangle[] make_border_rects (
        Mtk.Rectangle rect,
        int x_amount,
        int y_amount
    ) {
        Mtk.Rectangle top_rect = {0, 0, rect.width + x_amount * 2, y_amount};
        Mtk.Rectangle bottom_rect = {0, rect.height + y_amount, rect.width + x_amount * 2, y_amount};
        Mtk.Rectangle left_rect = {0, y_amount, x_amount, rect.height};
        Mtk.Rectangle right_rect = {rect.width + x_amount, y_amount, x_amount, rect.height};
            
        return { top_rect, bottom_rect, left_rect, right_rect };
    }


    /* Swaps width and height. Either swaps in-place and returns the original
     * buffer or allocates a new buffer, frees the original buffer and returns
     * the new buffer.
     */
    private uint8[] flip_buffer (
        uint8[] buffer,
        int width,
        int height
    ) {
        /* Working in blocks increases cache efficiency, compared to reading
         * or writing an entire column at once */
        var BLOCK_SIZE = 16;

        //  if (width == height) {
        //      int i0, j0;

        //      for (j0 = 0; j0 < height; j0 += BLOCK_SIZE) {
        //          for (i0 = 0; i0 <= j0; i0 += BLOCK_SIZE) {
        //              int max_j = int.min (j0 + BLOCK_SIZE, height);
        //              int max_i = int.min (i0 + BLOCK_SIZE, width);
        //              int i, j;

        //              if (i0 == j0) {
        //                  for (j = j0; j < max_j; j++) {
        //                      for (i = i0; i < j; i++) {
        //                          uint8 tmp = buffer[j * width + i];
        //                          buffer[j * width + i] = buffer[i * width + j];
        //                          buffer[i * width + j] = tmp;
        //                      }
        //                  }
        //              } else {
        //                  for (j = j0; j < max_j; j++) {
        //                      for (i = i0; i < max_i; i++) {
        //                          uint8 tmp = buffer[j * width + i];
        //                          buffer[j * width + i] = buffer[i * width + j];
        //                          buffer[i * width + j] = tmp;
        //                      }
        //                  }
        //              }
        //          }
        //      }

        //      return buffer;
        //  } else {
            var new_buffer = new uint8[width * height];

            for (var i0 = 0; i0 < width; i0 += BLOCK_SIZE) {
                int max_i = int.min (i0 + BLOCK_SIZE, width);

                for (var j0 = 0; j0 < height; j0 += BLOCK_SIZE) {
                    int max_j = int.min (j0 + BLOCK_SIZE, height);

                    for (var i = i0; i < max_i; i++) {
                        for (var j = j0; j < max_j; j++) {
                            new_buffer[i * height + j] = buffer[j * width + i];
                        }
                    }
                }
            }

            return new_buffer;
        //  }
    }

    private Cogl.Texture? make_shadow (Mtk.Rectangle rect) {
        var spread = shadow_spread;

        var buffer_width = rect.width + spread * 2;
        var buffer_height = rect.height + spread * 2;

        /* Round up so we have aligned rows/columns */
        buffer_width = (buffer_width + 3) & ~3;
        buffer_height = (buffer_height + 3) & ~3;

        /* Square buffer allows in-place swaps, which are roughly 70% faster, but we
         * don't want to over-allocate too much memory.
         */
        //  if (buffer_height < buffer_width && buffer_height > (3 * buffer_width) / 4) {
        //      buffer_height = buffer_width;
        //  } else if (buffer_width < buffer_height && buffer_width > (3 * buffer_height) / 4) {
        //      buffer_width = buffer_height;
        //  }

        var buffer = new uint8[buffer_width * buffer_height];

        /* Blurring with multiple box-blur passes is fast, but (especially for
         * large shadow sizes) we can improve efficiency by restricting the blur
         * to the region that actually needs to be blurred.
         */
        var row_border_rects = make_border_rects (rect, spread, spread);

        Mtk.Rectangle flipped_rect = { rect.y, rect.x, rect.height, rect.width };
        var column_border_rects = make_border_rects (flipped_rect, spread, 0);

        /* Offsets between coordinates of the regions and coordinates in the buffer */
        var x_offset = spread;
        var y_offset = spread;

        /* Step 1: unblurred image */
        for (var row_i = rect.y + y_offset; row_i < rect.y + y_offset + rect.height; row_i++) {
            Memory.set (&buffer[0] + buffer_width * row_i + x_offset + rect.x, 255, rect.width);
        }

        /* Step 2: swap rows and columns */
        buffer = flip_buffer (buffer, buffer_width, buffer_height);
        
        /* Step 3: blur rows (really columns) */
        var d = box_filter_size;
        blur_rows (
            column_border_rects, y_offset, x_offset,
            buffer, buffer_height, buffer_width,
            d
        );

        /* Step 4: swap rows and columns */
        buffer = flip_buffer (buffer, buffer_height, buffer_width);

        /* Step 5: blur rows */
        //  blur_rows (
        //      row_border_rects, x_offset, y_offset,
        //      buffer, buffer_width, buffer_height,
        //      d
        //  );

        var backend = Clutter.get_default_backend ();
        var ctx = backend.get_cogl_context ();
        try {
            //  return null;

            var texture = new Cogl.Texture2D.from_data (
                ctx,
                buffer_width,
                buffer_height,
                Cogl.PixelFormat.A_8,
                buffer_width,
                buffer
            );

            return texture;
        } catch (Error e) {
            critical ("ShadowEffect.make_shadow (): %s", e.message);
            return null;
        }
    }
}

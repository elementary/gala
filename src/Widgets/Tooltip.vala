/*
 * Copyright 2021 elementary, Inc (https://elementary.io)
 *           2021 José Expósito <jose.exposito89@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * Clutter actor to display text in a tooltip-like component.
 *
 * Style constants from:
 * https://github.com/elementary/stylesheet/blob/master/src/widgets/_tooltips.scss
 */
public class Gala.Tooltip : Clutter.Actor {
    private const double BACKGROUND_COLOR = (26 / 255); // #1a
    private const double BACKGROUND_OPACITY = 0.9;
    private const double BACKGROUND_BORDER_RADIUS = 3;
    private const string COLOR = "#ffffff";
    private const int PADDING_TOP = 3;
    private const int PADDING_BOTTOM = 3;
    private const int PADDING_LEFT = 6;
    private const int PADDING_RIGHT = 6;

    public string text {
        get {
            return _text;
        }
        set {
            _text = value;
            draw ();
        }
    }
    private string _text = "";

    public float max_width {
        get {
            return _max_width;
        }
        set {
            _max_width = value;
            draw ();
        }
    }
    private float _max_width = 200;

    /**
     * Canvas to draw the Tooltip background.
     */
    private Clutter.Canvas background_canvas;

    /**
     * Actor to display the Tooltip text.
     */
    private Clutter.Text? text_actor = null;

    construct {
        background_canvas = new Clutter.Canvas ();
        background_canvas.draw.connect (draw_background);
        content = background_canvas;
    }

    private void draw () {
        visible = (text.length != 0);

        if (!visible) {
            return;
        }

        // First set the text
        remove_child (text_actor);

        text_actor = new Clutter.Text () {
            color = Clutter.Color.from_string (COLOR),
            x = PADDING_LEFT,
            y = PADDING_TOP,
            ellipsize = Pango.EllipsizeMode.END,
            use_markup = true
        };
        text_actor.set_markup (Markup.printf_escaped ("<span size='large'>%s</span>", text));

        if (text_actor.width > max_width) {
            text_actor.width = max_width;
        }

        add_child (text_actor);

        // Adjust the size of the tooltip to the text
        width = text_actor.width + PADDING_LEFT + PADDING_RIGHT;
        height = text_actor.height + PADDING_TOP + PADDING_BOTTOM;
        background_canvas.set_size ((int) width, (int) height);

        // And paint the background
        background_canvas.invalidate ();
    }

    private bool draw_background (Cairo.Context cr, int width, int height) {
        cr.save ();
        cr.set_operator (Cairo.Operator.CLEAR);
        cr.paint ();
        cr.restore ();

        Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, 0, 0, width, height, BACKGROUND_BORDER_RADIUS);
        cr.set_source_rgba (BACKGROUND_COLOR, BACKGROUND_COLOR, BACKGROUND_COLOR, BACKGROUND_OPACITY);
        cr.fill ();

        return false;
    }
}

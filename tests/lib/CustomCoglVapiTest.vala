/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leo "lenemter" <lenemter@gmail.com>
 */

public class Gala.CustomCoglVapiTest : TestCase {
#if HAS_MUTTER47
    construct {
        add_test ("Test _vala_cogl_color_from_string", test_vala_cogl_color_from_string);
    }

    private void test_vala_cogl_color_from_string () {
        assert_cogl_color_is_white ("#ffffff");
        assert_cogl_color_is_white ("#ffffffff");
        assert_cogl_color_is_white ("#fff");
        assert_cogl_color_is_white ("#ffff");
        assert_cogl_color_is_white ("rgb(255, 255, 255)");
        assert_cogl_color_is_white ("rgba(255, 255, 255, 1)");
        assert_cogl_color_is_white ("hsl(0, 0%, 100%)");
        assert_cogl_color_is_white ("hsla(0, 0%, 100%, 1)");

        // Invalid string must be treated as a black color
        assert_cogl_color_is_black ("#55555");
        assert_cogl_color_is_black ("#121212121212");
        assert_cogl_color_is_black ("#555555555555555555555555");
        assert_cogl_color_is_black ("");
        assert_cogl_color_is_black ("qwerty");
    }

    private void assert_cogl_color_is_white (string color_str) {
        var color = Cogl.Color.from_string (color_str);
        assert_true (color.red == 255u && color.green == 255u && color.blue == 255u);
    }

    private void assert_cogl_color_is_black (string color_str) {
        var color = Cogl.Color.from_string (color_str);
        assert_true (color.red == 0u && color.green == 0u && color.blue == 0u);
    }
#endif
}

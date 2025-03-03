/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.BlurManager : Object {
    private static BlurManager instance;

    public static void init (WindowManager wm) {
        if (instance != null) {
            return;
        }

        instance = new BlurManager (wm);
    }

    public static unowned BlurManager? get_instance () {
        return instance;
    }

    public WindowManager wm { get; construct; }

    private Gee.List<Meta.Window> blurred_windows = new Gee.ArrayList<Meta.Window> (null);

    private BlurManager (WindowManager wm) {
        Object (wm: wm);
    }

    /**
     * The size given here is only used for the hide mode. I.e. struts
     * and collision detection with other windows use this size. By default
     * or if set to -1 the size of the window is used.
     *
     * TODO: Maybe use for strut only?
     */
    public void set_region (Meta.Window window, uint x, uint y, uint width, uint height) {
        if (window in blurred_windows) {
            return;
        }

        blurred_windows.add (window);
        unowned var actor = (Meta.WindowActor) window.get_compositor_private ();

        if (actor == null) {
            critical ("Cannot blur actor: Actor is null");
        }

        actor.add_effect (new BackgroundBlurEffect (actor, 18, 1.0f));
    }

    //X11 only
    //  private void parse_mutter_hints (Meta.Window window) requires (!Meta.Util.is_wayland_compositor ()) {
    //      if (window.mutter_hints == null) {
    //          return;
    //      }

    //      var mutter_hints = window.mutter_hints.split (":");
    //      foreach (var mutter_hint in mutter_hints) {
    //          var split = mutter_hint.split ("=");

    //          if (split.length != 2) {
    //              continue;
    //          }

    //          var key = split[0];
    //          var val = split[1];

    //          switch (key) {
    //              case "anchor":
    //                  int meta_side_parsed; // Will be used as Meta.Side which is a 4 value bitfield so check bounds for that
    //                  if (int.try_parse (val, out meta_side_parsed) && 0 <= meta_side_parsed && meta_side_parsed <= 15) {
    //                      //FIXME: Next major release change dock and wingpanel calls to get rid of this
    //                      Pantheon.Desktop.Anchor parsed = TOP;
    //                      switch ((Meta.Side) meta_side_parsed) {
    //                          case BOTTOM:
    //                              parsed = BOTTOM;
    //                              break;

    //                          case LEFT:
    //                              parsed = LEFT;
    //                              break;

    //                          case RIGHT:
    //                              parsed = RIGHT;
    //                              break;

    //                          default:
    //                              break;
    //                      }

    //                      set_anchor (window, parsed);
    //                      // We need to set a second time because the intention is to call this before the window is shown which it is on wayland
    //                      // but on X the window was already shown when we get here so we have to call again to instantly apply it.
    //                      set_anchor (window, parsed);
    //                  } else {
    //                      warning ("Failed to parse %s as anchor", val);
    //                  }
    //                  break;

    //              case "hide-mode":
    //                  int parsed; // Will be used as Pantheon.Desktop.HideMode which is a 5 value enum so check bounds for that
    //                  if (int.try_parse (val, out parsed) && 0 <= parsed && parsed <= 4) {
    //                      set_hide_mode (window, parsed);
    //                  } else {
    //                      warning ("Failed to parse %s as hide mode", val);
    //                  }
    //                  break;

    //              case "size":
    //                  var split_val = val.split (",");
    //                  if (split_val.length != 2) {
    //                      break;
    //                  }
    //                  int parsed_width, parsed_height = 0; //set to 0 because vala doesn't realize height will be set too
    //                  if (int.try_parse (split_val[0], out parsed_width) && int.try_parse (split_val[1], out parsed_height)) {
    //                      set_size (window, parsed_width, parsed_height);
    //                  } else {
    //                      warning ("Failed to parse %s as width and height", val);
    //                  }
    //                  break;

    //              case "centered":
    //                  make_centered (window);
    //                  break;

    //              default:
    //                  break;
    //          }
    //      }
    //  }
}

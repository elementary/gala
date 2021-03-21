using Clutter;

namespace Gala.Plugins.AppWindowOverview {
    public class Main : Gala.Plugin {
        Gala.AppWindowOverview appWindowOverview;
        Gala.WindowManager wm;

        ~Main() {
            appWindowOverview = null;
            wm = null;
        }

        public override void initialize (Gala.WindowManager wm) {
            this.wm = wm;
#if HAS_MUTTER330
            var display = wm.get_display ();
#else
            var display = wm.get_screen ().get_display ();
#endif
            Meta.KeyBinding.set_custom_handler("set-spew-mark", handle_switch_windows);
#if HAS_MUTTER330
            unowned Meta.Display display = wm.get_display ();
#else
            var screen = wm.get_screen ();
#endif
            appWindowOverview = new Gala.AppWindowOverview (wm);
            wm.ui_group.add_child (appWindowOverview);
        }

        public override void destroy () {
            if (wm == null) {
                return;
            }

#if HAS_MUTTER330
            var display = wm.get_display ();
#else
            var display = wm.get_screen ().get_display ();
#endif

            display.remove_keybinding ("app-window-overview");
        }

        void handle_switch_windows (Meta.Display display, Meta.Screen screen,
            Meta.Window? window,
            Clutter.KeyEvent? event, Meta.KeyBinding binding) {
            if (appWindowOverview.is_opened ()) {
                appWindowOverview.close ();
            } else {
                appWindowOverview.open ();
            }
        }
    }
}

public Gala.PluginInfo register_plugin () {
    return Gala.PluginInfo () {
        name = "App windows",
        author = "Jack Darlington",
        plugin_type = typeof (Gala.Plugins.AppWindowOverview.Main),
        provides = Gala.PluginFunction.ADDITION,
        load_priority = Gala.LoadPriority.IMMEDIATE
    };
}

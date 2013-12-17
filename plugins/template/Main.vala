//  
//  Copyright (C) 2012 Tom Beckmann
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

/*
  This is a template class showing some of the things that can be done
  with a gala plugin and how to do them.
*/

namespace Gala.Plugins.Template
{
	public class Main : Object, Gala.Plugin
	{
		public X.Xrectangle[] region { get; protected set; default = {}; }

		Gala.WindowManager? wm = null;
		const int PADDING = 50;

		Clutter.Actor red_box;

		// This function is called as soon as Gala has started and gives you
		// an instance of the GalaWindowManager class.
		public void initialize (Gala.WindowManager wm)
		{
			// we will save the instance to our wm property so we can use it later again
			// especially helpful when you have larger plugins with more functions,
			// we won't need it here
			this.wm = wm;

			// for demonstration purposes we'll add a red quad to the stage which will
			// turn green when clicked
			red_box = new Clutter.Actor ();
			red_box.set_size (100, 100);
			red_box.background_color = { 255, 0, 0, 255 };
			red_box.reactive = true;
			red_box.button_press_event.connect (turn_green);

			// we want to place it in the lower right of the primary monitor with a bit
			// of padding. refer to vapi/libmutter.vapi in gala's source for something
			// remotely similar to a documentation
			var screen = wm.get_screen ();
			var rect = screen.get_monitor_geometry (screen.get_primary_monitor ());

			red_box.x = rect.x + rect.width - red_box.width - PADDING;
			red_box.y = rect.y + rect.height - red_box.height - PADDING;

			// to order Gala to deliver mouse events to our box instead of the underlying
			// windows, we need to mark the region where the quad is located. We do so
			// by setting the region property. If you have multiple areas, you can just
			// put more rectangle in this array.
			// Gala will listen to updates on this property and update all the areas
			// any time this changes for any plugin, so don't change this excessively like
			// for example if you play an animation, only set the area on the destination
			// point of the animation instead of making it follow the animated element.
			X.Xrectangle red_box_area = {
				(short)red_box.x, (short)red_box.y,
				(short)red_box.width, (short)red_box.height
			};
			region = { red_box_area };

			// now we'll add our box into the ui_group. This is where all the shell
			// elements and also the windows and backgrouds are located.
			wm.ui_group.add_child (red_box);
		}

		bool turn_green (Clutter.ButtonEvent event)
		{
			red_box.background_color = { 0, 255, 0, 255 };
			return true;
		}

		// This function is actually not even called by Gala at the moment,
		// still it might be a good idea to implement it anyway to make sure
		// your plugin is compatible in case we'd add disabling specific plugins
		// in the future
		public void destroy ()
		{
			// here you would destroy actors you added to the stage or remove
			// keybindings

			red_box.destroy ();
		}
	}
}

// this little function just tells Gala which class of those you may have in
// your plugin is the one you want to start with. Make sure it's public and
// returning the type of the right class
public Type register_plugin ()
{
	return typeof (Gala.Plugins.Template.Main);
}

/*

Some more useful stuff:

Modal Mode
----------
If you want to display large elements that can be toggled instead of small overlays,
you can use wm.begin_modal() to make Gala enter modal mode. In this mode, you'll be
able to receive key events and all mouse events will be delivered regardless of the
region you have set. Don't forget to call wm.end_modal() and provide an obvious way
to exit modal mode for the user, otherwise he will be stuck and can only restart
Gala.

Keybindings
-----------
To add keybindings, you'll need a gsettings schema. You can take a look at Gala's
schema in data/org.pantheon.desktop.gschema.xml for an example. You'll also find
how to correctly declare shortcut keys in that file. Once you got this file ready
it's pretty easy. Just enable its installation in cmake, the relevant is commented
out in this template, and call wm.get_screen().get_display().add_keybinding().
The keybinding function takes the name of the shortcut key in your 
schema, then a GSettings instance for that schema, which can be obtained with
'new GLib.Settings("org.pantheon.gala.plugins.my-plugin")', then some flags, for
which you can almost always use 0, refer to the vapi for more details, and finally
your function as arguments. Its delegate is:

public delegate void KeyHandlerFunc (Meta.Display display, Meta.Screen screen,
	Meta.Window? window, X.Event event, Meta.KeyBinding binding);

So it'd be something like

void initialize (Gala.WindowManager wm)
{
	[...]
	var display = wm.get_screen ().get_display ();
	var schema = new GLib.Settings ("org.pantheon.desktop.gala.plugins");
	display.add_keybinding ("my-shortcut", schema, 0, my_handler);
	[...]
}
void my_handler (Meta.Display display, Meta.Screen screen, Meta.Window? window,
	X.Event event, Meta.KeyBinding binding)
{
	print ("Shortcut hit! D:");
}
void destroy ()
{
	wm.get_screen ().get_display ().remove_keybinding ("my-shortcut");
}

Overriding default keybindings
------------------------------
Libmutter allows you to override exisiting shortcuts, which is a lot easier than
adding new ones. All you have to do is:

Keybinding.set_custom_handler ("shortcut-name", my_handler);

The signature for my_handler is the same as above.

More info
---------
A great source for exploring the possibilities of mutter's API is scrolling through
the mentioned mutter vapi. In some cases you can find documentation on particular
functions in the mutter source code. Just grep for their C names.

*/

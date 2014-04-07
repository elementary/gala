//  
//  Copyright (C) 2014 Tom Beckmann
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

// docs taken from unity indicator-session's
// src/backend-dbus/org.gnome.SessionManager.EndSessionDialog.xml

namespace Gala
{
	[DBus (name = "org.gnome.SessionManager.EndSessionDialog")]
	public class EndSessionDialog : Clutter.Actor
	{
		[DBus (visible = false)]
		public static void register (WindowManager wm)
		{
			Bus.own_name (BusType.SESSION, "com.canonical.Unity",
				BusNameOwnerFlags.REPLACE, (connection) => {
					connection.register_object ("/org/gnome/SessionManager/EndSessionDialog",
						new EndSessionDialog (wm));
				},
				() => { },
				() => { warning ("Could not acquire Unity bus."); });
		}

		public signal void confirmed_logout ();
		public signal void confirmed_reboot ();
		public signal void confirmed_shutdown ();
		public signal void canceled ();
		public signal void closed ();

		[DBus (visible = false)]
		public WindowManager wm { get; construct set; }

		public EndSessionDialog (WindowManager wm)
		{
			Object (wm: wm);

			background_color = { 0, 0, 0, 255 };

			opacity = 0;

			add_constraint (new Clutter.BindConstraint (wm.stage, Clutter.BindCoordinate.SIZE, 0));
		}

		/**
		 * This function opens a dialog which asks the user for confirmation
		 * a logout, poweroff or reboot action. The dialog has a timeout
		 * after which the action is automatically taken, and it should show
		 * the inhibitors to the user.
		 *
		 * @param type                   The type of dialog to show.
		 *                               0 for logout, 1 for shutdown, 2 for restart.
		 * @param timestamp              Timestamp of the user-initiated event which
		 *                               triggered the call, or 0 if the call was not
		 *                               triggered by an event.
		 * @param seconds_to_stay_open   The number of seconds which the dialog should
		 *                               stay open before automatic action is taken.
		 * @param inhibitor_object_paths The object paths of all inhibitors that
		 *                               are registered for the action.
		 */
		public void open (uint type, uint timestamp, uint seconds_to_stay_open,
			ObjectPath[] inhibitor_object_paths) throws Error
		{
			// note on the implementation: the unity indicator currently does not use
			// the seconds_to_stay_open and inhibitor_object_paths parameters, so we
			// ignore them here for now as well.

			wm.ui_group.insert_child_below (this, wm.top_window_group);

			animate (Clutter.AnimationMode.EASE_OUT_QUAD, 600, opacity: 80);

			var dialog = new Dialog (type);
			dialog.show_all ();
			dialog.destroy.connect (() => {
				animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, opacity: 0)
					.completed.connect (() => { wm.ui_group.remove_child (this); });
			});
			dialog.confirmed_logout.connect (() => { confirmed_logout (); });
			dialog.confirmed_shutdown.connect (() => { confirmed_shutdown (); });
			dialog.confirmed_reboot.connect (() => { confirmed_reboot (); });
		}

		class Dialog : Gtk.Dialog
		{
			public signal void confirmed_logout ();
			public signal void confirmed_shutdown ();
			public signal void confirmed_reboot ();

			public Dialog (uint type)
			{
				Object (type: Gtk.WindowType.POPUP);

				string icon_name = "";
				string heading_text = "";
				string button_text = "";

				// the restart type is currently used by the indicator for what is
				// labelled shutdown because of unity's implementation of it 
				// apparently. So we got to adjust to that until they fix this.
				switch (type) {
					case 0: // logout
						icon_name = "system-log-out";
						heading_text = _("Are you sure you want to Log Out?");
						button_text = _("Log Out");
						break;
					case 1: // shutdown
					case 2: // restart
						icon_name = "system-shutdown";
						heading_text = _("Are you sure you want to Shut Down?");
						button_text = _("Shut Down");
						break;
					/*case 2: // restart
						icon_name = "system-reboot";
						heading_text = _("Are you sure you want to Restart?");
						button_text = _("Restart");
						break;*/
				}

				set_position (Gtk.WindowPosition.CENTER_ALWAYS);

				var heading = new Gtk.Label ("<span weight='bold' size='larger'>" +
					heading_text + "</span>");
				heading.get_style_context ().add_class ("larger");
				heading.use_markup = true;
				heading.xalign = 0;

				var grid = new Gtk.Grid ();
				grid.column_spacing = 12;
				grid.row_spacing = 12;
				grid.margin_left = grid.margin_right = grid.margin_bottom = 12;
				grid.attach (new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.DIALOG), 0, 0, 1, 2);
				grid.attach (heading, 1, 0, 1, 1);
				grid.attach (new Gtk.Label (_("This will close any open app and turn off your device.")), 1, 1, 1, 1);

				// the indicator does not have a separate item for restart, that's
				// why we show both shutdown and restart for the restart action
				// (which is sent for shutdown as described above)
				if (type == 2) {
					var confirm_restart = add_button (_("Restart"), Gtk.ResponseType.OK) as Gtk.Button;
					confirm_restart.clicked.connect (() => {
						confirmed_reboot ();
						close_dialog ();
					});
				}

				var cancel = add_button (_("Cancel"), Gtk.ResponseType.CANCEL) as Gtk.Button;
				cancel.clicked.connect (close_dialog);

				var confirm = add_button (button_text, Gtk.ResponseType.OK) as Gtk.Button;
				confirm.get_style_context ().add_class ("destructive-action");
				confirm.clicked.connect (() => {
					if (type == 2 || type == 1)
						confirmed_shutdown ();
					else
						confirmed_logout ();
					close_dialog ();
				});

				get_content_area ().add (grid);

				var action_area = get_action_area ();
				action_area.margin_right = 6;
				action_area.margin_bottom = 6;

				map.connect (() => {
					Gdk.pointer_grab (get_window (), true, Gdk.EventMask.BUTTON_PRESS_MASK
						| Gdk.EventMask.BUTTON_RELEASE_MASK
						| Gdk.EventMask.POINTER_MOTION_MASK,
						null, null, 0);
					Gdk.keyboard_grab (get_window (), true, 0);
				});
			}

			public void close_dialog ()
			{
				Gdk.pointer_ungrab (0);
				Gdk.keyboard_ungrab (0);

				destroy ();
			}
		}
	}
}



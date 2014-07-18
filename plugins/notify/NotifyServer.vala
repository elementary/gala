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

using Meta;

namespace Gala.Plugins.Notify
{
	[CCode (cname = "get_pixbuf_from_dbus_variant")]
	public extern Gdk.Pixbuf get_pixbuf_from_dbus_variant (Variant variant);

	public enum NotificationUrgency {
		LOW = 0,
		NORMAL = 1,
		CRITICAL = 2
	}

	[DBus (name = "org.freedesktop.DBus")]
	private interface DBus : Object
	{
		[DBus (name = "GetConnectionUnixProcessID")]
		public abstract uint32 get_connection_unix_process_id (string name) throws Error;
	}

	[DBus (name = "org.freedesktop.Notifications")]
	public class NotifyServer : Object
	{
		const int DEFAULT_TMEOUT = 4000;
		const string FALLBACK_ICON = "dialog-information";

		[DBus (visible = false)]
		public signal void show_notification (Notification notification);

		[DBus (visible = false)]
		public signal void notification_closed (uint32 id);

		[DBus (visible = false)]
		public NotificationStack stack { get; construct; }

		uint32 id_counter = 0;

		DBus? bus_proxy = null;

		public NotifyServer (NotificationStack stack)
		{
			Object (stack: stack);

			try {
				bus_proxy = Bus.get_proxy_sync (BusType.SESSION, "org.freedesktop.DBus", "/");
			} catch (Error e) {
				warning (e.message);
				bus_proxy = null;
			}
		}

		public void close_notification (uint32 id)
		{
			notification_closed (id);
		}

		public string [] get_capabilities ()
		{
			return {
				"body",
				"body-markup",
				"x-canonical-private-synchronous",
				"x-canonical-private-icon-only"
			};
		}

		public void get_server_information (out string name, out string vendor,
			out string version, out string spec_version)
		{
			name = "pantheon-notify";
			vendor = "elementaryOS";
			version = "0.1";
			spec_version = "1.1";
		}

		public new uint32 notify (string app_name, uint32 replaces_id, string app_icon, string summary, 
			string body, string[] actions, HashTable<string, Variant> hints, int32 expire_timeout, BusName sender)
		{
			var id = replaces_id != 0 ? replaces_id : ++id_counter;
			var pixbuf = get_pixbuf (hints, app_name, app_icon);
			var timeout = expire_timeout == uint32.MAX ? DEFAULT_TMEOUT : expire_timeout;
			var urgency = hints.contains ("urgency") ?
				(NotificationUrgency) hints.lookup ("urgency").get_byte () : NotificationUrgency.NORMAL;

			var icon_only = hints.contains ("x-canonical-private-icon-only");
			var confirmation = hints.contains ("x-canonical-private-synchronous");
			var progress = confirmation && hints.contains ("value");

#if true //debug notifications
			print ("Notification from '%s', replaces: %u\n" +
				"\tapp icon: '%s'\n\tsummary: '%s'\n\tbody: '%s'\n\tn actions: %u\n\texpire: %i\n\tHints:\n",
				app_name, replaces_id, app_icon, summary, body, actions.length);
			hints.@foreach ((key, val) => {
				print ("\t\t%s => %s\n", key, val.is_of_type (VariantType.STRING) ?
					val.get_string () : "<" + val.get_type ().dup_string () + ">");
			});
#endif

			uint32 pid = 0;
			try {
				pid = bus_proxy.get_connection_unix_process_id (sender);
			} catch (Error e) { warning (e.message); }

			foreach (var child in stack.get_children ()) {
				unowned Notification notification = (Notification) child;

				if (notification.id == id && !notification.being_destroyed) {
					var normal_notification = notification as NormalNotification;
					var confirmation_notification = notification as ConfirmationNotification;

					if (normal_notification != null)
						normal_notification.update (summary, body, pixbuf, expire_timeout, actions);

					if (confirmation_notification != null)
						confirmation_notification.update (pixbuf,
							progress ? hints.@get ("value").get_int32 () : 0);

					return id;
				}
			}

			Notification notification;
			if (confirmation)
				notification = new ConfirmationNotification (id, pixbuf,
					progress ? hints.@get ("value").get_int32 () : -1);
			else
				notification = new NormalNotification (stack.screen, id, summary, body, pixbuf,
					urgency, timeout, pid, actions);

			stack.show_notification (notification);

			return id;
		}

		Gdk.Pixbuf? get_pixbuf (HashTable<string, Variant> hints, string app, string icon)
		{
			// decide on the icon, order:
			// - image-data
			// - image-path
			// - app_icon
			// - icon_data
			// - from app name?
			// - fallback to dialog-information

			Gdk.Pixbuf? pixbuf = null;
			var size = Notification.ICON_SIZE;

			if (hints.contains ("image_data") || hints.contains ("image-data")) {

				var image = hints.contains ("image_data") ?
					hints.lookup ("image_data") : hints.lookup ("image-data");

				pixbuf = get_pixbuf_from_dbus_variant (image);

				pixbuf = pixbuf.scale_simple (size, size, Gdk.InterpType.HYPER);

			} else if (hints.contains ("image-path") || hints.contains ("image_path")) {

				var image_path = (hints.contains ("image-path") ?
					hints.lookup ("image-path") : hints.lookup ("image_path")).get_string ();

				try {
					if (image_path.has_prefix ("file://") || image_path.has_prefix ("/")) {
						var file_path = File.new_for_commandline_arg (image_path).get_path ();
						pixbuf = new Gdk.Pixbuf.from_file_at_scale (file_path, size, size, true);
					} else {
						pixbuf = Gtk.IconTheme.get_default ().load_icon (image_path, size, 0);
					}
				} catch (Error e) { warning (e.message); }

			} else if (icon != "") {

				var actual_icon = icon;
				// fix icon names that are sent to notify-osd to the ones that actually exist
				if (icon.has_prefix ("notification-"))
					actual_icon = icon.substring (13) + "-symbolic";

				try {
					pixbuf = Gtk.IconTheme.get_default ().load_icon (actual_icon, size, 0);
				} catch (Error e) { warning (e.message); }

			} else if (hints.contains ("icon_data")) {
				warning ("icon data is not supported");
			}

			if (pixbuf == null) {

				try {
					pixbuf = Gtk.IconTheme.get_default ().load_icon (app.down (), size, 0);
				} catch (Error e) {

					try {
						pixbuf = Gtk.IconTheme.get_default ().load_icon (FALLBACK_ICON, size, 0);
					} catch (Error e) { warning (e.message); }
				}
			}

			return pixbuf;
		}
	}
}


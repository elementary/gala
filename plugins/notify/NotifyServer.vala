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
		public signal void show_notification (uint32 id, string summary, string body, Gdk.Pixbuf? icon,
			NotificationUrgency urgency, int32 expire_timeout, uint32 sender_pid, string[] actions);

		[DBus (visible = false)]
		public signal void notification_closed (uint32 id);

		uint32 id_counter = 0;

		DBus? bus_proxy = null;

		public NotifyServer ()
		{
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
			return { "body", "body-markup" };
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

			uint32 pid = 0;
			try {
				pid = bus_proxy.get_connection_unix_process_id (sender);
			} catch (Error e) { warning (e.message); }

			show_notification (id, summary, body, pixbuf, urgency, timeout, pid, actions);

			return id_counter;
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

				try {
					pixbuf = Gtk.IconTheme.get_default ().load_icon (icon, size, 0);
				} catch (Error e) {}

			} else if (hints.contains ("icon_data")) {
				print ("IMPLEMENT ICON_DATA!!!!!!!!\n");

				Gdk.Pixdata data = {};
				try {
					if (data.deserialize ((uint8[])hints.lookup ("icon_data").get_data ()))
						pixbuf = Gdk.Pixbuf.from_pixdata (data);
					else
						warning ("Error while deserializing icon_data");
				} catch (Error e) { warning (e.message); }
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


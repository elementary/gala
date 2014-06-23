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
	public enum NotificationUrgency {
		LOW = 0,
		NORMAL = 1,
		CRITICAL = 2
	}

	[DBus (name="org.freedesktop.Notifications")]
	public class NotifyServer : Object
	{
		const int DEFAULT_TMEOUT = 3000;
		const string FALLBACK_ICON = "dialog-information";

		[DBus (visible = false)]
		public signal void show_notification (uint32 id, string summary, string body, Gdk.Pixbuf? icon,
			NotificationUrgency urgency, int32 expire_timeout, Window? window, string[] actions);

		[DBus (visible = false)]
		public signal void notification_closed (uint32 id);

		uint32 id_counter = 0;

		public NotifyServer ()
		{
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
			string body, string[] actions, HashTable<string, Variant> hints, int32 expire_timeout, BusName name)
		{
			var id = replaces_id != 0 ? replaces_id : ++id_counter;
			var pixbuf = get_pixbuf (hints, app_name, app_icon);
			var window = get_window ();
			var timeout = expire_timeout == uint32.MAX ? DEFAULT_TMEOUT : expire_timeout;
			var urgency = hints.contains ("urgency") ?
				(NotificationUrgency) hints.lookup ("urgency").get_byte () : NotificationUrgency.NORMAL;

			show_notification (id, summary, body, pixbuf, urgency, timeout, window, actions);

			return id_counter;
		}

		Window? get_window ()
		{
			return null;
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

			if (hints.contains ("image_data")) {

				int width;
				int height;
				int rowstride;
				bool has_alpha;
				int bits_per_sample;
				int channels;
				weak Array<uint8> data;

				hints.lookup ("image_data").get ("(iiibiiay)", out width, out height, out rowstride,
					out has_alpha, out bits_per_sample, out channels, out data, uint.MAX);

				pixbuf = new Gdk.Pixbuf.from_data ((uint8[])data, Gdk.Colorspace.RGB, has_alpha,
					bits_per_sample, width, height, rowstride, null);

				pixbuf = pixbuf.scale_simple (size, size, Gdk.InterpType.HYPER);

			} else if (hints.contains ("image-path")) {

				var image_path = hints.lookup ("image-path").get_string ();

				try {
					if (image_path.has_prefix ("file://")) {
						pixbuf = new Gdk.Pixbuf.from_file_at_scale (image_path, size, size, true);
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

				/*Gdk.Pixdata data = {};
				try {
					if (data.deserialize ((uint8[])hints.lookup ("image-data").get_data ()))
						tex.set_from_pixbuf (Gdk.Pixbuf.from_pixdata (data));
					else
						warning ("Error while deserializing icon_data");
				} catch (Error e) { warning (e.message); }*/
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


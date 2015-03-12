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
	public enum NotificationUrgency
	{
		LOW = 0,
		NORMAL = 1,
		CRITICAL = 2
	}

	public enum NotificationClosedReason
	{
		EXPIRED = 1,
		DISMISSED = 2,
		CLOSE_NOTIFICATION_CALL = 3,
		UNDEFINED = 4
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

		public signal void notification_closed (uint32 id, uint32 reason);
		public signal void action_invoked (uint32 id, string action_key);

		[DBus (visible = false)]
		public NotificationStack stack { get; construct; }

		uint32 id_counter = 0;

		DBus? bus_proxy = null;
		unowned Canberra.Context? ca_context = null;

		public NotifyServer (NotificationStack stack)
		{
			Object (stack: stack);
		}

		construct
		{
			try {
				bus_proxy = Bus.get_proxy_sync (BusType.SESSION, "org.freedesktop.DBus", "/");
			} catch (Error e) {
				warning (e.message);
				bus_proxy = null;
			}

			var locale = Intl.setlocale (LocaleCategory.MESSAGES, null);
			ca_context = CanberraGtk.context_get ();
			ca_context.change_props (Canberra.PROP_APPLICATION_NAME, "Gala",
			                         Canberra.PROP_APPLICATION_ID, "org.pantheon.gala",
			                         Canberra.PROP_APPLICATION_NAME, "start-here",
			                         Canberra.PROP_APPLICATION_LANGUAGE, locale,
			                         null);
			ca_context.open ();
		}

		public string [] get_capabilities ()
		{
			return {
				"body",
				"body-markup",
				"sound",
				// even though we don't fully support actions, we still want to receive the default
				// action. Well written applications will check if the actions capability is available
				// before settings a default action, so we have to specify it here. Also, not displaying
				// certain actions even though requested is allowed according to spec, so we should be fine
				"actions",
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

		/**
		 * Implementation of the CloseNotification DBus method
		 *
		 * @param id The id of the notification to be closed.
		 */
		public void close_notification (uint32 id) throws DBusError
		{
			foreach (var child in stack.get_children ()) {
				unowned Notification notification = (Notification) child;
				if (notification.id != id)
					continue;

				notification_closed_callback (notification, id,
					NotificationClosedReason.CLOSE_NOTIFICATION_CALL);
				notification.close ();

				return;
			}

			// according to spec, an empty dbus error should be sent if the notification
			// doesn't exist (anymore)
			throw new DBusError.FAILED ("");
		}

		public new uint32 notify (string app_name, uint32 replaces_id, string app_icon, string summary, 
			string body, string[] actions, HashTable<string, Variant> hints, int32 expire_timeout, BusName sender)
		{
			Variant? variant;

			var id = replaces_id != 0 ? replaces_id : ++id_counter;
			var pixbuf = get_pixbuf (app_name, app_icon, hints);
			var timeout = expire_timeout == uint32.MAX ? DEFAULT_TMEOUT : expire_timeout;

			var urgency = NotificationUrgency.NORMAL;
			if ((variant = hints.lookup ("urgency")) != null)
				urgency = (NotificationUrgency) variant.get_byte ();

			var icon_only = hints.contains ("x-canonical-private-icon-only");
			var confirmation = hints.contains ("x-canonical-private-synchronous");
			var progress = confirmation && hints.contains ("value");

			unowned NotifySettings options = NotifySettings.get_default ();

			// Default values for confirmations
			var allow_bubble = true;
			var allow_sound = true;

			if (!confirmation) {
				var app_found = false;

				var param_bubbles = (options.default_bubbles ? "show" : "hide");
				var param_sounds = (options.default_sounds ? "on" : "off");

				for (int i = 0; i < options.apps.length; i++) {
					var properties = options.apps[i].split (":");

					// Don't crash! (If this entry is invalid search for another or create a new one)
					if (properties.length == 2) {
						if (properties[0] == app_name) {
							var parameters = properties[1].split (",");

							if (parameters.length == 2) {
								param_bubbles = parameters[0];
								param_sounds = parameters[1];

								app_found = true;

								break;
							}
						}
					}
				}

				if (!app_found) {
					// if no matching app was found, add the default values to the list
					var apps_new = new string[options.apps.length + 1];

					for (int i = 0; i < options.apps.length; i++) {
						apps_new[i] = options.apps[i];
					}

					apps_new[options.apps.length] = app_name + ":" + param_bubbles + "," + param_sounds;

					options.apps = apps_new;
				}

				allow_bubble = (!options.do_not_disturb && param_bubbles == "show");
				allow_sound = (allow_bubble && param_sounds == "on");
			}

#if 0 // enable to debug notifications
			print ("Notification from '%s', replaces: %u\n" +
				"\tapp icon: '%s'\n\tsummary: '%s'\n\tbody: '%s'\n\tn actions: %u\n\texpire: %i\n\tHints:\n",
				app_name, replaces_id, app_icon, summary, body, actions.length);
			hints.@foreach ((key, val) => {
				print ("\t\t%s => %s\n", key, val.is_of_type (VariantType.STRING) ?
					val.get_string () : "<" + val.get_type ().dup_string () + ">");
			});
			print ("\tActions: ");
			foreach (var action in actions) {
				print ("%s, ", action);
			}
			print ("\n");
#endif

			uint32 pid = 0;
			try {
				pid = bus_proxy.get_connection_unix_process_id (sender);
			} catch (Error e) { warning (e.message); }

			if (allow_sound)
				handle_sounds (hints);

			foreach (var child in stack.get_children ()) {
				unowned Notification notification = (Notification) child;

				if (notification.being_destroyed)
					continue;

				// we only want a single confirmation notification, so we just take the
				// first one that can be found, no need to check ids or anything
				unowned ConfirmationNotification? confirmation_notification = notification as ConfirmationNotification;
				if (confirmation
					&& confirmation_notification != null) {

					// value may be -1 for a muted state, but -1 is interpreted as no progress set by the
					// ConfirmationNotification class, so if we do have a progress, we make sure it's set
					// to 0 for a muted state.
					var progress_value = progress ? int.max (hints.@get ("value").get_int32 (), 0) : -1;

					confirmation_notification.update (pixbuf,
						progress_value,
						hints.@get ("x-canonical-private-synchronous").get_string (),
						icon_only);

					return id;
				}

				unowned NormalNotification? normal_notification = notification as NormalNotification;
				if (!confirmation
					&& notification.id == id
					&& normal_notification != null) {

					normal_notification.update (summary, body, pixbuf, timeout, actions);

					return id;
				}
			}

			if (allow_bubble) {
				Notification notification;
				if (confirmation)
					notification = new ConfirmationNotification (id, pixbuf, icon_only,
						progress ? hints.@get ("value").get_int32 () : -1,
						hints.@get ("x-canonical-private-synchronous").get_string ());
				else
					notification = new NormalNotification (stack.screen, id, summary, body, pixbuf,
						urgency, timeout, pid, actions);

				notification.action_invoked.connect (notification_action_invoked_callback);
				notification.closed.connect (notification_closed_callback);
				stack.show_notification (notification);
			}

#if !VALA_0_26
			// fixes memleaks as described in https://bugzilla.gnome.org/show_bug.cgi?id=698260
			// valac >= 0.26 already has this fix
			hints.@foreach ((key, val) => {
				g_variant_unref (val);
			});
#endif

			return id;
		}

		static Gdk.Pixbuf? get_pixbuf (string app_name, string app_icon, HashTable<string, Variant> hints)
		{
			// decide on the icon, order:
			// - image-data
			// - image-path
			// - app_icon
			// - icon_data
			// - from app name?
			// - fallback to dialog-information

			Gdk.Pixbuf? pixbuf = null;
			Variant? variant = null;
			var size = Notification.ICON_SIZE;
			var mask_offset = 4;
			var mask_size_offset = mask_offset * 2;
			var has_mask = false;

			if ((variant = hints.lookup ("image-data")) != null
				|| (variant = hints.lookup ("image_data")) != null
				|| (variant = hints.lookup ("icon_data")) != null) {

				has_mask = true;
				size = size - mask_size_offset;

				pixbuf = load_from_variant_at_size (variant, size);

			} else if ((variant = hints.lookup ("image-path")) != null
				|| (variant = hints.lookup ("image_path")) != null) {

				var image_path = variant.get_string ();

				try {
					if (image_path.has_prefix ("file://") || image_path.has_prefix ("/")) {
						has_mask = true;
						size = size - mask_size_offset;

						var file_path = File.new_for_commandline_arg (image_path).get_path ();
						pixbuf = new Gdk.Pixbuf.from_file_at_scale (file_path, size, size, true);
					} else {
						pixbuf = Gtk.IconTheme.get_default ().load_icon (image_path, size, 0);
					}
				} catch (Error e) { warning (e.message); }

			} else if (app_icon != "") {

				try {
					var themed = new ThemedIcon.with_default_fallbacks (app_icon);
					var info = Gtk.IconTheme.get_default ().lookup_by_gicon (themed, size, 0);
					if (info != null)
						pixbuf = info.load_icon ();
				} catch (Error e) { warning (e.message); }

			}

			if (pixbuf == null) {

				try {
					pixbuf = Gtk.IconTheme.get_default ().load_icon (app_name.down (), size, 0);
				} catch (Error e) {

					try {
						pixbuf = Gtk.IconTheme.get_default ().load_icon (FALLBACK_ICON, size, 0);
					} catch (Error e) { warning (e.message); }
				}
			} else if (has_mask) {
				var mask_size = Notification.ICON_SIZE;
				var offset_x = mask_offset;
				var offset_y = mask_offset + 1;

				var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, mask_size, mask_size);
				var cr = new Cairo.Context (surface);

				Granite.Drawing.Utilities.cairo_rounded_rectangle (cr,
					offset_x, offset_y, size, size, 4);
				cr.clip ();

				Gdk.cairo_set_source_pixbuf (cr, pixbuf, offset_x, offset_y);
				cr.paint ();

				cr.reset_clip ();

				var mask = new Cairo.ImageSurface.from_png (Config.PKGDATADIR + "/image-mask.png");
				cr.set_source_surface (mask, 0, 0);
				cr.paint ();

				pixbuf = Gdk.pixbuf_get_from_surface (surface, 0, 0, mask_size, mask_size);
			}

			return pixbuf;
		}

		static Gdk.Pixbuf? load_from_variant_at_size (Variant variant, int size)
		{
			if (!variant.is_of_type (new VariantType ("(iiibiiay)"))) {
				critical ("notify icon/image-data format invalid");
				return null;
			}

			int width, height, rowstride, bits_per_sample, n_channels;
			bool has_alpha;

			variant.get ("(iiibiiay)", out width, out height, out rowstride,
				out has_alpha, out bits_per_sample, out n_channels, null);

			var data = variant.get_child_value (6);
			unowned uint8[] pixel_data = (uint8[]) data.get_data ();

			var pixbuf = new Gdk.Pixbuf.with_unowned_data (pixel_data, Gdk.Colorspace.RGB, has_alpha,
				bits_per_sample, width, height, rowstride, null);

			return pixbuf.scale_simple (size, size, Gdk.InterpType.BILINEAR);
		}

		void handle_sounds (HashTable<string,Variant> hints)
		{
			if (ca_context == null)
				return;

			Variant? variant = null;

			// Are we suppose to play a sound at all?
			if ((variant = hints.lookup ("supress-sound")) != null
				&& variant.get_boolean ())
				return;

			Canberra.Proplist props;
			Canberra.Proplist.create (out props);
			props.sets (Canberra.PROP_CANBERRA_CACHE_CONTROL, "volatile");

			bool play_sound = false;

			// no sounds for confirmation bubbles
			if ((variant = hints.lookup ("x-canonical-private-synchronous")) != null) {
				var confirmation_type = variant.get_string ();

				// the sound indicator is an exception here, it won't emit a sound at all, even though for
				// consistency it should. So we make it emit the default one.
				if (confirmation_type != "indicator-sound")
					return;

				props.sets (Canberra.PROP_EVENT_ID, "audio-volume-change");
				play_sound = true;
			}

			if ((variant = hints.lookup ("sound-name")) != null) {
				props.sets (Canberra.PROP_EVENT_ID, variant.get_string ());
				play_sound = true;
			}

			if ((variant = hints.lookup ("sound-file")) != null) {
				props.sets (Canberra.PROP_MEDIA_FILENAME, variant.get_string ());
				play_sound = true;
			}

			// pick a sound according to the category
			if (!play_sound) {
				variant = hints.lookup ("category");
				string? sound_name = null;

				if (variant != null)
					sound_name = category_to_sound (variant.get_string ());
				else
					sound_name = "dialog-information";

				if (sound_name != null) {
					props.sets (Canberra.PROP_EVENT_ID, sound_name);
					play_sound = true;
				}
			}

			if (play_sound)
				ca_context.play_full (0, props);
		}

		static string? category_to_sound (string category)
		{
			string? sound = null;

			switch (category) {
				case "device.added":
					sound = "device-added";
					break;
				case "device.removed":
					sound = "device-removed";
					break;
				case "im":
					sound = "message";
					break;
				case "im.received":
					sound = "message-new-instant";
					break;
				case "network.connected":
					sound = "network-connectivity-established";
					break;
				case "network.disconnected":
					sound = "network-connectivity-lost";
					break;
				case "presence.online":
					sound = "service-login";
					break;
				case "presence.offline":
					sound = "service-logout";
					break;
				// no sound at all
				case "x-gnome.music":
					sound = null;
					break;
				// generic errors
				case "device.error":
				case "email.bounced":
				case "im.error":
				case "network.error":
				case "transfer.error":
					sound = "dialog-error";
					break;
				// use generic default
				case "network":
				case "email":
				case "email.arrived":
				case "presence":
				case "transfer":
				case "transfer.complete":
				default:
					sound = "dialog-information";
					break;
			}

			return sound;
		}

		void notification_closed_callback (Notification notification, uint32 id, uint32 reason)
		{
			notification.action_invoked.disconnect (notification_action_invoked_callback);
			notification.closed.disconnect (notification_closed_callback);

			notification_closed (id, reason);
		}

		void notification_action_invoked_callback (Notification notification, uint32 id, string action)
		{
			action_invoked (id, action);
		}
	}
}

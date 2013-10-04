//  
//  Copyright (C) 2013 Tom Beckmann, Rico Tzschichholz
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

namespace Gala
{
	public delegate void PendingFileLoadFinished (Object userdata, Meta.Background? content);

	struct PendingFileLoad
	{
		string filename;
		GDesktop.BackgroundStyle style;
		Gee.LinkedList<PendingFileLoadCaller?> callers;
	}

	struct PendingFileLoadCaller
	{
		bool should_copy;
		int monitor_index;
		Meta.BackgroundEffects effects;
		PendingFileLoadFinished on_finished;
		Object userdata;
	}

	public class BackgroundCache : Object
	{
		static BackgroundCache? instance = null;

		Meta.Screen screen;

		Gee.LinkedList<Meta.Background> patterns;
		Gee.LinkedList<Meta.Background> images;
		Gee.LinkedList<PendingFileLoad?> pending_file_loads;
		Gee.HashMap<string,FileMonitor> file_monitors;

		string animation_filename;
		Animation animation;

		public signal void file_changed (string filename);

		public BackgroundCache (Meta.Screen _screen)
		{
			screen = _screen;

			patterns = new Gee.LinkedList<Meta.Background> ();
			images = new Gee.LinkedList<Meta.Background> ();
			pending_file_loads = new Gee.LinkedList<PendingFileLoad?> ();
			file_monitors = new Gee.HashMap<string,FileMonitor> ();
		}

		public Meta.Background get_pattern_content (int monitor_index, Clutter.Color color,
			Clutter.Color second_color, GDesktop.BackgroundShading shading_type, Meta.BackgroundEffects effects)
		{
			Meta.Background? content = null, candidate_content = null;

			foreach (var pattern in patterns) {
				if (pattern == null)
					continue;

				if (pattern.get_shading() != shading_type)
					continue;

				if (color.equal(pattern.get_color ()))
					continue;

				if (shading_type != GDesktop.BackgroundShading.SOLID &&
					!second_color.equal(pattern.get_second_color ()))
					continue;

				candidate_content = pattern;

				if (effects != pattern.effects)
					continue;

				break;
			}

			if (candidate_content != null) {
				content = candidate_content.copy (monitor_index, effects);
			} else {
				content = new Meta.Background (screen, monitor_index, effects);

				if (shading_type == GDesktop.BackgroundShading.SOLID) {
					content.load_color (color);
				} else {
					content.load_gradient (shading_type, color, second_color);
				}
			}

			patterns.add (content);

			return content;
		}

		public void monitor_file (string filename)
		{
			if (file_monitors.has_key (filename))
				return;

			var file = File.new_for_path (filename);
			try {
				var monitor = file.monitor (FileMonitorFlags.NONE);

				//TODO maybe do this in a cleaner way
				ulong signal_id = 0;
				signal_id = monitor.changed.connect (() => {
					foreach (var image in images) {
						if (image.get_filename () == filename)
							images.remove (image);
					}

					monitor.disconnect (signal_id);

					file_changed (filename);
				});

				file_monitors.set (filename, monitor);
			} catch (Error e) { warning (e.message); }
		}

		public void remove_content (Gee.LinkedList<Meta.Background> content_list, Meta.Background content) {
			content_list.remove (content);
		}

		public void remove_pattern_content (Meta.Background content) {
			remove_content (patterns, content);
		}

		public void remove_image_content (Meta.Background content) {
			var filename = content.get_filename();

			if (filename != null && file_monitors.has_key (filename))
				//TODO disconnect filemonitor and delete it properly
				file_monitors.unset (filename);

			remove_content(images, content);
		}

		//FIXME as we may have to get a number of callbacks fired when this finishes,
		//	  we can't use vala's async system, but use a callback based system instead
		public void load_image_content (int monitor_index,
			GDesktop.BackgroundStyle style, string filename, Meta.BackgroundEffects effects,
			Object userdata, PendingFileLoadFinished on_finished, Cancellable? cancellable = null)
		{
			foreach (var pending_file_load in pending_file_loads) {
				if (pending_file_load.filename == filename &&
					pending_file_load.style == style) {
					pending_file_load.callers.add ({true, monitor_index, effects, on_finished, userdata});
					return;
				}
			}

			PendingFileLoad load = {filename, style, new Gee.LinkedList<PendingFileLoadCaller?> ()};
			load.callers.add ({false, monitor_index, effects, on_finished, userdata});
			pending_file_loads.add (load);

			var content = new Meta.Background (screen, monitor_index, effects);
			content.load_file_async.begin (filename, style, cancellable, (obj, res) => {
				try {
				  content.load_file_async.end (res);

				  monitor_file (filename);
				  images.add (content);
				} catch (Error e) {
				  content = null;
				}

				foreach (var pending_load in pending_file_loads) {
					if (pending_load.filename != filename ||
						pending_load.style != style)
						continue;

					foreach (var caller in pending_load.callers) {
						if (caller.on_finished != null) {
							if (content != null && caller.should_copy) {
								content = (obj as Meta.Background).copy (caller.monitor_index, caller.effects);
							}

							caller.on_finished (caller.userdata, content);
						}
					}

					pending_file_loads.remove (pending_load);
				}
			});
		}

		public void get_image_content (int monitor_index, GDesktop.BackgroundStyle style, 
			string filename, Meta.BackgroundEffects effects, Object userdata, 
			PendingFileLoadFinished on_finished, Cancellable? cancellable = null)
		{
			Meta.Background content = null, candidate_content = null;
			foreach (var image in images) {
				if (image == null)
					continue;

				if (image.get_style () != style)
					continue;

				if (image.get_filename () != filename)
					continue;

				if (style == GDesktop.BackgroundStyle.SPANNED &&
					image.monitor != monitor_index)
					continue;

				candidate_content = image;

				if (effects != image.effects)
					continue;

				break;
			}

			if (candidate_content != null) {
				content = candidate_content.copy (monitor_index, effects);

				if (cancellable != null && cancellable.is_cancelled ())
					content = null;
				else
					images.add (content);

				on_finished (userdata, content);
			} else {
				load_image_content (monitor_index, style, filename, effects, userdata, on_finished, cancellable);
			}
		}

		public async Animation get_animation (string filename)
		{
			Animation animation;

			if (animation_filename == filename) {
				animation = this.animation;

				//FIXME do we need those Idles?
				Idle.add (() => {
					get_animation.callback ();
					return false;
				});
			} else {
				animation = new Animation (screen, filename);

				yield animation.load ();

				monitor_file (filename);
				animation_filename = filename;
				this.animation = animation;

				Idle.add (() => {
					get_animation.callback ();
					return false;
				});
			}

			yield;
			return animation;
		}
		
		public static void init (Meta.Screen screen)
		{
			instance = new BackgroundCache (screen);
		}

		public static BackgroundCache get_default ()
		{
			return instance;
		}
	}
}


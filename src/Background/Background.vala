//  
//  Copyright (C) 2012 Tom Beckmann, Rico Tzschichholz
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

// Code has been ported from gnome-shell's js/ui/background.js

const string BACKGROUND_SCHEMA = "org.gnome.desktop.background";
const string PRIMARY_COLOR_KEY = "primary-color";
const string SECONDARY_COLOR_KEY = "secondary-color";
const string COLOR_SHADING_TYPE_KEY = "color-shading-type";
const string BACKGROUND_STYLE_KEY = "picture-options";
const string PICTURE_OPACITY_KEY = "picture-opacity";
const string PICTURE_URI_KEY = "picture-uri";

const uint FADE_ANIMATION_TIME = 1000;

// These parameters affect how often we redraw.
// The first is how different (percent crossfaded) the slide show
// has to look before redrawing and the second is the minimum
// frequency (in seconds) we're willing to wake up
const double ANIMATION_OPACITY_STEP_INCREMENT = 4.0;
const double ANIMATION_MIN_WAKEUP_INTERVAL = 1.0;

public class Background : Object
{
	public Meta.BackgroundEffects effects { get; construct set; }
	public Settings settings { get; construct set; }
	public int monitor_index { get; construct set; }

	public Meta.BackgroundGroup actor { get; private set; }
	public bool is_loaded { get; private set; }

	// those two are set by the BackgroundManager
	internal ulong change_signal_id = 0;
	internal ulong loaded_signal_id = 0;

	float _brightness;
	public float brightness {
		get {
			return _brightness;
		}
		set {
			_brightness = value;
			if (pattern != null && pattern.content != null)
				(pattern.content as Meta.Background).brightness = value;

			foreach (var image in images) {
				if (image != null && image.content != null)
					(image.content as Meta.Background).brightness = brightness;
			}
		}
	}

	float _vignette_sharpness;
	public float vignette_sharpness {
		get {
			return _vignette_sharpness;
		}
		set {
			_vignette_sharpness = value;
			if (pattern != null && pattern.content != null)
				(pattern.content as Meta.Background).vignette_sharpness = value;

			foreach (var image in images) {
				if (image != null && image.content != null)
					(image.content as Meta.Background).vignette_sharpness = vignette_sharpness;
			}
		}
	}

	GDesktop.BackgroundStyle style;

	Meta.BackgroundActor? pattern;
	BackgroundCache cache;

	Animation animation;

	Cancellable? cancellable = null;
	uint update_animation_timeout_id = 0;

	Meta.BackgroundActor images[2];
	Gee.HashMap<string,ulong> file_watches;

	string filename;
	uint num_pending_images;

	public signal void changed ();
	public signal void loaded ();

    public Background (int monitor_index, Meta.BackgroundEffects effects, Settings settings)
	{
		Object (monitor_index: monitor_index, effects: effects, settings: settings);
        actor = new Meta.BackgroundGroup ();

        file_watches = new Gee.HashMap<string,ulong> ();
        pattern = null;
        // contains a single image for static backgrounds and
        // two images (from and to) for slide shows
		images = { null, null };

        brightness = 1.0f;
        vignette_sharpness = 0.2f;
        cancellable = new Cancellable ();
        is_loaded = false;

        settings.changed.connect (() => {
			changed ();
		});

        load ();

		actor.destroy.connect (destroy);
    }

    public void destroy ()
	{
		if (cancellable != null)
			cancellable.cancel ();

        if (update_animation_timeout_id != 0) {
            Source.remove (update_animation_timeout_id);
            update_animation_timeout_id = 0;
        }

        foreach (var key in file_watches.keys) {
            cache.disconnect (file_watches.get (key));
        }
        file_watches = null;

        if (pattern != null) {
            if (pattern.content != null)
                cache.remove_pattern_content (pattern.content as Meta.Background);

            pattern.destroy ();
            pattern = null;
        }

		foreach (var image in images) {
			if (image == null)
				continue;

            if (image.content != null)
                cache.remove_image_content (image.content as Meta.Background);

            image.destroy ();
        }
    }

    public void set_loaded ()
	{
        if (is_loaded)
            return;

        is_loaded = true;

        Idle.add (() => {
			loaded ();
            return false;
        });
    }

    public void load_pattern ()
	{
        var color = Clutter.Color.from_string (settings.get_string (PRIMARY_COLOR_KEY));
        var second_color = Clutter.Color.from_string (settings.get_string (SECONDARY_COLOR_KEY));

        var shading_type = (GDesktop.BackgroundShading)settings.get_enum (COLOR_SHADING_TYPE_KEY);

        var content = cache.get_pattern_content (monitor_index, color, second_color, shading_type, effects);

        pattern = new Meta.BackgroundActor ();
        actor.add_child (pattern);

        pattern.content = content;
    }

    public void watch_cache_file (string filename)
	{
        if (file_watches.has_key (filename))
            return;

        var signal_id = cache.file_changed.connect ((changed_file) => {
			if (changed_file == filename) {
				changed ();
			}
		});

        file_watches.set (filename, signal_id);
    }

    public void add_image (Meta.Background content, int index, string filename) {
        content.brightness = brightness;
        content.vignette_sharpness = vignette_sharpness;

        var actor = new Meta.BackgroundActor ();
        actor.content = content;

        // The background pattern is the first actor in
        // the group, and all images should be above that.
        this.actor.insert_child_at_index (actor, index + 1);

        images[index] = actor;
        watch_cache_file (filename);
    }

    public void update_image (Meta.Background content, int index, string filename) {
        content.brightness = brightness;
        content.vignette_sharpness = vignette_sharpness;

        cache.remove_image_content (images[index].content as Meta.Background);
        images[index].content = content;
        watch_cache_file (filename);
    }

    public void update_animation_progress ()
	{
        if (images[1] != null)
            images[1].opacity = (uint)(animation.transition_progress * 255);

        queue_update_animation();
    }

    public void update_animation ()
	{
        update_animation_timeout_id = 0;

        animation.update (monitor_index);
        var files = animation.key_frame_files;

        if (files.size == 0) {
            set_loaded ();
            queue_update_animation ();
            return;
        }

        num_pending_images = files.size;
        for (var i = 0; i < files.size; i++) {
			var image = images[i];
            if (image != null && image.content != null &&
                (image.content as Meta.Background).get_filename () == files.get (i)) {

                num_pending_images--;
                if (num_pending_images == 0)
                    update_animation_progress ();

                continue;
            }

            cache.get_image_content (monitor_index, style, files[i], effects,
				this, get_update_animation_callback (i), cancellable);
        }
    }

	// FIXME wrap callback method to keep the i at the correct value, I suppose
	//       we should find a nicer way to do this
	PendingFileLoadFinished get_update_animation_callback (int i) {
		return (userdata, content) => {
			var self = userdata as Background;
			self.num_pending_images--;

			if (content == null) {
				self.set_loaded ();
				if (self.num_pending_images == 0)
					self.update_animation_progress ();
				return;
			}

			if (self.images[i] == null) {
				self.add_image (content, i, self.animation.key_frame_files.get (i));
			} else {
				self.update_image (content, i, self.animation.key_frame_files.get (i));
			}

			if (self.num_pending_images == 0) {
				self.set_loaded ();
				self.update_animation_progress ();
			}
		};
	}

    public void queue_update_animation ()
	{
        if (update_animation_timeout_id != 0)
            return;

        if (cancellable == null || cancellable.is_cancelled ())
            return;

        if (animation.transition_duration == 0.0)
            return;

        var n_steps = 255 / ANIMATION_OPACITY_STEP_INCREMENT;
        var time_per_step = (uint)((animation.transition_duration * 1000) / n_steps);

        var interval = uint.max ((uint)(ANIMATION_MIN_WAKEUP_INTERVAL * 1000), time_per_step);

        if (interval > uint.MAX)
            return;

		update_animation_timeout_id = Timeout.add (interval, () => {
			update_animation_timeout_id = 0;
			update_animation ();
			return false;
		});
    }

    public void load_animation (string filename)
	{
        cache.get_animation.begin (filename, (obj, res) => {
			animation = cache.get_animation.end (res);

			if (animation == null || cancellable.is_cancelled ()) {
				set_loaded ();
				return;
			}

			update_animation ();
			watch_cache_file (filename);
		});
    }

    public void load_file (string filename)
	{
		this.filename = filename;
        cache.get_image_content (monitor_index, style, filename, effects, this, (userdata, content) => {
			var self = userdata as Background;
			if (content == null) {
				if (!self.cancellable.is_cancelled ())
					self.load_animation (self.filename);
				return;
			}

			self.add_image (content, 0, self.filename);
			self.set_loaded ();
		}, cancellable);
    }

    public void load ()
	{
        cache = BackgroundCache.get_default ();

        load_pattern ();

        style = (GDesktop.BackgroundStyle)settings.get_enum (BACKGROUND_STYLE_KEY);
        if (style == GDesktop.BackgroundStyle.NONE) {
            set_loaded ();
            return;
        }

        var uri = settings.get_string (PICTURE_URI_KEY);
        string filename;
        if (Uri.parse_scheme (uri) != null)
            filename = File.new_for_uri (uri).get_path ();
        else
            filename = uri;

        if (filename == null) {
            set_loaded ();
            return;
        }

        load_file (filename);
    }
}

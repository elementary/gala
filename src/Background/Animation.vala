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

public class Animation : Object
{
	public string filename { get; construct set; }
	public Meta.Screen screen { get; construct set; }

	public Gee.LinkedList<string> key_frame_files { get; private set; }
	public double transition_progress { get; private set; default = 0.0; }
	public double transition_duration { get; private set; default = 0.0; }
	public bool loaded { get; private set; default = false; }

	Gnome.BGSlideShow? show = null;

	public Animation (Meta.Screen screen, string filename)
	{
		Object (filename: filename, screen: screen);
		key_frame_files = new Gee.LinkedList<string> ();
	}

	public async void load ()
	{
		show = new Gnome.BGSlideShow (filename);

		//FIXME yield show.load_async (null);
		show.load ();
		loaded = true;
	}

	public void update (int monitor_index)
	{
		key_frame_files = new Gee.LinkedList<string> ();

		if (show == null)
			return;

		if (show.get_num_slides () < 1)
			return;

		var monitor = screen.get_monitor_geometry (monitor_index);

		bool is_fixed;
		string file1, file2;
		double progress, duration;
		show.get_current_slide (monitor.width, monitor.height, out progress, 
			out duration, out is_fixed, out file1, out file2);

		transition_progress = progress;
		transition_duration = duration;

		if (file1 != null)
			key_frame_files.add (file1);

		if (file2 != null)
			key_frame_files.add (file2);
	}
}


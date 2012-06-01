//  
//  Copyright (C) 2012 GardenGnome, Rico Tzschichholz
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
	public class Settings : Granite.Services.Settings
	{
		public bool attach_modal_dialogs { get; set; }
		public string button_layout { get; set; }
		public bool edge_tiling { get; set; }
		public bool enable_animations { get; set; }
		public string panel_main_menu_action { get; set; }
		public string theme { get; set; }
		public string toggle_recording_action { get; set; }
		public bool use_gnome_defaults { get; set; }
		public bool enable_manager_corner { get; set; }
		
		static Settings? instance = null;
		
		private Settings ()
		{
			base (SCHEMA);
		}
		
		public static Settings get_default ()
		{
			if (instance == null)
				instance = new Settings ();
			
			return instance;
		}
	}
}

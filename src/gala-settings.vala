namespace Gala
{
    public class Settings : Granite.Services.Settings
    {
        public bool attach_modal_dialogs { get; set; }
        public string[] button_layout { get; set; }
        public bool edge_tiling { get; set; }
        public bool enable_animations { get; set; }
        public string panel_main_menu_action { get; set; }
        public string theme { get; set; }
        public bool use_gnome_defaults { get; set; }
        public bool enable_manager_corner { get; set; }
        
        static Settings? instance = null;
        
        private Settings ()
        {
            base (SCHEMA);
        }
        
        public static Settings get_default()
        {
            if (instance == null)
                instance = new Settings ();
            
            return instance;
        }
    }
}
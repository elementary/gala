[DBus (name = "io.elementary.pantheon.AccountsService")]
interface Gala.AccountsService : Object {
    public abstract int prefers_accent_color { get; }
}

[DBus (name = "org.freedesktop.Accounts")]
interface Gala.FDO.Accounts : Object {
    public abstract string find_user_by_name (string username) throws GLib.Error;
}

[DBus (name = "org.freedesktop.DBus.Properties")]
interface Gala.FDO.Properties : Object {
    public signal void properties_changed (string interface_name, HashTable<string, Variant> changed_properties, string[] invalidated_properties);
}

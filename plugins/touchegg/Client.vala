/*
 * Copyright 2020 elementary, Inc (https://elementary.io)
 *           2020 José Expósito <jose.exposito89@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
* This class connects to the Touchégg daemon to receive touch events.
* See: https://github.com/JoseExposito/touchegg
*/
public class Gala.Plugins.Touchegg.Client : Object {
    public signal void on_gesture_begin (Gesture gesture);
    public signal void on_gesture_update (Gesture gesture);
    public signal void on_gesture_end (Gesture gesture);

    /**
     * Daemon D-Bus address.
     */
    private const string DBUS_ADDRESS = "unix:abstract=touchegg";

    /**
     * D-Bus interface name.
     */
    private const string DBUS_INTERFACE_NAME = "io.github.joseexposito.Touchegg";

    /**
     * D-Bus object path.
     */
    private const string DBUS_OBJECT_PATH = "/io/github/joseexposito/Touchegg";

    /**
     * Signal names.
     */
    private const string DBUS_ON_GESTURE_BEGIN = "OnGestureBegin";
    private const string DBUS_ON_GESTURE_UPDATE = "OnGestureUpdate";
    private const string DBUS_ON_GESTURE_END = "OnGestureEnd";

    /**
     * Maximum number of reconnection attempts to the daemon.
     */
    private const int MAX_RECONNECTION_ATTEMPTS = 5;

    /**
     * Time to sleep between reconnection attempts.
     */
    private const int RECONNECTION_USLEEP_TIME = 5000000;

    /**
     * Connection with the daemon.
     */
    private GLib.DBusConnection? connection = null;

    /**
     * Current number of reconnection attempts.
     */
    private int reconnection_attempts = 0;

    /*
     * Store the last received signal and signal parameters so in case of
     * disconnection in the middle of a gesture we can finish it.
     */
    private string? last_signal_received = null;
    private Variant? last_params_received = null;

    /**
     * Stablish a connection with the daemon server.
     */
    public void stablish_connection () {
        ThreadFunc<void> run = () => {
            var connected = false;

            while (!connected && reconnection_attempts < MAX_RECONNECTION_ATTEMPTS) {
                try {
                    debug ("Connecting to Touchégg daemon");
                    connection = new DBusConnection.for_address_sync (
                        DBUS_ADDRESS,
                        GLib.DBusConnectionFlags.AUTHENTICATION_CLIENT
                    );

                    debug ("Connection with Touchégg established");
                    connected = true;
                    reconnection_attempts = 0;

                    connection.signal_subscribe (null, DBUS_INTERFACE_NAME, null, DBUS_OBJECT_PATH,
                        null, DBusSignalFlags.NONE, (DBusSignalCallback) on_new_message);
                    connection.on_closed.connect (on_disconnected);
                } catch (Error e) {
                    warning ("Error connecting to Touchégg daemon: %s", e.message);
                    connected = false;
                    reconnection_attempts++;

                    if (reconnection_attempts < MAX_RECONNECTION_ATTEMPTS) {
                        debug ("Reconnecting to Touchégg daemon in 5 seconds");
                        Thread.usleep (RECONNECTION_USLEEP_TIME);
                    } else {
                        warning ("Maximum number of reconnections reached, aborting");
                    }
                }
            }
        };

        new Thread<void> (null, (owned) run);
    }

    public void stop () {
        try {
            reconnection_attempts = MAX_RECONNECTION_ATTEMPTS;

            if (!connection.closed) {
                connection.close_sync ();
            }
        } catch (Error e) {
            // Ignore this error, the process is being killed as this point
        }
    }

    [CCode (instance_pos = -1)]
    private void on_new_message (DBusConnection connection, string? sender_name, string object_path,
        string interface_name, string signal_name, Variant parameters) {
        last_signal_received = signal_name;
        last_params_received = parameters;

        var gesture = make_gesture (parameters);
        emit_event (signal_name, gesture);
    }

    private void on_disconnected (bool remote_peer_vanished, Error? error) {
        debug ("Connection with Touchégg daemon lost %s", error.message);

        if (last_signal_received == DBUS_ON_GESTURE_BEGIN || last_signal_received == DBUS_ON_GESTURE_UPDATE) {
            debug ("Connection lost in the middle of a gesture, ending it");
            var gesture = make_gesture (last_params_received);
            emit_event (DBUS_ON_GESTURE_END, gesture);
        }

        stablish_connection ();
    }

    private static Gesture make_gesture (Variant signal_params) {
        GestureType type;
        GestureDirection direction;
        double percentage;
        int fingers;
        DeviceType performed_on_device_type;
        uint64 elapsed_time;

        signal_params.get ("(uudiut)", out type, out direction, out percentage, out fingers,
            out performed_on_device_type, out elapsed_time);

        Gesture gesture = new Gesture () {
            type = type,
            direction = direction,
            percentage = percentage,
            fingers = fingers,
            performed_on_device_type = performed_on_device_type,
            elapsed_time = elapsed_time
        };

        return gesture;
    }

    private void emit_event (string signal_name, Gesture gesture) {
        switch (signal_name) {
            case DBUS_ON_GESTURE_BEGIN:
                on_gesture_begin (gesture);
                break;
            case DBUS_ON_GESTURE_UPDATE:
                on_gesture_update (gesture);
                break;
            case DBUS_ON_GESTURE_END:
                on_gesture_end (gesture);
                break;
            default:
                break;
        }
    }
}

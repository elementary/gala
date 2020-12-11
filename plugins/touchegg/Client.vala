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

namespace Gala.Plugins.Touchegg {
    /**
     * Daemon event type.
     */
     private enum GestureEventType {
        UNKNOWN = 0,
        BEGIN = 1,
        UPDATE = 2,
        END = 3,
    }

    /**
     * Daemon event.
     */
    private struct GestureEvent {
        public uint32 event_size;
        public GestureEventType event_type;
        public GestureType type;
        public GestureDirection direction;
        public int percentage;
        public int fingers;
        public uint64 elapsed_time;
        public DeviceType performed_on_device_type;
    }

    /**
     * This class connects to the Touchégg daemon to receive touch events.
     * See: https://github.com/JoseExposito/touchegg
     */
    public class Client : Object {
        public signal void on_gesture_begin (Gesture gesture);
        public signal void on_gesture_update (Gesture gesture);
        public signal void on_gesture_end (Gesture gesture);

        /**
         * Maximum number of reconnection attempts to the daemon.
         */
        private const int MAX_RECONNECTION_ATTEMPTS = 5;

        /**
         * Time to sleep between reconnection attempts.
         */
        private const int RECONNECTION_USLEEP_TIME = 5000000;

        /**
         * Socket used to connect to the daemon.
         */
        private Socket? socket = null;

        /**
         * Current number of reconnection attempts.
         */
        private int reconnection_attempts = 0;

        /**
         * Struct to store the received event. It is useful to keep it to be able to finish ongoing
         * actions in case of disconnection
         */
        private GestureEvent *event = null;

        /**
         * Start receiving gestures.
         */
        public void run () throws IOError {
            new Thread<void*> (null, receive_events);
        }

        public void stop () {
            if (socket != null) {
                try {
                    reconnection_attempts = MAX_RECONNECTION_ATTEMPTS;
                    socket.close ();
                } catch (Error e) {
                    // Ignore this error, the process is being killed as this point
                }
            }
        }

        private void* receive_events () {
            uint8[] event_buffer = new uint8[sizeof (GestureEvent)];

            while (reconnection_attempts < MAX_RECONNECTION_ATTEMPTS) {
                try {
                    if (socket == null || !socket.is_connected ()) {
                        debug ("Connecting to Touchégg daemon");
                        socket = new Socket (SocketFamily.UNIX, SocketType.STREAM, 0);
                        if (socket == null) {
                            throw new GLib.IOError.CONNECTION_REFUSED (
                                "Error connecting to Touchégg daemon: Can not create socket"
                            );
                        }

                        UnixSocketAddress address = new UnixSocketAddress.as_abstract ("/touchegg", -1);
                        bool connected = socket.connect (address);
                        if (!connected) {
                            throw new GLib.IOError.CONNECTION_REFUSED ("Error connecting to Touchégg daemon");
                        }

                        reconnection_attempts = 0;
                        debug ("Connection to Touchégg daemon established");
                    }

                    // Read the event
                    ssize_t bytes_received = socket.receive (event_buffer);
                    if (bytes_received <= 0) {
                        throw new GLib.IOError.CONNECTION_CLOSED ("Error reading socket");
                    }
                    event = (GestureEvent *) event_buffer;

                    // The daemon could add events not supported by this plugin yet
                    // Discard any extra data
                    if (bytes_received < event.event_size) {
                        ssize_t pending_bytes = event.event_size - bytes_received;
                        uint8[] discard_buffer = new uint8[pending_bytes];
                        bytes_received = socket.receive (discard_buffer);
                        if (bytes_received <= 0) {
                            throw new GLib.IOError.CONNECTION_CLOSED ("Error reading socket");
                        }
                    }

                    emit_event (event);
                } catch (Error e) {
                    warning ("Connection to Touchégg daemon lost: %s", e.message);
                    handle_disconnection ();
                }
            }

            return null;
        }

        private void handle_disconnection () {
            reconnection_attempts++;

            if (event != null
                && event.event_type != GestureEventType.UNKNOWN
                && event.event_type != GestureEventType.END) {
                event.event_type = GestureEventType.END;
                emit_event (event);
            }

            if (socket != null) {
                try {
                    socket.close ();
                } catch (Error e) {
                    // The connection is already closed at this point, ignore this error
                }
            }

            if (reconnection_attempts < MAX_RECONNECTION_ATTEMPTS) {
                debug ("Reconnecting to Touchégg daemon in 5 seconds");
                Thread.usleep (RECONNECTION_USLEEP_TIME);
            } else {
                warning ("Maximum number of reconnections reached, aborting");
            }
        }

        private void emit_event (GestureEvent *event) {
            Gesture gesture = new Gesture () {
                type = event.type,
                direction = event.direction,
                percentage = event.percentage,
                fingers = event.fingers,
                elapsed_time = event.elapsed_time,
                performed_on_device_type = event.performed_on_device_type
            };

            switch (event.event_type) {
                case GestureEventType.BEGIN:
                    on_gesture_begin (gesture);
                    break;
                case GestureEventType.UPDATE:
                    on_gesture_update (gesture);
                    break;
                case GestureEventType.END:
                    on_gesture_end (gesture);
                    break;
                default:
                    break;
            }
        }
    }
}

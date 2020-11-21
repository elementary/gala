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
    public class Client {
        public signal void on_gesture_begin (Gesture gesture);
        public signal void on_gesture_update (Gesture gesture);
        public signal void on_gesture_end (Gesture gesture);

        /**
         * Maximum number of reconnection attemps to the daemon.
         */
        private const int MAX_RECONNECTION_ATTEMPS = 5;

        /**
         * Socket used to connect to the daemon.
         */
        private Socket socket = null;

        /**
         * Current number of reconnection attemps.
         */
        private int reconnection_attemps = 0;

        /**
         * Stuct to store the received event. It is usefull to keep it to be able to finish ongoing
         * actions in case of disconnection
         */
        private GestureEvent *event = null;

        /**
         * Start receiving gestures.
         */
        public void run () throws IOError {
            new Thread<void*> (null, this.recive_events);
        }

        private void* recive_events () {
            uint8[] event_buffer = new uint8[sizeof (GestureEvent)];

            while (this.reconnection_attemps < MAX_RECONNECTION_ATTEMPS) {
                try {
                    if (this.socket == null || !this.socket.is_connected ()) {
                        debug ("Connecting to Touchégg daemon");
                        this.socket = new Socket (SocketFamily.UNIX, SocketType.STREAM, 0);
                        if (this.socket == null) {
                            throw new GLib.IOError.CONNECTION_REFUSED (
                                "Error connecting to Touchégg daemon: Can not create socket"
                            );
                        }
    
                        UnixSocketAddress address = new UnixSocketAddress.as_abstract ("/touchegg", -1);
                        bool connected = this.socket.connect (address);
                        if (!connected) {
                            throw new GLib.IOError.CONNECTION_REFUSED ("Error connecting to Touchégg daemon");
                        }

                        debug ("Connetion to Touchégg daemon stablished");
                    }

                    // Read the event
                    ssize_t bytes_received = this.socket.receive (event_buffer);
                    if (bytes_received <= 0) {
                        throw new GLib.IOError.CONNECTION_CLOSED ("Error reading socket");
                    }
                    this.event = (GestureEvent *) event_buffer;

                    // The daemon could add events not supported by this plugin yet
                    // Discard any extra data
                    if (bytes_received < this.event.event_size) {
                        ssize_t pending_bytes = this.event.event_size - bytes_received;
                        uint8[] discard_buffer = new uint8[pending_bytes];
                        bytes_received = this.socket.receive (discard_buffer);
                        if (bytes_received <= 0) {
                            throw new GLib.IOError.CONNECTION_CLOSED ("Error reading socket");
                        }
                    }

                    this.emit_event (this.event);
                } catch (Error e) {
                    warning ("Connection to Touchégg daemon lost: %s", e.message);
                    this.reconnection_attemps++;

                    if (this.event != null 
                            && this.event.event_type != GestureEventType.UNKNOWN 
                            && this.event.event_type != GestureEventType.END) {
                        this.event.event_type = GestureEventType.END;
                        this.emit_event (this.event);
                    }

                    if (this.socket != null) {
                        this.socket.close ();
                    }

                    if (this.reconnection_attemps < MAX_RECONNECTION_ATTEMPS) {
                        debug ("Reconnecting to Touchégg daemon in 5 seconds");
                        Thread.usleep (5000000);
                    } else {
                        warning ("Maximum number of reconnections reached, aborting");
                    }
                }
            }

            return null;
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
                    this.on_gesture_begin (gesture);
                    break;
                case GestureEventType.UPDATE:
                    this.on_gesture_update (gesture);
                    break;
                case GestureEventType.END:
                    this.on_gesture_end (gesture);
                    break;
                default:
                    break;
            }
        }
    }
}

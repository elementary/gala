/*
 * Copyright 2021 elementary, Inc (https://elementary.io)
 *           2021 José Expósito <jose.exposito89@gmail.com>
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

namespace Gala {
    /**
     * Physical direction of the gesture. This direction doesn't follow natural scroll preferences.
     */
    public enum GestureDirection {
        UNKNOWN = 0,

        // GestureType.SWIPE and GestureType.SCROLL
        UP = 1,
        DOWN = 2,
        LEFT = 3,
        RIGHT = 4,

        // GestureType.PINCH
        IN = 5,
        OUT = 6,
    }

    public class Gesture {
        public Clutter.EventType type;
        public GestureDirection direction;
        public int fingers;
        public Clutter.InputDeviceType performed_on_device_type;
    }
}

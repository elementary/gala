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

    public enum GestureAction {
        NONE,
        SWITCH_WORKSPACE,
        MOVE_TO_WORKSPACE,
        SWITCH_WINDOWS,
        MULTITASKING_VIEW,
        DOCK,
        N_ACTIONS
    }

    public class Gesture {
        public const float INVALID_COORD = float.MAX;

        public Clutter.EventType type;
        public GestureDirection direction;
        public int fingers;
        public Clutter.InputDeviceType performed_on_device_type;

        /**
         * The x coordinate of the initial contact point for the gesture.
         * Doesn't have to be set. In that case it is set to {@link INVALID_COORD}.
         * Currently the only backend not setting this is {@link GestureTracker.enable_touchpad}.
         */
        public float origin_x = INVALID_COORD;

        /**
         * The y coordinate of the initial contact point for the gesture.
         * Doesn't have to be set. In that case it is set to {@link INVALID_COORD}.
         * Currently the only backend not setting this is {@link GestureTracker.enable_touchpad}.
         */
        public float origin_y = INVALID_COORD;
    }
}

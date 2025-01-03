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
     * Physical direction of the gesture.
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

    /**
     * Action triggered by the gesture.
     */
    public class GestureAction {
        public enum Type {
            NONE,
            CUSTOM, // Means we have less than three fingers. Usually only emitted if we are interacting with a component itself e.g. MultitaskingView
            SWITCH_WORKSPACE,
            MOVE_TO_WORKSPACE,
            SWITCH_WINDOWS,
            MULTITASKING_VIEW,
            ZOOM
        }

        public enum Direction {
            FORWARD,
            BACKWARD
        }

        public GestureAction (Type type, Direction direction) {
            this.type = type;
            this.direction = direction;
        }

        public Type type;
        public Direction direction;
    }
}

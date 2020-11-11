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

namespace Gala {
    public enum GestureType {
        NOT_SUPPORTED = 0,
        SWIPE = 1,
        PINCH = 2,
    }

    public enum GestureDirection {
        UNKNOWN = 0,
      
        // GestureType.SWIPE
        UP = 1,
        DOWN = 2,
        LEFT = 3,
        RIGHT = 4,
      
        // GestureType.PINCH
        IN = 5,
        OUT = 6,
    }

    public class Gesture {
        public GestureType type;
        public GestureDirection direction;
        public int percentage;
        public int fingers;
        public uint64 elapsed_time;
    }
}

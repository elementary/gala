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
        SWIPE,
        PINCH,
        NOT_SUPPORTED,
    }

    public enum GestureDirection {
        UNKNOWN,
      
        // GestureType.SWIPE
        UP,
        DOWN,
        LEFT,
        RIGHT,
      
        // GestureType.PINCH
        IN,
        OUT,
    }

    public class Gesture {
        public GestureType type;
        public GestureDirection direction;
        public int percentage;
        public int fingers;
        public uint64 elapsed_time;
    }
}

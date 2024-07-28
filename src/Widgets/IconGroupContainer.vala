//
//  Copyright (C) 2014 Tom Beckmann
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Gala {
    /**
     * This class contains the icon groups at the bottom and will take
     * care of displaying actors for inserting windows between the groups
     * once implemented
     */
    public class IconGroupContainer : Clutter.Actor {
        public const int SPACING = 48;
        public const int GROUP_WIDTH = 64;

        public WindowManager wm { get; construct; }

        public signal void request_reposition (bool animate);

        private float _scale_factor = 1.0f;
        public float scale_factor {
            get {
                return _scale_factor;
            }
            set {
                if (value != _scale_factor) {
                    _scale_factor = value;
                    reallocate ();
                }
            }
        }

        public IconGroupContainer (WindowManager wm, float scale) {
            Object (wm: wm, scale_factor: scale);

            layout_manager = new Clutter.BoxLayout ();
        }

        private void reallocate () {
            foreach (var child in get_children ()) {
                unowned WorkspaceInsertThumb thumb = child as WorkspaceInsertThumb;
                if (thumb != null) {
                    thumb.scale_factor = scale_factor;
                }
            }
        }

        public void add_group (IconGroup group) {
            var index = group.workspace.index ();

            insert_child_at_index (group, index * 2);

            var thumb = new WorkspaceInsertThumb (wm, index, scale_factor);
            thumb.notify["expanded"].connect_after (expanded_changed);
            insert_child_at_index (thumb, index * 2);

            update_inserter_indices ();
        }

        public void remove_group (IconGroup group) {
            var thumb = (WorkspaceInsertThumb) group.get_previous_sibling ();
            thumb.notify["expanded"].disconnect (expanded_changed);
            remove_child (thumb);

            remove_child (group);

            update_inserter_indices ();
        }

        /**
         * Removes an icon group "in place".
         * When initially dragging an icon group we remove
         * it and it's previous WorkspaceInsertThumb. This would make
         * the container immediately reallocate and fill the empty space
         * with right-most IconGroups.
         *
         * We don't want that until the IconGroup
         * leaves the expanded WorkspaceInsertThumb.
         */
        public void remove_group_in_place (IconGroup group) {
            var deleted_thumb = (WorkspaceInsertThumb) group.get_previous_sibling ();
            var deleted_placeholder_thumb = (WorkspaceInsertThumb) group.get_next_sibling ();

            remove_group (group);

            /**
             * We will account for that empty space
             * by manually expanding the next WorkspaceInsertThumb with the
             * width we deleted. Because the IconGroup is still hovering over
             * the expanded thumb, we will also update the drag & drop action
             * of IconGroup on that.
             */
            if (deleted_placeholder_thumb != null) {
                float deleted_width = deleted_thumb.get_width () + group.get_width ();
                deleted_placeholder_thumb.expanded = true;
                deleted_placeholder_thumb.width += deleted_width;
                group.set_hovered_actor (deleted_placeholder_thumb);
            }
        }

        public void reset_thumbs (int delay) {
            foreach (var child in get_children ()) {
                unowned WorkspaceInsertThumb thumb = child as WorkspaceInsertThumb;
                if (thumb != null) {
                    thumb.delay = delay;
                    thumb.destroy_all_children ();
                }
            }
        }

        private void expanded_changed (ParamSpec param) {
            request_reposition (true);
        }

        /**
         * Calculates the width that will be occupied taking currently running animations
         * end states into account
         */
        public float calculate_total_width () {
            var spacing = InternalUtils.scale_to_int (SPACING, scale_factor);
            var group_width = InternalUtils.scale_to_int (GROUP_WIDTH, scale_factor);

            var width = 0.0f;
            foreach (var child in get_children ()) {
                if (child is WorkspaceInsertThumb) {
                    if (((WorkspaceInsertThumb) child).expanded)
                        width += group_width + spacing * 2;
                    else
                        width += spacing;
                } else
                    width += group_width;
            }

            width += spacing;

            return width;
        }

        public void force_reposition () {
            var children = get_children ();

            foreach (var child in children) {
                if (child is IconGroup) {
                    child.ref (); //The list only contains weak references so make sure the child isn't freed before it's added again
                    remove_group ((IconGroup) child);
                }
            }

            foreach (var child in children) {
                if (child is IconGroup) {
                    add_group ((IconGroup) child);
                    child.unref ();
                }
            }
        }

        private void update_inserter_indices () {
            var current_index = 0;

            foreach (var child in get_children ()) {
                unowned WorkspaceInsertThumb thumb = child as WorkspaceInsertThumb;
                if (thumb != null) {
                    thumb.workspace_index = current_index++;
                }
            }
        }
    }
}

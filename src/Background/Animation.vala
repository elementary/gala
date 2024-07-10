/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 *                         2014 Tom Beckmann
 */

public class Gala.Animation : Object {
    public string filename { get; construct; }
    public string[] key_frame_files { get; private set; default = {}; }
    public double transition_progress { get; private set; default = 0.0; }
    public double transition_duration { get; private set; default = 0.0; }
    public bool loaded { get; private set; default = false; }

    private Gnome.BGSlideShow? show = null;

    public Animation (string filename) {
        Object (filename: filename);
    }

    public async void load () {
        show = new Gnome.BGSlideShow (filename);

        show.load_async (null, (obj, res) => {
            loaded = true;

            load.callback ();
        });

        yield;
    }

#if HAS_MUTTER45
    public void update (Mtk.Rectangle monitor) {
#else
    public void update (Meta.Rectangle monitor) {
#endif
        string[] key_frame_files = {};

        if (show == null) {
            return;
        }

        if (show.get_num_slides () < 1) {
            return;
        }

        double progress, duration;
        bool is_fixed;
        string file1, file2;
        show.get_current_slide (monitor.width, monitor.height, out progress, out duration, out is_fixed, out file1, out file2);

        transition_duration = duration;
        transition_progress = progress;

        if (file1 != null) {
            key_frame_files += file1;
        }

        if (file2 != null) {
            key_frame_files += file2;
        }

        this.key_frame_files = key_frame_files;
    }
}

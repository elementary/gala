/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

public interface Gala.BackgroundContainerInterface : Meta.BackgroundGroup {
    public signal void changed (int monitor_index);
}

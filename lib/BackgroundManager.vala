/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

public interface Gala.BackgroundManagerInterface : Meta.BackgroundGroup {
    public abstract Meta.BackgroundActor background_actor { get; protected set; }
    public abstract Meta.BackgroundActor? new_background_actor { get; protected set; }
}

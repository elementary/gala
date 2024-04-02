/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

 [DBus (name = "io.elementary.wm.daemon.EndSessionDialog")]
 public class Gala.Daemon.Session.Manager : Object {
     public signal void confirmed_logout ();
     public signal void confirmed_reboot ();
     public signal void confirmed_shutdown ();
     public signal void cancelled ();

     public void open (EndSessionDialog.Type type, uint timestamp, uint open_length, ObjectPath[] inhibiters) throws DBusError, IOError {
         var dialog = new EndSessionDialog (type) {
             title = "END_SESSION"
         };
         dialog.show_all ();
         dialog.present_with_time (timestamp);

         dialog.logout.connect (() => confirmed_logout ());
         dialog.reboot.connect (() => confirmed_reboot ());
         dialog.shutdown.connect (() => confirmed_shutdown ());
         dialog.cancelled.connect (() => cancelled ());
     }
 }

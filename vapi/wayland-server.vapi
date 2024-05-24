/* wayland-server.vapi
 *
 * Copyright 2022 Corentin Noël <corentin.noel@collabora.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice (including the
 * next paragraph) shall be included in all copies or substantial
 * portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Authors:
 * 	Corentin Noël <corentin.noel@collabora.com>
 */

[CCode (cprefix = "wl_", lower_case_cprefix = "wl_", cheader_filename = "wayland-server.h")]
namespace Wl {
	[Compact]
	[CCode (cname = "struct wl_display", free_function = "wl_display_destroy")]
	public class Display {
		[CCode (cname = "wl_display_create")]
		public Display ();
		public int add_socket (string name);
		public unowned string add_socket_auto ();
		public int add_socket_fd (int sock_fd);
		public void terminate ();
		public void run ();
		public void flush_clients ();
		public void destroy_clients ();
		public uint32 get_serial ();
		public uint32 next_serial ();
	}

	[Compact]
	[CCode (cname = "struct wl_client", free_function = "wl_client_destroy")]
	public class Client {
		[CCode (cname = "wl_client_create")]
		public Client (Wl.Display display, int fd);
		public void flush ();
		public void get_credentials (out Posix.pid_t pid, out Posix.uid_t uid, out Posix.gid_t gid);
		public int get_fd ();
		public unowned Wl.Display get_display ();
		[CCode (cname = "wl_resource_create")]
		public unowned Wl.Resource? create_resource (ref Wl.Interface interface, int version, uint32 id);
	}

	[Compact]
	[CCode (cname = "struct wl_resource", free_function = "wl_resource_destroy")]
	public class Resource {
		public uint32 get_id ();
		public unowned Wl.Client get_client ();
		[CCode (simple_generics = true)]
		public void set_user_data<T> (T? data);
		[CCode (simple_generics = true)]
		public unowned T? get_user_data<T> ();
		public int get_version ();
		public unowned string get_class ();
		public void destroy ();
		public void set_implementation (void* implementation, void* data, [CCode (delegate_target = false)] ResourceDestroyFunc destroy);
		[PrintfFormat]
		public void post_error(uint32 code, string format, ...);
	}
	[Compact]
	[CCode (cname = "struct wl_interface")]
	public class Interface {
		public string name;
		public int version;
		[CCode (array_length = "method_count")]
		public Wl.Message[] methods;
		[CCode (array_length = "event_count")]
		public Wl.Message[] events;
	}

	[Compact]
	[CCode (cname = "struct wl_message")]
	public class Message {
		public string name;
		public string signature;
		[CCode (array_length = false)]
		public Wl.Interface?[] types;
	}

	[Compact]
	[CCode (cname = "struct wl_global", free_function = "wl_global_destroy")]
	public class Global {
		[CCode (cname = "wl_global_create")]
		public static Wl.Global? create (Wl.Display display, ref Wl.Interface interface, int version, [CCode (delegate_target_pos = 3.9) ] Wl.GlobalBindFunc bind);
	}

	[CCode (cheader_filename = "wayland-server-protocol.h", cname = "enum wl_display_error", cprefix="WL_DISPLAY_ERROR_", has_type_id = false)]
	public enum DisplayError {
		INVALID_OBJECT,
		INVALID_METHOD,
		NO_MEMORY,
		IMPLEMENTATION,
	}

	[CCode (cname = "wl_global_bind_func_t", instance_pos = 1.9)]
	public delegate void GlobalBindFunc (Wl.Client client, uint32 version, uint32 id);
	[CCode (cname = "wl_resource_destroy_func_t", has_target = false)]
	public delegate void ResourceDestroyFunc (Wl.Resource resource);
	[CCode (cname = "WAYLAND_VERSION_MAJOR")]
	public const int VERSION_MAJOR;
	[CCode (cname = "WAYLAND_VERSION_MINOR")]
	public const int VERSION_MINOR;
	[CCode (cname = "WAYLAND_VERSION_MICRO")]
	public const int VERSION_MICRO;
	[CCode (cname = "WAYLAND_VERSION")]
	public const string VERSION;
}


/*
    GLEW.vapi
    Copyright (C) 2012 Maia Kozheva <sikon@ubuntu.com>

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
*/
[CCode (cprefix = "GLEW", gir_namespace = "GLEW", gir_version = "1.0", lower_case_cprefix = "glew_")]
namespace GLEW {
	[CCode (cheader_filename = "GL/glew.h", cname = "glewInit")]
	public static uint glewInit ();
	[CCode (cheader_filename = "GL/glew.h", cname = "GLEW_OK")]
	public const uint GLEW_OK;
	[CCode (cheader_filename = "GL/glew.h", cname = "glewGetErrorString")]
	public static unowned string? glewGetErrorString (uint error);
	[CCode (cheader_filename = "GL/glew.h", cname = "glewGetString")]
	public static unowned string? glewGetString (uint name);
	[CCode (cheader_filename = "GL/glew.h", cname = "GLEW_VERSION")]
	public const uint GLEW_VERSION;
}

/*
 * GLESv2 binding for Vala (Plain C Style)
 *
 * Copyright 2013 Aleksandr Palamar <void995@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename="GLES2/gl2.h")]
namespace GLES2
{
    /*-------------------------------------------------------------------------
     * Data type definitions
     *-----------------------------------------------------------------------*/
     
    [SimpleType]
    public struct GLvoid {
    }
     
    [SimpleType]
    public struct GLchar: char {
    }
    
    [SimpleType]
    public struct GLenum: int {
    }
    
    [SimpleType]
    public struct GLboolean: uint8 {
    }
    
    [SimpleType]
    public struct GLbitfield: uint8 {
    }
    
    [SimpleType]
    public struct GLbyte: char {
    }
    
    [SimpleType]
    public struct GLshort: short {
    }
    
    [SimpleType]
    public struct GLint: int {
    }
    
    [SimpleType]
    public struct GLsizei: int {
    }
    
    [SimpleType]
    public struct GLubyte: uchar {
    }
    
    [SimpleType]
    public struct GLushort: ushort {
    }
    
    [SimpleType]
    public struct GLuint: uint {
    }
    
    [SimpleType]
    public struct GLfloat: float {
    }
    
    [SimpleType]
    public struct GLclampf: float {
    }
    
    [SimpleType]
    public struct GLfixed: int32 {
    }

    /* GL types for handling large vertex buffer objects */
    [SimpleType]
    public struct GLintptr: size_t {
    }
    
    [SimpleType]
    public struct GLsizeiptr: size_t {
    }
    
    public const GLboolean GL_FALSE;
    public const GLboolean GL_TRUE;
    
    /* ClearBufferMask */
    public const GLbitfield GL_DEPTH_BUFFER_BIT;
    public const GLbitfield GL_STENCIL_BUFFER_BIT;
    public const GLbitfield GL_COLOR_BUFFER_BIT;

    /* BeginMode */
    public const GLenum GL_POINTS;
    public const GLenum GL_LINES;
    public const GLenum GL_LINE_LOOP;
    public const GLenum GL_LINE_STRIP;
    public const GLenum GL_TRIANGLES;
    public const GLenum GL_TRIANGLE_STRIP;
    public const GLenum GL_TRIANGLE_FAN;

    /* AlphaFunction (not supported in ES20) */
    /*      GL_NEVER */
    /*      GL_LESS */
    /*      GL_EQUAL */
    /*      GL_LEQUAL */
    /*      GL_GREATER */
    /*      GL_NOTEQUAL */
    /*      GL_GEQUAL */
    /*      GL_ALWAYS */

    /* BlendingFactorDest */
    public const GLenum GL_ZERO;
    public const GLenum GL_ONE;
    public const GLenum GL_SRC_COLOR;
    public const GLenum GL_ONE_MINUS_SRC_COLOR;
    public const GLenum GL_SRC_ALPHA;
    public const GLenum GL_ONE_MINUS_SRC_ALPHA;
    public const GLenum GL_DST_ALPHA;
    public const GLenum GL_ONE_MINUS_DST_ALPHA;

    /* BlendingFactorSrc */
    /*      GL_ZERO */
    /*      GL_ONE */
    public const GLenum GL_DST_COLOR;
    public const GLenum GL_ONE_MINUS_DST_COLOR;
    public const GLenum GL_SRC_ALPHA_SATURATE;
    /*      GL_SRC_ALPHA */
    /*      GL_ONE_MINUS_SRC_ALPHA */
    /*      GL_DST_ALPHA */
    /*      GL_ONE_MINUS_DST_ALPHA */

    /* BlendEquationSeparate */
    public const GLenum GL_FUNC_ADD;
    public const GLenum GL_BLEND_EQUATION;
    public const GLenum GL_BLEND_EQUATION_RGB;    /* same as BLEND_EQUATION */
    public const GLenum GL_BLEND_EQUATION_ALPHA;

    /* BlendSubtract */
    public const GLenum GL_FUNC_SUBTRACT;
    public const GLenum GL_FUNC_REVERSE_SUBTRACT;

    /* Separate Blend Functions */
    public const GLenum GL_BLEND_DST_RGB;
    public const GLenum GL_BLEND_SRC_RGB;
    public const GLenum GL_BLEND_DST_ALPHA;
    public const GLenum GL_BLEND_SRC_ALPHA;
    public const GLenum GL_CONSTANT_COLOR;
    public const GLenum GL_ONE_MINUS_CONSTANT_COLOR;
    public const GLenum GL_CONSTANT_ALPHA;
    public const GLenum GL_ONE_MINUS_CONSTANT_ALPHA;
    public const GLenum GL_BLEND_COLOR;

    /* Buffer Objects */
    public const GLenum GL_ARRAY_BUFFER;
    public const GLenum GL_ELEMENT_ARRAY_BUFFER;
    public const GLenum GL_ARRAY_BUFFER_BINDING;
    public const GLenum GL_ELEMENT_ARRAY_BUFFER_BINDING;

    public const GLenum GL_STREAM_DRAW;
    public const GLenum GL_STATIC_DRAW;
    public const GLenum GL_DYNAMIC_DRAW;

    public const GLenum GL_BUFFER_SIZE;
    public const GLenum GL_BUFFER_USAGE;

    public const GLenum GL_CURRENT_VERTEX_ATTRIB;

    /* CullFaceMode */
    public const GLenum GL_FRONT;
    public const GLenum GL_BACK;
    public const GLenum GL_FRONT_AND_BACK;

    /* DepthFunction */
    /*      GL_NEVER */
    /*      GL_LESS */
    /*      GL_EQUAL */
    /*      GL_LEQUAL */
    /*      GL_GREATER */
    /*      GL_NOTEQUAL */
    /*      GL_GEQUAL */
    /*      GL_ALWAYS */

    /* EnableCap */
    public const GLenum GL_TEXTURE_2D;
    public const GLenum GL_CULL_FACE;
    public const GLenum GL_BLEND;
    public const GLenum GL_DITHER;
    public const GLenum GL_STENCIL_TEST;
    public const GLenum GL_DEPTH_TEST;
    public const GLenum GL_SCISSOR_TEST;
    public const GLenum GL_POLYGON_OFFSET_FILL;
    public const GLenum GL_SAMPLE_ALPHA_TO_COVERAGE;
    public const GLenum GL_SAMPLE_COVERAGE;

    /* ErrorCode */
    public const GLenum GL_NO_ERROR;
    public const GLenum GL_INVALID_ENUM;
    public const GLenum GL_INVALID_VALUE;
    public const GLenum GL_INVALID_OPERATION;
    public const GLenum GL_OUT_OF_MEMORY;

    /* FrontFaceDirection */
    public const GLenum GL_CW;
    public const GLenum GL_CCW;

    /* GetPName */
    public const GLenum GL_LINE_WIDTH;
    public const GLenum GL_ALIASED_POINT_SIZE_RANGE;
    public const GLenum GL_ALIASED_LINE_WIDTH_RANGE;
    public const GLenum GL_CULL_FACE_MODE;
    public const GLenum GL_FRONT_FACE;
    public const GLenum GL_DEPTH_RANGE;
    public const GLenum GL_DEPTH_WRITEMASK;
    public const GLenum GL_DEPTH_CLEAR_VALUE;
    public const GLenum GL_DEPTH_FUNC;
    public const GLenum GL_STENCIL_CLEAR_VALUE;
    public const GLenum GL_STENCIL_FUNC;
    public const GLenum GL_STENCIL_FAIL;
    public const GLenum GL_STENCIL_PASS_DEPTH_FAIL;
    public const GLenum GL_STENCIL_PASS_DEPTH_PASS;
    public const GLenum GL_STENCIL_REF;
    public const GLenum GL_STENCIL_VALUE_MASK;
    public const GLenum GL_STENCIL_WRITEMASK;
    public const GLenum GL_STENCIL_BACK_FUNC;
    public const GLenum GL_STENCIL_BACK_FAIL;
    public const GLenum GL_STENCIL_BACK_PASS_DEPTH_FAIL;
    public const GLenum GL_STENCIL_BACK_PASS_DEPTH_PASS;
    public const GLenum GL_STENCIL_BACK_REF;
    public const GLenum GL_STENCIL_BACK_VALUE_MASK;
    public const GLenum GL_STENCIL_BACK_WRITEMASK;
    public const GLenum GL_VIEWPORT;
    public const GLenum GL_SCISSOR_BOX;
    /*      GL_SCISSOR_TEST */
    public const GLenum GL_COLOR_CLEAR_VALUE;
    public const GLenum GL_COLOR_WRITEMASK;
    public const GLenum GL_UNPACK_ALIGNMENT;
    public const GLenum GL_PACK_ALIGNMENT;
    public const GLenum GL_MAX_TEXTURE_SIZE;
    public const GLenum GL_MAX_VIEWPORT_DIMS;
    public const GLenum GL_SUBPIXEL_BITS;
    public const GLenum GL_RED_BITS;
    public const GLenum GL_GREEN_BITS;
    public const GLenum GL_BLUE_BITS;
    public const GLenum GL_ALPHA_BITS;
    public const GLenum GL_DEPTH_BITS;
    public const GLenum GL_STENCIL_BITS;
    public const GLenum GL_POLYGON_OFFSET_UNITS;
    /*      GL_POLYGON_OFFSET_FILL */
    public const GLenum GL_POLYGON_OFFSET_FACTOR;
    public const GLenum GL_TEXTURE_BINDING_2D;
    public const GLenum GL_SAMPLE_BUFFERS;
    public const GLenum GL_SAMPLES;
    public const GLenum GL_SAMPLE_COVERAGE_VALUE;
    public const GLenum GL_SAMPLE_COVERAGE_INVERT;

    /* GetTextureParameter */
    /*      GL_TEXTURE_MAG_FILTER */
    /*      GL_TEXTURE_MIN_FILTER */
    /*      GL_TEXTURE_WRAP_S */
    /*      GL_TEXTURE_WRAP_T */

    public const GLenum GL_NUM_COMPRESSED_TEXTURE_FORMATS;
    public const GLenum GL_COMPRESSED_TEXTURE_FORMATS;

    /* HintMode */
    public const GLenum GL_DONT_CARE;
    public const GLenum GL_FASTEST;
    public const GLenum GL_NICEST;

    /* HintTarget */
    public const GLenum GL_GENERATE_MIPMAP_HINT;

    /* DataType */
    public const GLenum GL_BYTE;
    public const GLenum GL_UNSIGNED_BYTE;
    public const GLenum GL_SHORT;
    public const GLenum GL_UNSIGNED_SHORT;
    public const GLenum GL_INT;
    public const GLenum GL_UNSIGNED_INT;
    public const GLenum GL_FLOAT;
    public const GLenum GL_FIXED;

    /* PixelFormat */
    public const GLenum GL_DEPTH_COMPONENT;
    public const GLenum GL_ALPHA;
    public const GLenum GL_RGB;
    public const GLenum GL_RGBA;
    public const GLenum GL_LUMINANCE;
    public const GLenum GL_LUMINANCE_ALPHA;

    /* PixelType */
    /*      GL_UNSIGNED_BYTE */
    public const GLenum GL_UNSIGNED_SHORT_4_4_4_4;
    public const GLenum GL_UNSIGNED_SHORT_5_5_5_1;
    public const GLenum GL_UNSIGNED_SHORT_5_6_5;

    /* Shaders */
    public const GLenum GL_FRAGMENT_SHADER;
    public const GLenum GL_VERTEX_SHADER;
    public const GLenum GL_MAX_VERTEX_ATTRIBS;
    public const GLenum GL_MAX_VERTEX_UNIFORM_VECTORS;
    public const GLenum GL_MAX_VARYING_VECTORS;
    public const GLenum GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS;
    public const GLenum GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS;
    public const GLenum GL_MAX_TEXTURE_IMAGE_UNITS;
    public const GLenum GL_MAX_FRAGMENT_UNIFORM_VECTORS;
    public const GLenum GL_SHADER_TYPE;
    public const GLenum GL_DELETE_STATUS;
    public const GLenum GL_LINK_STATUS;
    public const GLenum GL_VALIDATE_STATUS;
    public const GLenum GL_ATTACHED_SHADERS;
    public const GLenum GL_ACTIVE_UNIFORMS;
    public const GLenum GL_ACTIVE_UNIFORM_MAX_LENGTH;
    public const GLenum GL_ACTIVE_ATTRIBUTES;
    public const GLenum GL_ACTIVE_ATTRIBUTE_MAX_LENGTH;
    public const GLenum GL_SHADING_LANGUAGE_VERSION;
    public const GLenum GL_CURRENT_PROGRAM;

    /* StencilFunction */
    public const GLenum GL_NEVER;
    public const GLenum GL_LESS;
    public const GLenum GL_EQUAL;
    public const GLenum GL_LEQUAL;
    public const GLenum GL_GREATER;
    public const GLenum GL_NOTEQUAL;
    public const GLenum GL_GEQUAL;
    public const GLenum GL_ALWAYS;

    /* StencilOp */
    /*      GL_ZERO */
    public const GLenum GL_KEEP;
    public const GLenum GL_REPLACE;
    public const GLenum GL_INCR;
    public const GLenum GL_DECR;
    public const GLenum GL_INVERT;
    public const GLenum GL_INCR_WRAP;
    public const GLenum GL_DECR_WRAP;

    /* StringName */
    public const GLenum GL_VENDOR;
    public const GLenum GL_RENDERER;
    public const GLenum GL_VERSION;
    public const GLenum GL_EXTENSIONS;

    /* TextureMagFilter */
    public const GLenum GL_NEAREST;
    public const GLenum GL_LINEAR;

    /* TextureMinFilter */
    /*      GL_NEAREST */
    /*      GL_LINEAR */
    public const GLenum GL_NEAREST_MIPMAP_NEAREST;
    public const GLenum GL_LINEAR_MIPMAP_NEAREST;
    public const GLenum GL_NEAREST_MIPMAP_LINEAR;
    public const GLenum GL_LINEAR_MIPMAP_LINEAR;

    /* TextureParameterName */
    public const GLenum GL_TEXTURE_MAG_FILTER;
    public const GLenum GL_TEXTURE_MIN_FILTER;
    public const GLenum GL_TEXTURE_WRAP_S;
    public const GLenum GL_TEXTURE_WRAP_T;

    /* TextureTarget */
    /*      GL_TEXTURE_2D */
    public const GLenum GL_TEXTURE;

    public const GLenum GL_TEXTURE_CUBE_MAP;
    public const GLenum GL_TEXTURE_BINDING_CUBE_MAP;
    public const GLenum GL_TEXTURE_CUBE_MAP_POSITIVE_X;
    public const GLenum GL_TEXTURE_CUBE_MAP_NEGATIVE_X;
    public const GLenum GL_TEXTURE_CUBE_MAP_POSITIVE_Y;
    public const GLenum GL_TEXTURE_CUBE_MAP_NEGATIVE_Y;
    public const GLenum GL_TEXTURE_CUBE_MAP_POSITIVE_Z;
    public const GLenum GL_TEXTURE_CUBE_MAP_NEGATIVE_Z;
    public const GLenum GL_MAX_CUBE_MAP_TEXTURE_SIZE;

    /* TextureUnit */
    public const GLenum GL_TEXTURE0;
    public const GLenum GL_TEXTURE1;
    public const GLenum GL_TEXTURE2;
    public const GLenum GL_TEXTURE3;
    public const GLenum GL_TEXTURE4;
    public const GLenum GL_TEXTURE5;
    public const GLenum GL_TEXTURE6;
    public const GLenum GL_TEXTURE7;
    public const GLenum GL_TEXTURE8;
    public const GLenum GL_TEXTURE9;
    public const GLenum GL_TEXTURE10;
    public const GLenum GL_TEXTURE11;
    public const GLenum GL_TEXTURE12;
    public const GLenum GL_TEXTURE13;
    public const GLenum GL_TEXTURE14;
    public const GLenum GL_TEXTURE15;
    public const GLenum GL_TEXTURE16;
    public const GLenum GL_TEXTURE17;
    public const GLenum GL_TEXTURE18;
    public const GLenum GL_TEXTURE19;
    public const GLenum GL_TEXTURE20;
    public const GLenum GL_TEXTURE21;
    public const GLenum GL_TEXTURE22;
    public const GLenum GL_TEXTURE23;
    public const GLenum GL_TEXTURE24;
    public const GLenum GL_TEXTURE25;
    public const GLenum GL_TEXTURE26;
    public const GLenum GL_TEXTURE27;
    public const GLenum GL_TEXTURE28;
    public const GLenum GL_TEXTURE29;
    public const GLenum GL_TEXTURE30;
    public const GLenum GL_TEXTURE31;
    public const GLenum GL_ACTIVE_TEXTURE;

    /* TextureWrapMode */
    public const GLenum GL_REPEAT;
    public const GLenum GL_CLAMP_TO_EDGE;
    public const GLenum GL_MIRRORED_REPEAT;

    /* Uniform Types */
    public const GLenum GL_FLOAT_VEC2;
    public const GLenum GL_FLOAT_VEC3;
    public const GLenum GL_FLOAT_VEC4;
    public const GLenum GL_INT_VEC2;
    public const GLenum GL_INT_VEC3;
    public const GLenum GL_INT_VEC4;
    public const GLenum GL_BOOL;
    public const GLenum GL_BOOL_VEC2;
    public const GLenum GL_BOOL_VEC3;
    public const GLenum GL_BOOL_VEC4;
    public const GLenum GL_FLOAT_MAT2;
    public const GLenum GL_FLOAT_MAT3;
    public const GLenum GL_FLOAT_MAT4;
    public const GLenum GL_SAMPLER_2D;
    public const GLenum GL_SAMPLER_CUBE;

    /* Vertex Arrays */
    public const GLenum GL_VERTEX_ATTRIB_ARRAY_ENABLED;
    public const GLenum GL_VERTEX_ATTRIB_ARRAY_SIZE;
    public const GLenum GL_VERTEX_ATTRIB_ARRAY_STRIDE;
    public const GLenum GL_VERTEX_ATTRIB_ARRAY_TYPE;
    public const GLenum GL_VERTEX_ATTRIB_ARRAY_NORMALIZED;
    public const GLenum GL_VERTEX_ATTRIB_ARRAY_POINTER;
    public const GLenum GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING;

    /* Read Format */
    public const GLenum GL_IMPLEMENTATION_COLOR_READ_TYPE;
    public const GLenum GL_IMPLEMENTATION_COLOR_READ_FORMAT;

    /* Shader Source */
    public const GLenum GL_COMPILE_STATUS;
    public const GLenum GL_INFO_LOG_LENGTH;
    public const GLenum GL_SHADER_SOURCE_LENGTH;
    public const GLenum GL_SHADER_COMPILER;

    /* Shader Binary */
    public const GLenum GL_SHADER_BINARY_FORMATS;
    public const GLenum GL_NUM_SHADER_BINARY_FORMATS;

    /* Shader Precision-Specified Types */
    public const GLenum GL_LOW_FLOAT;
    public const GLenum GL_MEDIUM_FLOAT;
    public const GLenum GL_HIGH_FLOAT;
    public const GLenum GL_LOW_INT;
    public const GLenum GL_MEDIUM_INT;
    public const GLenum GL_HIGH_INT;

    /* Framebuffer Object. */
    public const GLenum GL_FRAMEBUFFER;
    public const GLenum GL_RENDERBUFFER;

    public const GLenum GL_RGBA4;
    public const GLenum GL_RGB5_A1;
    public const GLenum GL_RGB565;
    public const GLenum GL_DEPTH_COMPONENT16;
    public const GLenum GL_STENCIL_INDEX8;

    public const GLenum GL_RENDERBUFFER_WIDTH;
    public const GLenum GL_RENDERBUFFER_HEIGHT;
    public const GLenum GL_RENDERBUFFER_INTERNAL_FORMAT;
    public const GLenum GL_RENDERBUFFER_RED_SIZE;
    public const GLenum GL_RENDERBUFFER_GREEN_SIZE;
    public const GLenum GL_RENDERBUFFER_BLUE_SIZE;
    public const GLenum GL_RENDERBUFFER_ALPHA_SIZE;
    public const GLenum GL_RENDERBUFFER_DEPTH_SIZE;
    public const GLenum GL_RENDERBUFFER_STENCIL_SIZE;

    public const GLenum GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE;
    public const GLenum GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME;
    public const GLenum GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL;
    public const GLenum GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE;

    public const GLenum GL_COLOR_ATTACHMENT0;
    public const GLenum GL_DEPTH_ATTACHMENT;
    public const GLenum GL_STENCIL_ATTACHMENT;

    public const GLenum GL_NONE;

    public const GLenum GL_FRAMEBUFFER_COMPLETE;
    public const GLenum GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT;
    public const GLenum GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT;
    public const GLenum GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS;
    public const GLenum GL_FRAMEBUFFER_UNSUPPORTED;

    public const GLenum GL_FRAMEBUFFER_BINDING;
    public const GLenum GL_RENDERBUFFER_BINDING;
    public const GLenum GL_MAX_RENDERBUFFER_SIZE;

    public const GLenum GL_INVALID_FRAMEBUFFER_OPERATION;
    
    /*-------------------------------------------------------------------------
     * GL core functions.
     *-----------------------------------------------------------------------*/

    public void glActiveTexture (GLenum texture);
    public void glAttachShader (GLuint program, GLuint shader);
    public void glBindAttribLocation (GLuint program, GLuint index, string name);
    public void glBindBuffer (GLenum target, GLuint buffer);
    public void glBindFramebuffer (GLenum target, GLuint framebuffer);
    public void glBindRenderbuffer (GLenum target, GLuint renderbuffer);
    public void glBindTexture (GLenum target, GLuint texture);
    public void glBlendColor (GLclampf red, GLclampf green, GLclampf blue, GLclampf alpha);
    public void glBlendEquation ( GLenum mode );
    public void glBlendEquationSeparate (GLenum modeRGB, GLenum modeAlpha);
    public void glBlendFunc (GLenum sfactor, GLenum dfactor);
    public void glBlendFuncSeparate (GLenum srcRGB, GLenum dstRGB, GLenum srcAlpha, GLenum dstAlpha);
    public void glBufferData (GLenum target, GLsizeiptr size, GLvoid* data, GLenum usage);
    public void glBufferSubData (GLenum target, GLintptr offset, GLsizeiptr size, GLvoid* data);
    public GLenum glCheckFramebufferStatus (GLenum target);
    public void glClear (GLbitfield mask);
    public void glClearColor (GLclampf red, GLclampf green, GLclampf blue, GLclampf alpha);
    public void glClearDepthf (GLclampf depth);
    public void glClearStencil (GLint s);
    public void glColorMask (GLboolean red, GLboolean green, GLboolean blue, GLboolean alpha);
    public void glCompileShader (GLuint shader);
    public void glCompressedTexImage2D (GLenum target, GLint level, GLenum internalformat, GLsizei width, GLsizei height, GLint border, GLsizei imageSize, GLvoid* data);
    public void glCompressedTexSubImage2D (GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLsizei imageSize, GLvoid* data);
    public void glCopyTexImage2D (GLenum target, GLint level, GLenum internalformat, GLint x, GLint y, GLsizei width, GLsizei height, GLint border);
    public void glCopyTexSubImage2D (GLenum target, GLint level, GLint xoffset, GLint yoffset, GLint x, GLint y, GLsizei width, GLsizei height);
    public GLuint glCreateProgram ();
    public GLuint glCreateShader (GLenum type);
    public void glCullFace (GLenum mode);
    public void glDeleteBuffers (GLsizei n, GLuint* buffers);
    public void glDeleteFramebuffers (GLsizei n, GLuint* framebuffers);
    public void glDeleteProgram (GLuint program);
    public void glDeleteRenderbuffers (GLsizei n, GLuint* renderbuffers);
    public void glDeleteShader (GLuint shader);
    public void glDeleteTextures (GLsizei n, GLuint* textures);
    public void glDepthFunc (GLenum func);
    public void glDepthMask (GLboolean flag);
    public void glDepthRangef (GLclampf zNear, GLclampf zFar);
    public void glDetachShader (GLuint program, GLuint shader);
    public void glDisable (GLenum cap);
    public void glDisableVertexAttribArray (GLuint index);
    public void glDrawArrays (GLenum mode, GLint first, GLsizei count);
    public void glDrawElements (GLenum mode, GLsizei count, GLenum type, GLvoid* indices);
    public void glEnable (GLenum cap);
    public void glEnableVertexAttribArray (GLuint index);
    public void glFinish ();
    public void glFlush ();
    public void glFramebufferRenderbuffer (GLenum target, GLenum attachment, GLenum renderbuffertarget, GLuint renderbuffer);
    public void glFramebufferTexture2D (GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level);
    public void glFrontFace (GLenum mode);
    public void glGenBuffers (GLsizei n, GLuint* buffers);
    public void glGenerateMipmap (GLenum target);
    public void glGenFramebuffers (GLsizei n, GLuint* framebuffers);
    public void glGenRenderbuffers (GLsizei n, GLuint* renderbuffers);
    public void glGenTextures (GLsizei n, GLuint* textures);
    public void glGetActiveAttrib (GLuint program, GLuint index, GLsizei bufsize, GLsizei* length, GLint* size, GLenum* type, GLchar* name);
    public void glGetActiveUniform (GLuint program, GLuint index, GLsizei bufsize, GLsizei* length, GLint* size, GLenum* type, GLchar* name);
    public void glGetAttachedShaders (GLuint program, GLsizei maxcount, GLsizei* count, GLuint* shaders);
    public int glGetAttribLocation (GLuint program, string name);
    public void glGetBooleanv (GLenum pname, GLboolean* params);
    public void glGetBufferParameteriv (GLenum target, GLenum pname, GLint* params);
    public GLenum glGetError ();
    public void glGetFloatv (GLenum pname, GLfloat* params);
    public void glGetFramebufferAttachmentParameteriv (GLenum target, GLenum attachment, GLenum pname, GLint* params);
    public void glGetIntegerv (GLenum pname, GLint* params);
    public void glGetProgramiv (GLuint program, GLenum pname, GLint* params);
    public void glGetProgramInfoLog (GLuint program, GLsizei bufsize, GLsizei* length, GLchar* infolog);
    public void glGetRenderbufferParameteriv (GLenum target, GLenum pname, GLint* params);
    public void glGetShaderiv (GLuint shader, GLenum pname, GLint* params);
    public void glGetShaderInfoLog (GLuint shader, GLsizei bufsize, GLsizei* length, GLchar* infolog);
    public void glGetShaderPrecisionFormat (GLenum shadertype, GLenum precisiontype, GLint* range, GLint* precision);
    public void glGetShaderSource (GLuint shader, GLsizei bufsize, GLsizei* length, GLchar* source);
    public string glGetString (GLenum name);
    public void glGetTexParameterfv (GLenum target, GLenum pname, GLfloat* params);
    public void glGetTexParameteriv (GLenum target, GLenum pname, GLint* params);
    public void glGetUniformfv (GLuint program, GLint location, GLfloat* params);
    public void glGetUniformiv (GLuint program, GLint location, GLint* params);
    public int glGetUniformLocation (GLuint program, string name);
    public void glGetVertexAttribfv (GLuint index, GLenum pname, GLfloat* params);
    public void glGetVertexAttribiv (GLuint index, GLenum pname, GLint* params);
    public void glGetVertexAttribPointerv (GLuint index, GLenum pname, GLvoid** pointer);
    public void glHint (GLenum target, GLenum mode);
    public GLboolean glIsBuffer (GLuint buffer);
    public GLboolean glIsEnabled (GLenum cap);
    public GLboolean glIsFramebuffer (GLuint framebuffer);
    public GLboolean glIsProgram (GLuint program);
    public GLboolean glIsRenderbuffer (GLuint renderbuffer);
    public GLboolean glIsShader (GLuint shader);
    public GLboolean glIsTexture (GLuint texture);
    public void glLineWidth (GLfloat width);
    public void glLinkProgram (GLuint program);
    public void glPixelStorei (GLenum pname, GLint param);
    public void glPolygonOffset (GLfloat factor, GLfloat units);
    public void glReadPixels (GLint x, GLint y, GLsizei width, GLsizei height, GLenum format, GLenum type, void* pixels);
    public void glReleaseShaderCompiler ();
    public void glRenderbufferStorage (GLenum target, GLenum internalformat, GLsizei width, GLsizei height);
    public void glSampleCoverage (GLclampf value, GLboolean invert);
    public void glScissor (GLint x, GLint y, GLsizei width, GLsizei height);
    public void glShaderBinary (GLsizei n, GLuint* shaders, GLenum binaryformat, GLvoid* binary, GLsizei length);
    public void glShaderSource (GLuint shader, GLsizei count, out string source, GLint* length);
    public void glStencilFunc (GLenum func, GLint @ref, GLuint mask);
    public void glStencilFuncSeparate (GLenum face, GLenum func, GLint @ref, GLuint mask);
    public void glStencilMask (GLuint mask);
    public void glStencilMaskSeparate (GLenum face, GLuint mask);
    public void glStencilOp (GLenum fail, GLenum zfail, GLenum zpass);
    public void glStencilOpSeparate (GLenum face, GLenum fail, GLenum zfail, GLenum zpass);
    public void glTexImage2D (GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, GLvoid* pixels);
    public void glTexParameterf (GLenum target, GLenum pname, GLfloat param);
    public void glTexParameterfv (GLenum target, GLenum pname, GLfloat* params);
    public void glTexParameteri (GLenum target, GLenum pname, GLint param);
    public void glTexParameteriv (GLenum target, GLenum pname, GLint* params);
    public void glTexSubImage2D (GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLenum type, GLvoid* pixels);
    public void glUniform1f (GLint location, GLfloat x);
    public void glUniform1fv (GLint location, GLsizei count, GLfloat* v);
    public void glUniform1i (GLint location, GLint x);
    public void glUniform1iv (GLint location, GLsizei count, GLint* v);
    public void glUniform2f (GLint location, GLfloat x, GLfloat y);
    public void glUniform2fv (GLint location, GLsizei count, GLfloat* v);
    public void glUniform2i (GLint location, GLint x, GLint y);
    public void glUniform2iv (GLint location, GLsizei count, GLint* v);
    public void glUniform3f (GLint location, GLfloat x, GLfloat y, GLfloat z);
    public void glUniform3fv (GLint location, GLsizei count, GLfloat* v);
    public void glUniform3i (GLint location, GLint x, GLint y, GLint z);
    public void glUniform3iv (GLint location, GLsizei count, GLint* v);
    public void glUniform4f (GLint location, GLfloat x, GLfloat y, GLfloat z, GLfloat w);
    public void glUniform4fv (GLint location, GLsizei count, GLfloat* v);
    public void glUniform4i (GLint location, GLint x, GLint y, GLint z, GLint w);
    public void glUniform4iv (GLint location, GLsizei count, GLint* v);
    public void glUniformMatrix2fv (GLint location, GLsizei count, GLboolean transpose, GLfloat* value);
    public void glUniformMatrix3fv (GLint location, GLsizei count, GLboolean transpose, GLfloat* value);
    public void glUniformMatrix4fv (GLint location, GLsizei count, GLboolean transpose, GLfloat* value);
    public void glUseProgram (GLuint program);
    public void glValidateProgram (GLuint program);
    public void glVertexAttrib1f (GLuint indx, GLfloat x);
    public void glVertexAttrib1fv (GLuint indx, GLfloat* values);
    public void glVertexAttrib2f (GLuint indx, GLfloat x, GLfloat y);
    public void glVertexAttrib2fv (GLuint indx, GLfloat* values);
    public void glVertexAttrib3f (GLuint indx, GLfloat x, GLfloat y, GLfloat z);
    public void glVertexAttrib3fv (GLuint indx, GLfloat* values);
    public void glVertexAttrib4f (GLuint indx, GLfloat x, GLfloat y, GLfloat z, GLfloat w);
    public void glVertexAttrib4fv (GLuint indx, GLfloat* values);
    public void glVertexAttribPointer (GLuint indx, GLint size, GLenum type, GLboolean normalized, GLsizei stride, void* ptr);
    public void glViewport (GLint x, GLint y, GLsizei width, GLsizei height);
}

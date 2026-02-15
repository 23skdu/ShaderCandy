#ifndef GL_LOADER_H
#define GL_LOADER_H

#ifdef __linux__
#include <GL/gl.h>
#include <GL/glext.h>
#include <GL/glx.h>
#include <iostream>

// OpenGL 3.3+ function pointers
static PFNGLCREATEPROGRAMPROC glCreateProgram_ptr = nullptr;
static PFNGLDELETEPROGRAMPROC glDeleteProgram_ptr = nullptr;
static PFNGLUSEPROGRAMPROC glUseProgram_ptr = nullptr;
static PFNGLATTACHSHADERPROC glAttachShader_ptr = nullptr;
static PFNGLLINKPROGRAMPROC glLinkProgram_ptr = nullptr;
static PFNGLGETPROGRAMIVPROC glGetProgramiv_ptr = nullptr;
static PFNGLGETPROGRAMINFOLOGPROC glGetProgramInfoLog_ptr = nullptr;
static PFNGLCREATESHADERPROC glCreateShader_ptr = nullptr;
static PFNGLDELETESHADERPROC glDeleteShader_ptr = nullptr;
static PFNGLSHADERSOURCEPROC glShaderSource_ptr = nullptr;
static PFNGLCOMPILESHADERPROC glCompileShader_ptr = nullptr;
static PFNGLGETSHADERIVPROC glGetShaderiv_ptr = nullptr;
static PFNGLGETSHADERINFOLOGPROC glGetShaderInfoLog_ptr = nullptr;
static PFNGLGENBUFFERSPROC glGenBuffers_ptr = nullptr;
static PFNGLDELETEBUFFERSPROC glDeleteBuffers_ptr = nullptr;
static PFNGLBINDBUFFERPROC glBindBuffer_ptr = nullptr;
static PFNGLBUFFERDATAPROC glBufferData_ptr = nullptr;
static PFNGLBUFFERSUBDATAPROC glBufferSubData_ptr = nullptr;
static PFNGLGENVERTEXARRAYSPROC glGenVertexArrays_ptr = nullptr;
static PFNGLDELETEVERTEXARRAYSPROC glDeleteVertexArrays_ptr = nullptr;
static PFNGLBINDVERTEXARRAYPROC glBindVertexArray_ptr = nullptr;
static PFNGLENABLEVERTEXATTRIBARRAYPROC glEnableVertexAttribArray_ptr = nullptr;
static PFNGLVERTEXATTRIBPOINTERPROC glVertexAttribPointer_ptr = nullptr;
static PFNGLGETUNIFORMBLOCKINDEXPROC glGetUniformBlockIndex_ptr = nullptr;
static PFNGLUNIFORMBLOCKBINDINGPROC glUniformBlockBinding_ptr = nullptr;
static PFNGLBINDBUFFERBASEPROC glBindBufferBase_ptr = nullptr;
static PFNGLDELETEFRAMEBUFFERSPROC glDeleteFramebuffers_ptr = nullptr;
static PFNGLDELETERENDERBUFFERSPROC glDeleteRenderbuffers_ptr = nullptr;
static PFNGLGETUNIFORMLOCATIONPROC glGetUniformLocation_ptr = nullptr;
static PFNGLUNIFORM1FPROC glUniform1f_ptr = nullptr;
static PFNGLUNIFORM2FPROC glUniform2f_ptr = nullptr;
static PFNGLUNIFORM3FPROC glUniform3f_ptr = nullptr;
static PFNGLUNIFORM4FPROC glUniform4f_ptr = nullptr;
static PFNGLUNIFORM1IPROC glUniform1i_ptr = nullptr;
static PFNGLUNIFORMMATRIX4FVPROC glUniformMatrix4fv_ptr = nullptr;
static PFNGLGENFRAMEBUFFERSPROC glGenFramebuffers_ptr = nullptr;
static PFNGLBINDFRAMEBUFFERPROC glBindFramebuffer_ptr = nullptr;
static PFNGLFRAMEBUFFERTEXTURE2DPROC glFramebufferTexture2D_ptr = nullptr;
static PFNGLCHECKFRAMEBUFFERSTATUSPROC glCheckFramebufferStatus_ptr = nullptr;
static PFNGLGENRENDERBUFFERSPROC glGenRenderbuffers_ptr = nullptr;
static PFNGLBINDRENDERBUFFERPROC glBindRenderbuffer_ptr = nullptr;
static PFNGLRENDERBUFFERSTORAGEPROC glRenderbufferStorage_ptr = nullptr;
static PFNGLFRAMEBUFFERRENDERBUFFERPROC glFramebufferRenderbuffer_ptr = nullptr;
static PFNGLACTIVETEXTUREPROC glActiveTexture_ptr = nullptr;
static PFNGLGENERATEMIPMAPPROC glGenerateMipmap_ptr = nullptr;
static PFNGLUNIFORM1FVPROC glUniform1fv_ptr = nullptr;
static PFNGLGETUNIFORMFVPROC glGetUniformfv_ptr = nullptr;

// Macro wrappers
#define glCreateProgram glCreateProgram_ptr
#define glDeleteProgram glDeleteProgram_ptr
#define glUseProgram glUseProgram_ptr
#define glAttachShader glAttachShader_ptr
#define glLinkProgram glLinkProgram_ptr
#define glGetProgramiv glGetProgramiv_ptr
#define glGetProgramInfoLog glGetProgramInfoLog_ptr
#define glCreateShader glCreateShader_ptr
#define glDeleteShader glDeleteShader_ptr
#define glShaderSource glShaderSource_ptr
#define glCompileShader glCompileShader_ptr
#define glGetShaderiv glGetShaderiv_ptr
#define glGetShaderInfoLog glGetShaderInfoLog_ptr
#define glGenBuffers glGenBuffers_ptr
#define glDeleteBuffers glDeleteBuffers_ptr
#define glBindBuffer glBindBuffer_ptr
#define glBufferData glBufferData_ptr
#define glBufferSubData glBufferSubData_ptr
#define glGenVertexArrays glGenVertexArrays_ptr
#define glDeleteVertexArrays glDeleteVertexArrays_ptr
#define glBindVertexArray glBindVertexArray_ptr
#define glEnableVertexAttribArray glEnableVertexAttribArray_ptr
#define glVertexAttribPointer glVertexAttribPointer_ptr
#define glGetUniformBlockIndex glGetUniformBlockIndex_ptr
#define glUniformBlockBinding glUniformBlockBinding_ptr
#define glBindBufferBase glBindBufferBase_ptr
#define glDeleteFramebuffers glDeleteFramebuffers_ptr
#define glDeleteRenderbuffers glDeleteRenderbuffers_ptr
#define glGetUniformLocation glGetUniformLocation_ptr
#define glGetUniformfv glGetUniformfv_ptr
#define glUniform1f glUniform1f_ptr
#define glUniform2f glUniform2f_ptr
#define glUniform3f glUniform3f_ptr
#define glUniform4f glUniform4f_ptr
#define glUniform1i glUniform1i_ptr
#define glUniformMatrix4fv glUniformMatrix4fv_ptr
#define glGenFramebuffers glGenFramebuffers_ptr
#define glBindFramebuffer glBindFramebuffer_ptr
#define glFramebufferTexture2D glFramebufferTexture2D_ptr
#define glCheckFramebufferStatus glCheckFramebufferStatus_ptr
#define glGenRenderbuffers glGenRenderbuffers_ptr
#define glBindRenderbuffer glBindRenderbuffer_ptr
#define glRenderbufferStorage glRenderbufferStorage_ptr
#define glFramebufferRenderbuffer glFramebufferRenderbuffer_ptr
#define glActiveTexture glActiveTexture_ptr
#define glGenerateMipmap glGenerateMipmap_ptr
#define glUniform1fv glUniform1fv_ptr

inline bool InitializeGLLoader() {
    glCreateProgram_ptr = (PFNGLCREATEPROGRAMPROC)glXGetProcAddress((const GLubyte*)"glCreateProgram");
    glDeleteProgram_ptr = (PFNGLDELETEPROGRAMPROC)glXGetProcAddress((const GLubyte*)"glDeleteProgram");
    glUseProgram_ptr = (PFNGLUSEPROGRAMPROC)glXGetProcAddress((const GLubyte*)"glUseProgram");
    glAttachShader_ptr = (PFNGLATTACHSHADERPROC)glXGetProcAddress((const GLubyte*)"glAttachShader");
    glLinkProgram_ptr = (PFNGLLINKPROGRAMPROC)glXGetProcAddress((const GLubyte*)"glLinkProgram");
    glGetProgramiv_ptr = (PFNGLGETPROGRAMIVPROC)glXGetProcAddress((const GLubyte*)"glGetProgramiv");
    glGetProgramInfoLog_ptr = (PFNGLGETPROGRAMINFOLOGPROC)glXGetProcAddress((const GLubyte*)"glGetProgramInfoLog");
    glCreateShader_ptr = (PFNGLCREATESHADERPROC)glXGetProcAddress((const GLubyte*)"glCreateShader");
    glDeleteShader_ptr = (PFNGLDELETESHADERPROC)glXGetProcAddress((const GLubyte*)"glDeleteShader");
    glShaderSource_ptr = (PFNGLSHADERSOURCEPROC)glXGetProcAddress((const GLubyte*)"glShaderSource");
    glCompileShader_ptr = (PFNGLCOMPILESHADERPROC)glXGetProcAddress((const GLubyte*)"glCompileShader");
    glGetShaderiv_ptr = (PFNGLGETSHADERIVPROC)glXGetProcAddress((const GLubyte*)"glGetShaderiv");
    glGetShaderInfoLog_ptr = (PFNGLGETSHADERINFOLOGPROC)glXGetProcAddress((const GLubyte*)"glGetShaderInfoLog");
    glGenBuffers_ptr = (PFNGLGENBUFFERSPROC)glXGetProcAddress((const GLubyte*)"glGenBuffers");
    glDeleteBuffers_ptr = (PFNGLDELETEBUFFERSPROC)glXGetProcAddress((const GLubyte*)"glDeleteBuffers");
    glBindBuffer_ptr = (PFNGLBINDBUFFERPROC)glXGetProcAddress((const GLubyte*)"glBindBuffer");
    glBufferData_ptr = (PFNGLBUFFERDATAPROC)glXGetProcAddress((const GLubyte*)"glBufferData");
    glBufferSubData_ptr = (PFNGLBUFFERSUBDATAPROC)glXGetProcAddress((const GLubyte*)"glBufferSubData");
    glGenVertexArrays_ptr = (PFNGLGENVERTEXARRAYSPROC)glXGetProcAddress((const GLubyte*)"glGenVertexArrays");
    glDeleteVertexArrays_ptr = (PFNGLDELETEVERTEXARRAYSPROC)glXGetProcAddress((const GLubyte*)"glDeleteVertexArrays");
    glBindVertexArray_ptr = (PFNGLBINDVERTEXARRAYPROC)glXGetProcAddress((const GLubyte*)"glBindVertexArray");
    glEnableVertexAttribArray_ptr = (PFNGLENABLEVERTEXATTRIBARRAYPROC)glXGetProcAddress((const GLubyte*)"glEnableVertexAttribArray");
    glVertexAttribPointer_ptr = (PFNGLVERTEXATTRIBPOINTERPROC)glXGetProcAddress((const GLubyte*)"glVertexAttribPointer");
    glGetUniformBlockIndex_ptr = (PFNGLGETUNIFORMBLOCKINDEXPROC)glXGetProcAddress((const GLubyte*)"glGetUniformBlockIndex");
    glUniformBlockBinding_ptr = (PFNGLUNIFORMBLOCKBINDINGPROC)glXGetProcAddress((const GLubyte*)"glUniformBlockBinding");
    glBindBufferBase_ptr = (PFNGLBINDBUFFERBASEPROC)glXGetProcAddress((const GLubyte*)"glBindBufferBase");
    glDeleteFramebuffers_ptr = (PFNGLDELETEFRAMEBUFFERSPROC)glXGetProcAddress((const GLubyte*)"glDeleteFramebuffers");
    glDeleteRenderbuffers_ptr = (PFNGLDELETERENDERBUFFERSPROC)glXGetProcAddress((const GLubyte*)"glDeleteRenderbuffers");
    glGetUniformLocation_ptr = (PFNGLGETUNIFORMLOCATIONPROC)glXGetProcAddress((const GLubyte*)"glGetUniformLocation");
    glGetUniformfv_ptr = (PFNGLGETUNIFORMFVPROC)glXGetProcAddress((const GLubyte*)"glGetUniformfv");
    glUniform1f_ptr = (PFNGLUNIFORM1FPROC)glXGetProcAddress((const GLubyte*)"glUniform1f");
    glUniform2f_ptr = (PFNGLUNIFORM2FPROC)glXGetProcAddress((const GLubyte*)"glUniform2f");
    glUniform3f_ptr = (PFNGLUNIFORM3FPROC)glXGetProcAddress((const GLubyte*)"glUniform3f");
    glUniform4f_ptr = (PFNGLUNIFORM4FPROC)glXGetProcAddress((const GLubyte*)"glUniform4f");
    glUniform1i_ptr = (PFNGLUNIFORM1IPROC)glXGetProcAddress((const GLubyte*)"glUniform1i");
    glUniformMatrix4fv_ptr = (PFNGLUNIFORMMATRIX4FVPROC)glXGetProcAddress((const GLubyte*)"glUniformMatrix4fv");
    glGenFramebuffers_ptr = (PFNGLGENFRAMEBUFFERSPROC)glXGetProcAddress((const GLubyte*)"glGenFramebuffers");
    glBindFramebuffer_ptr = (PFNGLBINDFRAMEBUFFERPROC)glXGetProcAddress((const GLubyte*)"glBindFramebuffer");
    glFramebufferTexture2D_ptr = (PFNGLFRAMEBUFFERTEXTURE2DPROC)glXGetProcAddress((const GLubyte*)"glFramebufferTexture2D");
    glCheckFramebufferStatus_ptr = (PFNGLCHECKFRAMEBUFFERSTATUSPROC)glXGetProcAddress((const GLubyte*)"glCheckFramebufferStatus");
    glGenRenderbuffers_ptr = (PFNGLGENRENDERBUFFERSPROC)glXGetProcAddress((const GLubyte*)"glGenRenderbuffers");
    glBindRenderbuffer_ptr = (PFNGLBINDRENDERBUFFERPROC)glXGetProcAddress((const GLubyte*)"glBindRenderbuffer");
    glRenderbufferStorage_ptr = (PFNGLRENDERBUFFERSTORAGEPROC)glXGetProcAddress((const GLubyte*)"glRenderbufferStorage");
    glFramebufferRenderbuffer_ptr = (PFNGLFRAMEBUFFERRENDERBUFFERPROC)glXGetProcAddress((const GLubyte*)"glFramebufferRenderbuffer");
    glActiveTexture_ptr = (PFNGLACTIVETEXTUREPROC)glXGetProcAddress((const GLubyte*)"glActiveTexture");
    glGenerateMipmap_ptr = (PFNGLGENERATEMIPMAPPROC)glXGetProcAddress((const GLubyte*)"glGenerateMipmap");
    glUniform1fv_ptr = (PFNGLUNIFORM1FVPROC)glXGetProcAddress((const GLubyte*)"glUniform1fv");

    if (!glCreateProgram_ptr) {
        std::cerr << "Failed to load OpenGL functions" << std::endl;
        return false;
    }
    return true;
}

#endif // __linux__

#endif // GL_LOADER_H

#ifndef LINUX_STUBS_H
#define LINUX_STUBS_H

#ifdef __APPLE__
// Stubs for Linux-specific types and constants to satisfy macOS IDEs
#include <OpenGL/gl3.h>
#include <OpenGL/gl3ext.h>

// GL types usually in GL/gl.h if not in gl3.h
#ifndef GL_GLEXT_PROTOTYPES
#define GL_GLEXT_PROTOTYPES
#endif

// GLFW stubs
typedef struct GLFWwindow GLFWwindow;
typedef struct GLFWmonitor GLFWmonitor;
typedef void (*GLFWkeyfun)(GLFWwindow *, int, int, int, int);
typedef void (*GLFWmousebuttonfun)(GLFWwindow *, int, int, int);
typedef void (*GLFWcursorposfun)(GLFWwindow *, double, double);
typedef void (*GLFWscrollfun)(GLFWwindow *, double, double);
typedef void (*GLFWframebuffersizefun)(GLFWwindow *, int, int);

typedef struct {
  int width;
  int height;
  int redBits;
  int greenBits;
  int blueBits;
  int refreshRate;
} GLFWvidmode;

#define GLFW_CONTEXT_VERSION_MAJOR 0x00021002
#define GLFW_CONTEXT_VERSION_MINOR 0x00021003
#define GLFW_OPENGL_PROFILE 0x00022001
#define GLFW_OPENGL_CORE_PROFILE 0x00032001
#define GLFW_TRUE 1
#define GLFW_FALSE 0
#define GLFW_PRESS 1
#define GLFW_RELEASE 0

#define GLFW_KEY_ESCAPE 256
#define GLFW_KEY_RIGHT 262
#define GLFW_KEY_LEFT 263
#define GLFW_KEY_DOWN 264
#define GLFW_KEY_UP 265
#define GLFW_KEY_F 70
#define GLFW_KEY_F11 300
#define GLFW_KEY_SPACE 32
#define GLFW_KEY_R 82
#define GLFW_MOUSE_BUTTON_LEFT 0
#define GLFW_MOUSE_BUTTON_RIGHT 1

#define glfwInit() 1
#define glfwWindowHint(h, v) (void)0
#define glfwGetPrimaryMonitor() ((GLFWmonitor *)0)
#define glfwCreateWindow(w, h, t, m, s) ((GLFWwindow *)0)
#define glfwTerminate() (void)0
#define glfwMakeContextCurrent(w) (void)0
#define glfwSwapInterval(i) (void)0
#define glfwSetWindowUserPointer(w, p) (void)0
#define glfwGetWindowUserPointer(w) ((void *)0)
#define glfwSetKeyCallback(w, c) ((GLFWkeyfun)0)
#define glfwSetMouseButtonCallback(w, c) ((GLFWmousebuttonfun)0)
#define glfwSetCursorPosCallback(w, c) ((GLFWcursorposfun)0)
#define glfwSetScrollCallback(w, c) ((GLFWscrollfun)0)
#define glfwSetFramebufferSizeCallback(w, c) ((GLFWframebuffersizefun)0)
#define glfwDestroyWindow(w) (void)0
#define glfwWindowShouldClose(w) 0
#define glfwPollEvents() (void)0
#define glfwSwapBuffers(w) (void)0
#define glfwGetTime() 1.0
#define glfwGetFramebufferSize(w, wi, h) (void)0
#define glfwSetWindowShouldClose(w, v) (void)0
#define glfwGetKey(w, k) 0
#define glfwGetMouseButton(w, b) 0
#define glfwGetCursorPos(w, x, y) (void)0
#define glfwSetWindowTitle(w, t) (void)0
#define glfwGetWindowMonitor(w) ((GLFWmonitor *)0)
#define glfwGetWindowPos(w, x, y) (void)0
#define glfwGetWindowSize(w, x, y) (void)0
#define glfwGetVideoMode(m) ((GLFWvidmode *)0)
#define glfwSetWindowMonitor(w, m, x, y, wi, h, r) (void)0

// X11 stubs
typedef struct _XDisplay Display;
typedef unsigned long Window;
typedef unsigned long Atom;
typedef unsigned long VisualID;
typedef unsigned long Cursor;
typedef unsigned long Pixmap;
typedef unsigned long Colormap;
typedef unsigned long GContext;
typedef unsigned long KeySym;

typedef struct {
  int type;
  Window window;
  int x, y;
} XAnyEvent;
typedef struct {
  int type;
  unsigned int state;
  unsigned int keycode;
} XKeyEvent;
typedef struct {
  int type;
  int x, y;
} XMotionEvent;
typedef struct {
  int type;
  int x, y;
  unsigned int button;
} XButtonEvent;
typedef struct {
  int type;
  int width, height;
} XConfigureEvent;

typedef union _XEvent {
  int type;
  XAnyEvent xany;
  XKeyEvent xkey;
  XMotionEvent xmotion;
  XButtonEvent xbutton;
  XConfigureEvent xconfigure;
  long pad[24];
} XEvent;

typedef struct _XVisualInfo {
  void *visual;
  VisualID visualid;
  int screen;
  int depth;
  int c_class;
  unsigned long red_mask;
  unsigned long green_mask;
  unsigned long blue_mask;
  int colormap_size;
  int bits_per_rgb;
} XVisualInfo;

typedef struct _GLXContext RecGLXContext;
typedef RecGLXContext *GLXContext;
typedef void *GLXFBConfig;

typedef struct _XWindowAttributes {
  int x, y;
  int width, height;
  int border_width;
  int depth;
  void *visual;
  Window root;
  int c_class;
  int bit_gravity;
  int win_gravity;
  int backing_store;
  unsigned long backing_planes;
  unsigned long backing_pixel;
  int save_under;
  Colormap colormap;
  int map_installed;
  int map_state;
  long all_event_masks;
  long your_event_mask;
  long do_not_propagate_mask;
  int override_redirect;
  void *screen;
  long event_mask;
} XWindowAttributes;

typedef XWindowAttributes XSetWindowAttributes;

// Wayland/EGL stubs
typedef void *EGLDisplay;
typedef void *EGLConfig;
typedef void *EGLContext;
typedef void *EGLSurface;
#define EGL_NO_DISPLAY ((EGLDisplay)0)
#define EGL_NO_CONTEXT ((EGLContext)0)
#define EGL_NO_SURFACE ((EGLSurface)0)

// X11 constants
#define None 0
#define AllocNone 0
#define ExposureMask (1L << 1)
#define KeyPressMask (1L << 0)
#define StructureNotifyMask (1L << 17)
#define ButtonPressMask (1L << 2)
#define PointerMotionMask (1L << 6)
#define True 1
#define False 0
#define KeyPress 2
#define ButtonPress 4
#define MotionNotify 6
#define ConfigureNotify 22

#define XK_Right 0xFF53
#define XK_Escape 0xFF1B
#define XK_q 0x0071

// GLX constants
#define GLX_X_RENDERABLE 0x8003
#define GLX_DRAWABLE_TYPE 0x8010
#define GLX_WINDOW_BIT 0x00000001
#define GLX_PIXMAP_BIT 0x00000002
#define GLX_RENDER_TYPE 0x8011
#define GLX_RGBA_BIT 0x00000001
#define GLX_X_VISUAL_TYPE 0x22
#define GLX_TRUE_COLOR 0x8002
#define GLX_RED_SIZE 8
#define GLX_GREEN_SIZE 9
#define GLX_BLUE_SIZE 10
#define GLX_ALPHA_SIZE 11
#define GLX_DEPTH_SIZE 12
#define GLX_STENCIL_SIZE 13

// X11 function stubs (macros)
#define XOpenDisplay(x) ((Display *)0)
#define DefaultScreen(d) 0
#define RootWindow(d, s) 0
#define XGetWindowAttributes(d, w, a) 1
#define XCompositeQueryExtension(d, e, f) 1
#define XCloseDisplay(d) 1
#define XFlush(d) (void)0
#define XSelectInput(d, w, m) 1
#define XNextEvent(d, e) 1
#define XCheckTypedWindowEvent(d, w, t, e) 1
#define XPending(d) 0
#define XInternAtom(d, n, o) 0
#define XChangeProperty(d, w, a, t, f, m, da, n) 1
#define XFree(p) (void)0
#define XCreateWindow(d, r, x, y, w, h, b, de, c, v, m, a) 0
#define XMapWindow(d, w) (void)0
#define XStoreName(d, w, n) (void)0
#define XCreateColormap(d, w, v, a) 0
#define XDestroyWindow(d, w) (void)0
#define XLookupKeysym(e, i) 0

// GLX function stubs
#define glXChooseFBConfig(d, s, a, n) ((void **)0)
#define glXGetVisualFromFBConfig(d, c) ((XVisualInfo *)0)
#define glXCreateNewContext(d, f, r, s, d2) ((GLXContext)0)
#define glXMakeCurrent(d, w, c) 1
#define glXSwapBuffers(d, w) (void)0
#define glXDestroyContext(d, c) (void)0

#endif // __APPLE__

#endif // LINUX_STUBS_H

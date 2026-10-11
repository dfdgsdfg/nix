"""Exercise kime through a mapped GtkEntry's own IM context under Xvfb.

An unmapped widget skips cursor layout and misses the Space/commit crash.
G_DEBUG=fatal-criticals makes the Pango assertion a build failure.
"""

import ctypes as c
import os
import sys
import time


gtk = c.CDLL(sys.argv[1])
P, I, U, S = c.c_void_p, c.c_int, c.c_uint, c.c_char_p


def bind(name, result, *args):
    fn = getattr(gtk, name)
    fn.restype = result
    fn.argtypes = args
    return fn


init = bind("gtk_init_check", I)
entry_new = bind("gtk_entry_new", P)
window_new = bind("gtk_window_new", P)
set_child = bind("gtk_window_set_child", None, P, P)
present = bind("gtk_window_present", None, P)
destroy = bind("gtk_window_destroy", None, P)
grab_focus = bind("gtk_widget_grab_focus", I, P)
first_child = bind("gtk_widget_get_first_child", P, P)
controllers = bind("gtk_widget_observe_controllers", P, P)
item_count = bind("g_list_model_get_n_items", U, P)
item = bind("g_list_model_get_item", P, P, U)
key_type = bind("gtk_event_controller_key_get_type", c.c_size_t)
is_a = bind("g_type_check_instance_is_a", I, P, c.c_size_t)
get_context = bind("gtk_event_controller_key_get_im_context", P, P)
unref = bind("g_object_unref", None, P)
get_text = bind("gtk_editable_get_text", S, P)
display_get = bind("gdk_display_get_default", P)
surface_new = bind("gdk_surface_new_toplevel", P, P)
surface_destroy = bind("gdk_surface_destroy", None, P)
seat_get = bind("gdk_display_get_default_seat", P, P)
keyboard_get = bind("gdk_seat_get_keyboard", P, P)
focus_in = bind("gtk_im_context_focus_in", None, P)
focus_out = bind("gtk_im_context_focus_out", None, P)
reset = bind("gtk_im_context_reset", None, P)
filter_key = bind("gtk_im_context_filter_key", I, P, I, P, P, U, U, U, I)
iterate = bind("g_main_context_iteration", I, P, I)
connect = bind("g_signal_connect_data", c.c_ulong, P, S, P, P, P, I)
disconnect = bind("g_signal_handler_disconnect", None, P, c.c_ulong)


def pump():
    for _ in range(5):
        while iterate(None, False):
            pass
        time.sleep(0.01)


assert init()
display = display_get()
surface = surface_new(display)
keyboard = keyboard_get(seat_get(display))
keys = dict(zip("gksrmfdjato", [42, 45, 39, 27, 58, 41, 40, 44, 38, 28, 32]))


def case(label, letters, suffix, expected, action=None):
    window, entry = window_new(), entry_new()
    set_child(window, entry)
    present(window)
    grab_focus(entry)
    pump()
    model = controllers(first_child(entry))
    context = None
    for n in range(item_count(model)):
        ctl = item(model, n)
        if is_a(ctl, key_type()):
            context = get_context(ctl)
        unref(ctl)
        if context:
            break
    unref(model)
    assert context, "GtkText input context missing"
    focus_in(context)

    def key(code):
        handled = filter_key(context, True, surface, keyboard, 0, code, 0, 0)
        pump()
        return handled

    key(130)  # Hangul key, as produced by the Caps Lock mapping.
    for letter in letters:
        key(keys[letter])
    handler = None
    commits = []
    if action == "reentrant-reset":
        @c.CFUNCTYPE(None, P, S, P)
        def on_commit(ctx, text, _data):
            commits.append(text.decode())
            if len(commits) > 4:
                os._exit(90)
            reset(ctx)

        handler = connect(context, b"commit", on_commit, None, None, 0)
    for code in suffix:
        handled = key(code)
        if code in (36, 23):  # Return and Tab must reach the widget once.
            assert not handled, (label, "control key swallowed", code)
    if action == "focus-out":
        focus_out(context)
    if action == "reset":
        reset(context)
    pump()
    actual = get_text(entry).decode()
    assert actual == expected, (label, actual, expected)
    if handler:
        disconnect(context, handler)
        assert commits == ["한"], commits
    print(f"PASS {label}: {actual!r}", flush=True)
    destroy(window)
    pump()


case("Space after Hangul", "gks", [65], "한 ")
case("multiple syllables", "gksrmf", [65], "한글 ")
case("resyllabification", "rksk", [65], "가나 ")
case("Backspace in preedit", "gks", [22, 65], "하 ")
case("Return after Hangul", "gks", [36], "한")
case("Tab after Hangul", "gks", [23], "한")
case("focus out during preedit", "gks", [], "한", "focus-out")
case("reset during preedit", "gks", [], "한", "reset")
case("reset from commit handler", "gks", [36], "한", "reentrant-reset")
surface_destroy(surface)
unref(surface)

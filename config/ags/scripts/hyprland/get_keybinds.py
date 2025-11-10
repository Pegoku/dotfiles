#!/usr/bin/env python3
import argparse
import re
import os
from os.path import expandvars as os_expandvars
from pathlib import Path
from typing import Dict, List

TITLE_REGEX = "#+!"
HIDE_COMMENT = "[hidden]"
MOD_SEPARATORS = ['+', ' ']
COMMENT_BIND_PATTERN = "#/#"

parser = argparse.ArgumentParser(description='Hyprland keybind reader')
parser.add_argument('--path', type=str, default="$HOME/.config/hypr/hyprland.conf", help='path to keybind file (sourcing isn\'t supported)')
args = parser.parse_args()
content_lines = []
reading_line = 0

# Little Parser made for hyprland keybindings conf file
Variables: Dict[str, str] = {}


class KeyBinding(dict):
    def __init__(self, mods, key, dispatcher, params, comment) -> None:
        self["mods"] = mods
        self["key"] = key
        self["dispatcher"] = dispatcher
        self["params"] = params
        self["comment"] = comment

class Section(dict):
    def __init__(self, children, keybinds, name) -> None:
        self["children"] = children
        self["keybinds"] = keybinds
        self["name"] = name


def read_content(path: str) -> str:
    """Read a file as UTF-8, tolerating stray bytes, and return 'error' if unreadable."""
    resolved = os.path.expanduser(os.path.expandvars(path))
    if not os.access(resolved, os.R_OK):
        return "error"
    with open(resolved, "r", encoding="utf-8", errors="replace") as file:
        return file.read()


def expand_sources(raw: str, base_path: str, seen: set[str] | None = None) -> str:
    """Inline `source = file` directives recursively.
    Paths are expanded for ~ and env vars; relative paths resolve against base_path's directory.
    """
    if seen is None:
        seen = set()
    lines = raw.splitlines()
    out_lines: list[str] = []
    base_dir = str(Path(os.path.expanduser(os.path.expandvars(base_path))).parent)
    for ln in lines:
        stripped = ln.strip()
        if stripped.startswith("source") and "=" in stripped:
            try:
                _, rhs = stripped.split("=", 1)
                src_path = rhs.strip().strip('\"\'')
                candidate = os.path.expanduser(os.path.expandvars(src_path))
                if not os.path.isabs(candidate):
                    candidate = os.path.join(base_dir, candidate)
                canon = os.path.realpath(candidate)
                if canon in seen:
                    # Avoid include loops
                    continue
                seen.add(canon)
                included_raw = read_content(canon)
                if included_raw != "error":
                    out_lines.append(f"# -- begin source: {src_path} --")
                    out_lines.extend(expand_sources(included_raw, canon, seen).splitlines())
                    out_lines.append(f"# -- end source: {src_path} --")
                else:
                    # Keep original line if include missing, to aid debugging
                    out_lines.append(ln)
            except Exception:
                out_lines.append(ln)
        else:
            out_lines.append(ln)
    return "\n".join(out_lines)


def autogenerate_comment(dispatcher: str, params: str = "") -> str:
    match dispatcher:

        case "resizewindow":
            return "Resize window"

        case "movewindow":
            if(params == ""):
                return "Move window"
            else:
                return "Window: move in {} direction".format({
                    "l": "left",
                    "r": "right",
                    "u": "up",
                    "d": "down",
                }.get(params, "null"))

        case "pin":
            return "Window: pin (show on all workspaces)"

        case "splitratio":
            return "Window split ratio {}".format(params)

        case "togglefloating":
            return "Float/unfloat window"

        case "resizeactive":
            return "Resize window by {}".format(params)

        case "killactive":
            return "Close window"

        case "fullscreen":
            return "Toggle {}".format(
                {
                    "0": "fullscreen",
                    "1": "maximization",
                    "2": "fullscreen on Hyprland's side",
                }.get(params, "null")
            )

        case "fakefullscreen":
            return "Toggle fake fullscreen"

        case "workspace":
            if params == "+1":
                return "Workspace: focus right"
            elif params == "-1":
                return "Workspace: focus left"
            return "Focus workspace {}".format(params)

        case "movefocus":
            return "Window: move focus {}".format(
                {
                    "l": "left",
                    "r": "right",
                    "u": "up",
                    "d": "down",
                }.get(params, "null")
            )

        case "swapwindow":
            return "Window: swap in {} direction".format(
                {
                    "l": "left",
                    "r": "right",
                    "u": "up",
                    "d": "down",
                }.get(params, "null")
            )

        case "movetoworkspace":
            if params == "+1":
                return "Window: move to right workspace (non-silent)"
            elif params == "-1":
                return "Window: move to left workspace (non-silent)"
            return "Window: move to workspace {} (non-silent)".format(params)

        case "movetoworkspacesilent":
            if params == "+1":
                return "Window: move to right workspace"
            elif params == "-1":
                return "Window: move to right workspace"
            return "Window: move to workspace {}".format(params)

        case "togglespecialworkspace":
            return "Workspace: toggle special"

        case "exec":
            return "Execute: {}".format(params)

        case _:
            return ""

def get_keybind_at_line(line_number, line_start = 0):
    global content_lines
    line = content_lines[line_number]
    _, keys = line.split("=", 1)
    keys, *comment = keys.split("#", 1)

    mods, key, dispatcher, *params = list(map(str.strip, keys.split(",", 4)))
    params = "".join(map(str.strip, params))

    # Remove empty spaces
    comment = list(map(str.strip, comment))
    # Add comment if it exists, else generate it
    if comment:
        comment = comment[0]
        if comment.startswith("[hidden]"):
            return None
    else:
        comment = autogenerate_comment(dispatcher, params)

    if mods:
        modstring = mods + MOD_SEPARATORS[0] # Add separator at end to ensure last mod is read
        mods = []
        p = 0
        for index, char in enumerate(modstring):
            if(char in MOD_SEPARATORS):
                if(index - p > 1):
                    mods.append(modstring[p:index])
                p = index+1
    else:
        mods = []

    return KeyBinding(mods, key, dispatcher, params, comment)

def get_binds_recursive(current_content, scope):
    global content_lines
    global reading_line
    # print("get_binds_recursive({0}, {1}) [@L{2}]".format(current_content, scope, reading_line + 1))
    while reading_line < len(content_lines): # TODO: Adjust condition
        line = content_lines[reading_line]
        heading_search_result = re.search(TITLE_REGEX, line)
        # print("Read line {0}: {1}\tisHeading: {2}".format(reading_line + 1, content_lines[reading_line], "[{0}, {1}, {2}]".format(heading_search_result.start(), heading_search_result.start() == 0, ((heading_search_result != None) and (heading_search_result.start() == 0))) if heading_search_result != None else "No"))
        if ((heading_search_result != None) and (heading_search_result.start() == 0)): # Found title
            # Determine scope
            heading_scope = line.find('!')
            # Lower? Return
            if(heading_scope <= scope):
                reading_line -= 1
                return current_content

            section_name = line[(heading_scope+1):].strip()
            # print("[[ Found h{0} at line {1} ]] {2}".format(heading_scope, reading_line+1, content_lines[reading_line]))
            reading_line += 1
            current_content["children"].append(get_binds_recursive(Section([], [], section_name), heading_scope))

        elif line.startswith(COMMENT_BIND_PATTERN):
            keybind = get_keybind_at_line(reading_line, line_start=len(COMMENT_BIND_PATTERN))
            if(keybind != None):
                current_content["keybinds"].append(keybind)

        elif line == "" or not line.lstrip().startswith("bind"): # Comment, ignore
            pass

        else: # Normal keybind
            keybind = get_keybind_at_line(reading_line)
            if(keybind != None):
                current_content["keybinds"].append(keybind)

        reading_line += 1

    return current_content;

def parse_keys(path: str) -> Dict[str, List[KeyBinding]]:
    """Parse the hyprland keybind config into a nested Section structure.
    Returns the string "error" if the file is missing or empty so the caller can
    propagate this sentinel. Includes are expanded via `source =`.
    """
    global content_lines, reading_line
    raw = read_content(path)
    if raw == "error" or raw.strip() == "":
        return "error"
    raw_expanded = expand_sources(raw, path)
    content_lines = raw_expanded.splitlines()
    if len(content_lines) == 0:
        return "error"
    reading_line = 0
    return get_binds_recursive(Section([], [], ""), 0)


if __name__ == "__main__":
    # Try to import json; if it fails (e.g., corrupted stdlib), fall back to a tiny serializer
    json_dumps = None
    try:
        import json  # type: ignore
        json_dumps = json.dumps
    except Exception as e:
        import sys, traceback
        tb = traceback.format_exc(limit=5)
        sys.stderr.write(f"[get_keybinds] Failed to import json: {e}\n{tb}\n")

        def _esc_str(s: str) -> str:
            out = []
            for ch in s:
                code = ord(ch)
                if ch == '"':
                    out.append('\\"')
                elif ch == '\\':
                    out.append('\\\\')
                elif ch == '\b':
                    out.append('\\b')
                elif ch == '\f':
                    out.append('\\f')
                elif ch == '\n':
                    out.append('\\n')
                elif ch == '\r':
                    out.append('\\r')
                elif ch == '\t':
                    out.append('\\t')
                elif code < 0x20:
                    out.append('\\u%04x' % code)
                else:
                    out.append(ch)
            return '"' + ''.join(out) + '"'

        def _to_json(o):
            if o is None:
                return 'null'
            if isinstance(o, bool):
                return 'true' if o else 'false'
            if isinstance(o, (int, float)):
                return str(o)
            if isinstance(o, str):
                return _esc_str(o)
            if isinstance(o, dict):
                items = []
                for k, v in o.items():
                    items.append(_esc_str(str(k)) + ':' + _to_json(v))
                return '{' + ','.join(items) + '}'
            if isinstance(o, (list, tuple)):
                return '[' + ','.join(_to_json(x) for x in o) + ']'
            return _esc_str(str(o))

        json_dumps = _to_json

    try:
        ParsedKeys = parse_keys(args.path)
        print(json_dumps(ParsedKeys))
    except Exception as e:
        import sys, traceback
        tb = traceback.format_exc(limit=5)
        sys.stderr.write(f"[get_keybinds] Unexpected error: {e}\n{tb}\n")
        try:
            print(json_dumps("error"))
        except Exception:
            print('"error"')

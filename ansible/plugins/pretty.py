# pretty.py
DOCUMENTATION = r"""
callback: pretty
type: stdout
short_description: Emoji + colored status stdout callback
extends_documentation_fragment:
  - default_callback
  - result_format_callback
"""

from ansible.plugins.callback.default import CallbackModule as DefaultCb
from ansible.utils.color import colorize, hostcolor
import os

class CallbackModule(DefaultCb):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE    = "stdout"
    CALLBACK_NAME    = "pretty"
    CALLBACK_NEEDS_WHITELIST = True

    STATUS_EMOJI = {
        "ok":          ("✅", "green"),
        "changed":     ("🔄️", "yellow"),
        "skipped":     ("⏭️", "blue"),
        "failed":      ("❌", "red"),
        "unreachable": ("🚫", "red"),
        "warning":     ("⚠️", "yellow"),
        "info":        ("ℹ️", "cyan"),
    }

    LABELS = {
        "ok":          "Successful",
        "changed":     "Changes",
        "skipped":     "Skipped",
        "failed":      "Failed",
        "unreachable": "Unreachable",
        "warning":     "Warnings",
        "info":        "Info",
    }

    def __init__(self, display=None):
        super().__init__()
        self._current_role = None
        self._last_role = None
        self._current_handler_role = None
        # Feature flags for portability/log sinks
        self._no_color = bool(os.environ.get("NO_COLOR") or os.environ.get("ANSIBLE_NOCOLOR"))
        self._no_emoji = bool(os.environ.get("ANSIBLE_NO_EMOJI"))
        self._printed_handler_roles = set()

    def v2_runner_on_start(self, host, task):
        return

    def v2_playbook_on_task_start(self, task, is_conditional):
        role_obj = getattr(task, '_role', None)
        if role_obj:
            role_name = role_obj.get_name() or getattr(role_obj, "_role_name", None)
            if role_name and role_name != self._current_role:
                header = f"▶️ {role_name} role"
                line    = '─' * (len(header) + 2)
                self._display.display("", screen_only=True)
                self._display.display(header, color='cyan' if not self._no_color else None, screen_only=True)
                self._display.display(line,   color='cyan' if not self._no_color else None, screen_only=True)
                self._current_role = role_name
    
    def v2_playbook_on_play_start(self, play):
        self._play = play
        title = play.get_name().strip() or play._file_name or 'Mystery Playbook'
        min_total = 40
        inner = max(min_total - 2, len(title))
        top    = "╭" + "─" * inner + "╮"
        middle = "│" + title.center(inner) + "│"
        bottom = "╰" + "─" * inner + "╯"
        self._display.display("", screen_only=True)
        for line in (top, middle, bottom):
            self._display.display(line, color='magenta' if not self._no_color else None, screen_only=True)
        self._printed_handler_roles = set()

    # —— Override includes to get an emoji —— #
    def v2_playbook_on_include(self, included_file):
        hosts_attr = getattr(included_file, "_hosts", []) or []
        hosts = ", ".join(getattr(h, "name", str(h)) for h in hosts_attr)
        filename = getattr(included_file, "_filename", None) or getattr(included_file, "_load_name", "included content")
        emoji, color = self._status("info")
        self._display.display(f"[{hosts}] {emoji} Prepared for next role: {filename} ", color=None, newline=False)
        self._display.display(f"(Done)", color=color)

    # —— Per‐task callbacks —— #
    def v2_runner_on_ok(self, result):
        task_obj = getattr(result, "_task", None)
        action = getattr(task_obj, "action", "") or ""

        if action.endswith("debug"):
            host = result._host.get_name()
            args = getattr(task_obj, "args", {}) or {}
            data = result._result or {}

            # 1) msg: ...
            if "msg" in args and data.get("msg") not in (None, ""):
                for line in str(data["msg"]).splitlines():
                    self._display.display(f" {' ' * len(host)}  {line}", color=None if self._no_color else "white")
                return
            # 2) var: my_var
            elif "var" in args:
                varname = args["var"]
                val = data.get(varname)
                if isinstance(val, (list, tuple)):
                    for line in val:
                        self._display.display(f" {' ' * len(host)}  {line}")
                else:
                    self._display.display(f" {' ' * len(host)}  {varname} = {val}")
                return
            # 3) stdout_lines (common for command/shell)
            out_lines = data.get("stdout_lines")
            if out_lines:
                for line in out_lines:
                    self._display.display(f" {' ' * len(host)}  {line}")
                return

        host, task = self._host_task(result)
        if "Gathering Facts" in task:
            self._display.display(f"[{host}] 🛂 {task} ", color=None, newline=False)
            self._display.display(f"(Done)", color=None if self._no_color else "cyan")
            return
        e, c  = self._status("ok")
        self._display.display(f"[{host}] {e} {task} ", color=None, newline=False)
        self._display.display(f"(Success)", color=c)

    def v2_runner_on_changed(self, result, ignore_errors=False):
        host, task = self._host_task(result)
        e, c  = self._status("changed")
        self._display.display(f"[{host}] {e} {task} ", color=None, newline=False)
        self._display.display(f"(Changed)", color=c)

    def v2_runner_on_failed(self, result, ignore_errors=False):
        host, task = self._host_task(result)
        emoji, color = self._status("failed")

        self._display.display(f"[{host}] {emoji} {task} ", color=None, newline=False)
        self._display.display("(Failed)", color=color)

        indent = " " * (len(host) + 3)
        self._print_block("msg",    result._result.get("msg"), indent)
        self._print_block("stderr", result._result.get("stderr"), indent)
        self._print_block("stdout", result._result.get("stdout"), indent)

    def v2_runner_on_skipped(self, result):
        host, task = self._host_task(result)
        e, c  = self._status("skipped")
        self._display.display(f"[{host}] {e} {task} ", color=None, newline=False)
        self._display.display(f"(Skipped)", color=c)

    def v2_runner_on_unreachable(self, result):
        host, task = self._host_task(result)
        emoji, color = self._status("unreachable")
        self._display.display(f"[{host}] {emoji} {task} ", color=None, newline=False)
        self._display.display("(Unreachable)", color=color)
        indent = " " * (len(host) + 3)
        self._print_block("msg", result._result.get("msg"), indent)

    def v2_playbook_on_handler_task_start(self, task):
        role_obj = getattr(task, '_role', None)
        if not role_obj:
            return
        role_name = role_obj.get_name() or getattr(role_obj, "_role_name", None)
        if not role_name or role_name in self._printed_handler_roles:
            return
        header = f"▶️ {role_name} handlers"
        line   = '─' * (len(header) + 2)
        self._display.display("", screen_only=True)
        self._display.display(header, color='yellow' if not self._no_color else None, screen_only=True)
        self._display.display(line, color='yellow' if not self._no_color else None, screen_only=True)
        self._printed_handler_roles.add(role_name)

    # —— Helper methods (added) —— #
    def _status(self, key):
        e, c = self.STATUS_EMOJI.get(key, ("", None))
        if self._no_emoji:
            e = ""
        if self._no_color:
            c = None
        return e, c

    def _host_task(self, result):
        host = result._host.get_name()
        task_obj = getattr(result, "_task", None)
        task = (getattr(result, "task_name", None)
                or (task_obj.get_name() if task_obj else None)
                or "Unnamed task")
        return host, task

    def _print_block(self, label, text, indent, cap=2000):
        if text in (None, ""):
            return
        s = str(text)
        if len(s) > cap:
            s = s[:cap] + "... (truncated)"
        self._display.display(f"{indent}{label}: {s}", color=None)

    # —— Loop‐item callbacks —— #
    def _print_item_details(self, result, host):
        """Helper to print msg, item.key/value, and diff.before→after."""
        indent = " " * (len(host) + 3)  # align under “[host] ”
        res = result._result

        # 1) msg
        msg = res.get("msg")
        if msg:
            self._display.display(f"{indent}{msg}", color=None if self._no_color else "dark gray")

        # 2) item.key = item.value
        item = res.get("item")
        if isinstance(item, dict):
            key = item.get("key")
            val = item.get("value")
            if key and (val is not None and val != ""):
                self._display.display(f"{indent}{key} = {val}", color=None if self._no_color else "dark gray")

        # 3) diff entries
        diffs = res.get("diff")
        if isinstance(diffs, list):
            entries = diffs
        elif isinstance(diffs, dict):
            entries = [diffs]
        else:
            entries = []
        for d in entries:
            if not isinstance(d, dict):
                    continue
            before = d.get("before")
            after  = d.get("after")
            if before and after:
                self._display.display(f"{indent}{before} → {after}", color=None if self._no_color else "dark gray")


    def v2_runner_item_on_ok(self, result):
        host, task = self._host_task(result)
        changed = result._result.get("changed", False)
        key = "changed" if changed else "ok"
        label = "Changed" if changed else "Success"
        emoji, color = self._status(key)

        # Summary line
        self._display.display(f"[{host}] {emoji} {task} ", color=None, newline=False)
        self._display.display(f"({label})", color=color)
        
        # Details
        self._print_item_details(result, host)


    def v2_runner_item_on_failed(self, result):
        host, task = self._host_task(result)
        emoji, color = self._status("failed")
        self._display.display(f"[{host}] {emoji} {task} ", color=None, newline=False)
        self._display.display(f"(Failed)", color=color)
        self._print_item_details(result, host)


    def v2_runner_item_on_skipped(self, result):
        host, task = self._host_task(result)
        emoji, color = self._status("skipped")
        self._display.display(f"[{host}] {emoji} {task} ", color=None, newline=False)
        self._display.display(f"(Skipped)", color=color)
        self._print_item_details(result, host)


    def v2_playbook_on_stats(self, stats):
        self._display.display('', screen_only=True)
        header = 'Summary'
        self._display.display(header, screen_only=True, color=None if self._no_color else 'magenta')
        self._display.display('─' * len(header), screen_only=True, color=None if self._no_color else 'magenta')

        for host in sorted(stats.processed.keys()):
            data = stats.summarize(host)
            self._display.display(hostcolor(host, data), screen_only=True)
            for key in ("ok", "changed", "unreachable", "failed", "skipped"):
                e, color = self._status(key)
                count = data["failures"] if key == "failed" else data.get(key, 0)
                label = self.LABELS[key]
                if count == 0 and not self._no_color:
                  color = "dark gray"

                self._display.display(f"  {e} {count} {label}", color=color, screen_only=True)
            self._display.display("", screen_only=True)

        self._display.display(
            "Setup complete. Thanks for using https://github.com/GertGerber/homelab2",
            color=None if self._no_color else "blue", screen_only=True
        )

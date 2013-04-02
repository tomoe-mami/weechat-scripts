urlselect
========

![screenshot][]

This script will collect URL in a buffer and then present you with a prompt
to select the URL (with Up/Down arrow key) starting from the most recent one.
Once you pressed Enter, the selected URL will be put into the clipboard or
[tmux][] buffer (depends on the active mode). Pressing Ctrl-C will cancel the
URL selection.

Other than copying URL, you can also bind external command to keys `0`-`9` (see
**Options** below). The command will be executed when you press the key during
URL selection.

To make it easier, you might want to bind a key to start URL selection. For
example, to use Alt-Enter you run the following command in your Weechat:

    /key bind meta-ctrl-M /urlselect

This script requires [xclip][] or [tmux][].

[xclip]: http://sourceforge.net/projects/xclip/
[screenshot]: http://i.imgur.com/GkhibXW.png
[tmux]: http://tmux.sourceforge.net/

Options
-------

- **plugins.var.lua.urlselect.selection** (default: **primary**)

  Default selection mode to use. Valid values are **primary**, **secondary**,
  **clipboard** and **tmux**.

- **plugins.var.lua.urlselect.ignore_copied_url** (default: **yes**)

  If set to **yes**, URL that has been copied into the clipboard will be
  ignored the next time you call `/urlselect` again.

- **plugins.var.lua.urlselect.noisy** (default: **no**)

  If set to **yes**, the script will print the URL into the core buffer
  everytime you stored one into the clipboard (ah, you know... for science!)

- **plugins.var.lua.urlselect.ext_cmd_?** (default: none)

  This option can be used to bind an external command to key 0-9 (replace the
  **?** on the option name with the key you want to bind). The selected URL will
  be appended to the command before executing it.

  Key `1` is bound to `xdg-open` by default.

- **plugins.var.lua.urlselect.show_nickname** (default: **no**)

  Show the nickname of user who sent the URL.

- **plugins.var.lua.urlselect.default_color** (default: **gray**)

  Colors for default text.

- **plugins.var.lua.urlselect.mode_color** (default: **yellow**)

  Colors for active mode.

- **plugins.var.lua.urlselect.key_color** (default: **yellow**)

  Colors for shortcut key.

- **plugins.var.lua.urlselect.index_color** (default: **yellow**)

  Colors for URL index.

- **plugins.var.lua.urlselect.url_color** (default: **lightblue**)

  Colors for selected URL.


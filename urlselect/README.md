xclipurl
========

This script will collect URL in a buffer and then present you with a prompt
to select the URL (with Up/Down arrow key). Once you pressed Enter,
the selected URL will be put into the clipboard. Pressing Ctrl-C will cancel
the URL selection.

To be able to see the prompt and the selected URL, you must first add item
`xclipurl` into a bar. You might also want to bind a key for command `/xclipurl`.

Here's a screenshot of it:

![screenshot][]

This script requires [xclip][]

[xclip]: http://sourceforge.net/projects/xclip/
[screenshot]: http://i.imgur.com/LTad6Xn.png

Options
-------

- **plugins.var.lua.xclipurl.selection** (default: **primary**)

  Default selection mode to use. Valid values are **primary**, **secondary**, and
  **clipboard**.

- **plugins.var.lua.xclipurl.ignore_stored_url** (default: **yes**)

  If set to **yes**, URL that has been stored into the clipboard will be
  ignored the next time you call `/xclipurl` again.

- **plugins.var.lua.xclipurl.noisy** (default: **no**)

  If set to **yes**, the script will print the URL into the core buffer
  everytime you stored one into the clipboard (ah, you know... for science!)

- **plugins.var.lua.xclipurl.default_color** (default: **gray**)
- **plugins.var.lua.xclipurl.mode_color** (default: **yellow**)
- **plugins.var.lua.xclipurl.key_color** (default: **yellow**)
- **plugins.var.lua.xclipurl.index_color** (default: **yellow**)
- **plugins.var.lua.xclipurl.url_color** (default: **lightblue**)


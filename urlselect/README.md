urlselect
========

A bar for selecting URLs from current buffer. Requires Weechat 0.4.4 or higher.



### Usage

Simply run `/urlselect` to activate URL selection bar. You can use
Up/Down/Home/End to navigate. Press ? to see the list of key bindings and Tab to
see list of available custom commands (see **Custom Commands** below).



### Custom Commands

You can bind a single digit (0-9) or lowercase alphabet (a-z) to a custom
Weechat command. The syntax to bind a key is:

    /urlselect bind <key> <command>

and to unbind:

    /urlselect unbind <key>

Two custom commands are already set by default (1 and 2). You can unbind these
keys or set it into something else with the above commands.

To see a list of available custom commands, you can press Tab while the URL
selection bar is active. You can also use `/urlselect list-commands` anywhere
else on Weechat.



### Bar & Bar Items

This script will create 1 bar and 8 bar items. The bar is called `urlselect`
and its settings are available under `weechat.bar.urlselect.*`.

The list of bar items are:

- **urlselect_index**: Index of URL count from the newest line (bottom) of
  current buffer.

- **urlselect_nick**: The nickname who mentioned the URL. If no nickname
  available, this will contain an asterisk.

- **urlselect_time**: The time of message containing the URL.

- **urlselect_url**: The actual URL portion of message.

- **urlselect_message**: Message with its original colors (if there's any)
  stripped and the URL portion highlighted.

- **urlselect_title**: Bar title. The one that says, `urlselect: Press ? for help`.

- **urlselect_help**: Help text for showing keys and list of custom commands.

- **urlselect_status**: Status notification. Active when certain activity occur.
  For example, running a custom command.



### Options

##### plugins.var.lua.status_timeout

Timeout (in milliseconds) for displaying status notification (default: `1300`).

##### plugins.var.lua.url_color

Color for URL item (default: `_lightblue`).

##### plugins.var.lua.nick_color

Color for nickname item. Leave this empty to use Weechat's nick color (default
is empty).

##### plugins.var.lua.index_color

Color for URL index (default: `brown`).

##### plugins.var.lua.message_color

Color for message containing the URL (default: `default`).

##### plugins.var.lua.time_color

Color for time of message (default: `default`).

##### plugins.var.lua.title_color

Color for bar title (default: `default`).

##### plugins.var.lua.key_color

Color for keys (default: `cyan`).

##### plugins.var.lua.help_color

Color for help text (default: `default`)

##### plugins.var.lua.status_color

Color for status notification (default: `black,green`)

##### plugins.var.lua.urlselect.cmd.*

These are for custom commands. Use `/urlselect bind` and `/urlselect unbind` to
modify these options.

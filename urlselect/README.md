urlselect
=================================================================================

A bar for selecting URLs from current buffer. Requires Weechat 0.4.4 or higher.

![screenshot](http://i.imgur.com/d5NFVnO.png "urlselect bar at the top of weechat")


### Usage

Simply run `/urlselect` to activate URL selection bar. You can use
Up/Down/Home/End to navigate. Press ? to see the list of key bindings and Tab to
see list of available custom commands (see **Custom Commands** below).



### Custom Commands

You can bind a single key digit (0-9) or lowercase alphabet (a-z) to a custom
Weechat command. When the selection bar is active, you can run these commands
by pressing Alt followed by the key. The syntax to bind a key is:

    /urlselect bind <key> <command>

You can use the following variables inside a command: `${url}`, `${time}`,
`${index}`, `${nick}`, and `${message}`. They will be replaced by their actual
values from the currently selected URL.

For example, to bind Alt-3 to view the raw content of a URL inside Weechat you
can use:

    /urlselect bind 3 /exec -noln -nf url:${url}


To remove a custom command, simply unbind its key:

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

- **urlselect_index**: Index of URL counted from the newest line (bottom) of
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

##### plugins.var.lua.urlselect.status_timeout

Timeout (in milliseconds) for displaying status notification (default: `1300`).

##### plugins.var.lua.urlselect.url_color

Color for URL item (default: `_lightblue`).

##### plugins.var.lua.urlselect.nick_color

Color for nickname item. Leave this empty to use Weechat's nick color (default
is empty).

##### plugins.var.lua.urlselect.index_color

Color for URL index (default: `brown`).

##### plugins.var.lua.urlselect.message_color

Color for message containing the URL (default: `default`).

##### plugins.var.lua.urlselect.time_color

Color for time of message (default: `default`).

##### plugins.var.lua.urlselect.title_color

Color for bar title (default: `default`).

##### plugins.var.lua.urlselect.key_color

Color for keys (default: `cyan`).

##### plugins.var.lua.urlselect.help_color

Color for help text (default: `default`)

##### plugins.var.lua.urlselect.status_color

Color for status notification (default: `black,green`)

##### plugins.var.lua.urlselect.cmd.*

These are for custom commands. Use `/urlselect bind` and `/urlselect unbind` to
modify these options.

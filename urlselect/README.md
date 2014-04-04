urlselect
=================================================================================

A bar for selecting URLs from current buffer. Requires Weechat 0.4.4 or higher.

![screenshot][]

[screenshot]: http://i.imgur.com/gdqyUxn.png

*URL selection bar on top of weechat with the help bar showing list of
available key bindings*


### Usage

Simply run `/urlselect` to activate URL selection bar. You can use
arrow keys to navigate between URLs. Press F1 to see the list of keys and custom
commands (see **Custom Commands** below). It's recommended to bind `/urlselect`
to a key so it can be easily activated. For example, to use Alt+Enter run the
following command in Weechat:

    /key bind meta-ctrl-M /urlselect



### Custom Commands

You can bind a single key digit (0-9) or lowercase alphabet (a-z) to a custom
Weechat command. When the selection bar is active, you can run these commands
by pressing Alt followed by the key. The syntax to bind a key is:

    /urlselect bind <key> <command>

You can use the following variables inside a command: `${url}`, `${time}`,
`${index}`, `${nick}`, `${message}`, `${buffer_name}`, `${buffer_full_name}`,
`${buffer_short_name}`, and `${buffer_number}`. They will be replaced by their
actual values from the currently selected URL.

For example, to bind Alt-v to view the raw content of a URL inside Weechat you
can use:

    /urlselect bind v /exec -noln -nf url:${url}


To remove a custom command, simply unbind its key:

    /urlselect unbind <key>

Two custom commands are already set by default. `o` for xdg-open and `i` for
inserting the URL into input bar. You can unbind these keys or set it into
something else with the above commands.

To see a list of available custom commands, you can press Tab while the URL
selection bar is active. You can also use `/urlselect list-commands` anywhere
else on Weechat.



### Bar & Bar Items

This script will create 2 bars and 10 bar items. The first bar is called
`urlselect`. This bar is used for displaying the info about currently selected
URL. Its settings are available under `weechat.bar.urlselect.*`. The second bar
is for showing the list of keys and custom commands. It is called
`urlselect_help` and its settings are available under
`weechat.bar.urlselect_help.*`. Both bars are hidden by default.

The list of bar items are:

- **urlselect_index**: Index of URL.

- **urlselect_nick**: The nickname who mentioned the URL. If no nickname
  available, this will contain an asterisk.

- **urlselect_time**: The time of message containing the URL.

- **urlselect_url**: The actual URL portion of message.

- **urlselect_message**: Message with its original colors (if there's any)
  stripped and the URL portion highlighted.

- **urlselect_buffer_name**: Name of buffer where the message containing the
  current URL is from. This is probably only useful in merged buffers.

- **urlselect_buffer_number**: Buffer number.

- **urlselect_title**: Bar title. The one that says, `urlselect: <F1> toggle help`.

- **urlselect_help**: Help text for showing keys and list of custom commands.

- **urlselect_status**: Status notification. Visible when certain activity occur.
  For example, running a custom command.



### HSignal

This script can send a hsignal `urlselect_current` when you press Ctrl-S. The
hashtable sent with the signal has the following fields: `url`, `index`, `time`,
`message`, `nick`, `buffer_number`, `buffer_name`, `buffer_full_name`,
and `buffer_short_name`.



### Options

##### plugins.var.lua.urlselect.tags

Comma separated list of tags. If not empty, script will scan URLs only on
messages with any of these tags (default:
`notify_message,notify_private,notify_highlight`).

##### plugins.var.lua.urlselect.scan_merged_buffers

Collect URLs from all buffers that are merged with the current one. Set to `1`
for yes and `0` for no (default: `0`). You can override this setting by calling
`/urlselect activate <mode>`, where `<mode>` is either `current` (scan current
buffer only) or `merged` (scan all buffers merged with the current one).

##### plugins.var.lua.urlselect.status_timeout

Timeout (in milliseconds) for displaying status notification (default: `1300`).

##### plugins.var.lua.urlselect.time_format

Format for displaying time (default: `%H:%M:%S`).

##### plugins.var.lua.urlselect.buffer_name

Format of `urlselect_buffer_name` bar item. Valid values are `full`
(eg: *irc.freenode.#weechat*), `normal` (eg: *freenode.#weechat*), and `short`
(eg: *#weechat*). If it's set to other value, it will fallback to the default
one (`normal`).

##### plugins.var.lua.urlselect.url_color

Color for URL item (default: `_lightblue`).

##### plugins.var.lua.urlselect.nick_color

Color for nickname item. Leave this empty to use Weechat's nick color (default
is empty).

##### plugins.var.lua.urlselect.highlight_color

Nickname color for URL from message with highlight (default is the value of
`weechat.color.chat_highlight` and `weechat.color.chat_highlight_bg`).

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

##### plugins.var.lua.urlselect.buffer_number_color

Color for buffer number (default: `brown`)

##### plugins.var.lua.urlselect.buffer_name_color

Color for buffer name (default: `green`)

##### plugins.var.lua.urlselect.cmd.*

These are for custom commands. Use `/urlselect bind` and `/urlselect unbind` to
modify these options.

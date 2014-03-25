chatbuf_color
==============

Colorize messages in chat buffer.

![screenshot](http://i.imgur.com/ntPZrip.png)

Options
---------

##### plugins.var.lua.chatbuf_color.colors

List of space separated colors. See plugin API documentation for
[`weechat_color`][weechat_color] for color syntax. (default: `1 2 3 4 5 6 7`)

##### plugins.var.lua.chatbuf_color.reshuffle_on_load

Reshuffle the color again to all opened buffers when the script is (re)loaded.
By default it won't assign new color if local variable `color` is already set
for a buffer. Value of `1` will enable this option and `0` will disable it.
(default: `1`)

##### plugins.var.lua.chatbuf_color.custom.*

These are for custom buffer colors. You can use command
`/chatbuf_color set <color> [<buffer> ...]` to set these options.


[weechat_color]:
http://www.weechat.org/files/doc/devel/weechat_plugin_api.en.html#_weechat_color

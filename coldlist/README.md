# Coldlist

A bar item that works similar to Weechat's hotlist but for showing notification
of messages that are hidden behind currently active zoomed buffer.

### Options

##### plugins.var.lua.coldlist.short_name

Whether to use short buffer name (1) or not (0). Default is 0 or the value of
`weechat.look.hotlist_short_names`.

##### plugins.var.lua.coldlist.separator

Separator for list of buffers. Default is `, ` or the value of
`weechat.look.hotlist_buffer_separator`.

##### plugins.var.lua.coldlist.prefix

Text before the list of buffers. Default is `C: `.

##### plugins.var.lua.coldlist.suffix

Text after the list of buffers. Default is empty string.

##### plugins.var.lua.coldlist.count_min_msg

The minimum amount of new messages required to make the message counter appear
on buffer entry. Default is 2 or the value of
`weechat.look.hotlist_count_min_msg`.

##### plugins.var.lua.coldlist.color_default

Default color for bar item. Default is `bar_fg`.

##### plugins.var.lua.coldlist.color_count_highlight

Color for highlight counter. Default is `magenta` or the value of
`weechat.color.status_count_highlight`.

##### plugins.var.lua.coldlist.color_count_msg

Color for normal message counter. Default is `brown` or the value of
`weechat.color.status_count_msg`.

##### plugins.var.lua.coldlist.color_count_private

Color for private message counter. Default is `green` or the value of
`weechat.color.status_count_private`.

##### plugins.var.lua.coldlist.color_count_other

Color for other message counter. Default is `green` or the value of
`weechat.color.status_count_other`.

##### plugins.var.lua.coldlist.color_bufnumber_highlight

Color for buffer number when there's a highlight. Default is `lightmagenta` or
the value of  `weechat.color.status_data_highlight`.

##### plugins.var.lua.coldlist.color_bufnumber_msg

Color for buffer number when there's normal incoming message. Default is
`yellow` or the value of `weechat.color.status_data_msg`.

##### plugins.var.lua.coldlist.color_bufnumber_private

Color for buffer number when there's new private message. Default is `green` or
the value of `weechat.color.status_data_private`.

##### plugins.var.lua.coldlist.color_bufnumber_other

Color for buffer number when there's other kind of messages. Default is
`default` or the value of `weechat.color.status_data_other`.



### Known issues

- Notification is currently only for messages. Joins/parts/quits/etc are not
  listed.
- If a buffer is shown in coldlist and then without unzooming first you switch to
  another buffer that is not merged with the buffer shown in the coldlist, the
  next new message notification for that buffer will appear both in coldlist and
  hotlist.
- The author has bad english so the previous issue (or this whole README) might
  be unclear to a lot of people.

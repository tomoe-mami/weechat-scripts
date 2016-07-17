# bufferlist

Bar for showing list of buffers.

### Options

##### plugins.var.lua.bufferlist.format

Format of buffer entry. The syntax is a bit similar with Weechat bar items
except comma won't add extra space and `+` is used to apply color of item to the
characters around it. Available item names are: `number`, `short_name`, `name`,
`full_name`, `hotlist`, `nick_prefix`, `lag` (see option
**enable_lag_indicator**), `rel`, and `index`. You can also
insert buffer's local variable by prefixing the name with backslash
(eg: `\type` will insert the value of local variable `type`)

##### plugins.var.lua.bufferlist.bar_name

The name of bar that will have automatic scrolling. Because of the limitation
of Weechat bar it should contain only 1 item called `bufferlist`. If there's
other item or there are extra characters in it, the autoscroll will be disabled.

This doesn't mean you can only use this bar for showing `bufferlist`. You can
put the item in any bar you like, they just won't have autoscrolling.

##### plugins.var.lua.bufferlist.relation

Relation mode between buffers. Currently there are only 3 modes: `merged` (for
merged buffers), `same_server` (buffers within the same server), and `none` (no
relation). Related buffers will be placed near each other.

See also option **rel_char_start**, **rel_char_middle**, **rel_char_end**, and
**rel_char_none**.

##### plugins.var.lua.bufferlist.always_show_number

When **relation** mode is set to `merged` (the default), only the first entry of 
merged buffers will have its number shown. Enable this option to show the number
of all entries. If relation mode is set to other value, this option will have no
effect since the number will always be shown.

##### plugins.var.lua.bufferlist.show_hidden_buffers

Show hidden buffers.

##### plugins.var.lua.bufferlist.enable_lag_indicator

If enabled, you can use item `lag` in option **format**.

##### plugins.var.lua.bufferlist.rel_char_(start|middle|end|none)

Characters that will be displayed in item `rel` for indicating the
position of related buffers. For example, if you want to have tree-like display:

    /set plugins.var.lua.bufferlist.rel_char_start  "┌"
    /set plugins.var.lua.bufferlist.rel_char_middle "├─"
    /set plugins.var.lua.bufferlist.rel_char_end    "└─"
    /set plugins.var.lua.bufferlist.rel_char_none   " "
    /set plugins.var.lua.bufferlist.relation        "same_server"


##### plugins.var.lua.bufferlist.prefix_not_joined

Text that will be shown in item `nick_prefix` when a channel buffer is already
opened but you haven't joined the channel (because Weechat is still connecting
to the server or you've been kicked out of the channel or you got disconnected
from a server).


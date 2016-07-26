# bufferlist

A script for displaying list of buffers in a bar.

It has the same purpose as [buffers.pl][] but with better performance (no infolist
call, recreate buffer list only when needed, use flexible format of buffer
entry). And more importantly, it's not written in Perl :)

It also has extra features like [auto-scroll/auto-focus current buffer][demo-scroll],
[mouse actions with multiple buffers][demo-mouse] and easy to switch relation mode
(unlike buffers.pl's server-channel indent, this does not depend on buffer
position).

## Mouse actions

Currently the mouse bindings are hardcoded.

Button                              | Action
------------------------------------|------------------------
Left click                          | Switch buffer
Left button, drag                   | Select buffers
Right button, drag                  | Deselect buffers
Ctrl-Right click                    | Clear selection
Ctrl-Left button, drag within list  | Move buffers
Ctrl-Left button, drag out of list  | Close buffers
Middle click                        | Merge buffers
Ctrl-Middle click                   | Unmerge buffers


## Options

#### bufferlist.look.format

Format of buffer entry. The syntax is a bit similar with Weechat bar items
except comma won't add extra space and `+` is used to apply color of item to the
characters around it. Available item names are: `number`, `short_name`, `name`,
`full_name`, `hotlist`, `prefix`, `lag` (see option
**enable_lag_indicator**), `rel`, and `index` (internal index of buffer in this
script). You can also insert buffer's local variable by prefixing the name with
`%` (eg: `%type` will insert the value of local variable `type`). These local
variables allow you to make more customization to buffer format. For example you
can mark your favorite channels using:

    /eval /buffer set localvar_set_fav ${color:magenta}♥

and then add `%fav` to option **format**.

Another example is marking query buffer using trigger:

    /trigger add new_query signal irc_pv_opened
    /trigger set new_query command /command -buffer ${buffer[${tg_signal_data}].full_name} core buffer set localvar_set_query ${color:yellow}[Q]

You can then add `%query` to option **format**.

#### bufferlist.look.bar_name

The name of bar that will have automatic scrolling. Because of the limitation
of Weechat bar it should contain only 1 item called `bufferlist`. If there's
other item or there are extra characters in it, the autoscroll will be disabled.

This doesn't mean you can only use this bar for showing `bufferlist`. You can
put the item in any bar you like, they just won't have autoscrolling.

#### bufferlist.look.relation

Relation mode between buffers. Currently there are only 3 modes: `merged` (for
merged buffers), `same_server` (buffers within the same server), and `none` (no
relation). Related buffers will be placed near each other.

See also [option **rel_char_start**, **rel_char_middle**, **rel_char_end**, and
**rel_char_none**](#bufferlistlookrel_char_startmiddleendnone).

#### bufferlist.look.always_show_number

By default if there are multiple consecutive buffers with the same number, only
the first one will have its number shown. Enable this option to make the number
always visible.

#### bufferlist.look.show_hidden_buffers

Show hidden buffers.

#### bufferlist.look.enable_lag_indicator

If enabled, you can use item `lag` in option **format**.

#### bufferlist.look.rel_char_(start|middle|end|none)

Characters that will be displayed in item `rel` for indicating the
position of related buffers. `rel_char_none` is for buffers that are not
related.

For example in `same_server` relation mode, if you want to have
similar indenting-style like buffers.pl you can use:

    /set plugins.var.lua.bufferlist.rel_char_middle "  "
    /set plugins.var.lua.bufferlist.rel_char_end    "  "

or if you want to have tree-like display:

    /set plugins.var.lua.bufferlist.rel_char_start  "┌"
    /set plugins.var.lua.bufferlist.rel_char_middle "├─"
    /set plugins.var.lua.bufferlist.rel_char_end    "└─"


#### bufferlist.look.prefix_placeholder

Placeholder text for item `prefix` when a channel buffer is already opened but
you haven't joined the channel because Weechat is still connecting to the
server or you've been kicked out of it or you got disconnected from the server.

#### bufferlist.look.max_name_length

Maximum length of buffer name. Set to `0` for no limit.

#### bufferlist.look.char_more

Character that will be appended when buffer name is truncated.

#### bufferlist.look.align_number

Align numbers and indexes.


#### bufferlist.look.char_selection

Selection marker character. If this option is not empty, buffers won't be
highlighted when you select them. To see the difference between selected and
unselected buffers, add item `sel` into option **format**.

### Color options

All color options used by this script are using [`weechat_color`][color] syntax.
This is to reduce the amount of options created (no unnecessary splitting of
fg/bg options).

[buffers.pl]: https://github.com/weechat/scripts/blob/master/perl/buffers.pl
[color]: https://weechat.org/doc/api#_color
[demo-mouse]: https://streamable.com/7ybq
[demo-scroll]: https://streamable.com/9u3p

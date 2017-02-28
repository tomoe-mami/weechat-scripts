# bufferlist

A script for displaying list of buffers in a bar. Requires Weechat ≥ 1.0.

It has the same purpose as [buffers.pl][] but with better performance (no infolist
call, recreate buffer list only when needed, use flexible format of buffer
entry). And more importantly, it's not written in Perl :)

It also has extra features like [auto-scroll/auto-focus current buffer][demo-scroll],
[mouse actions with multiple buffers][demo-mouse] and easy to switch relation mode
(unlike buffers.pl's server-channel indent, this does not depend on buffer
position).

## Mouse actions

Button                              | Action                     | hsignal
------------------------------------|----------------------------|-------------------------------
Left button                         | Switch buffer              | bufferlist_mouse_switch
Right button                        | Select buffers             | bufferlist_mouse_select
Ctrl-Right button                   | Deselect buffers           | bufferlist_mouse_deselect
Alt-Right button                    | Clear selection            | bufferlist_mouse_deselect_all
Ctrl-Left button, drag within list  | Move buffers               | bufferlist_mouse_move
Ctrl-Left button, drag into chat    | Close buffers              | bufferlist_mouse_close
Middle button                       | Merge buffers              | bufferlist_mouse_merge
Ctrl-Middle button                  | Unmerge buffers            | bufferlist_mouse_unmerge
Ctrl-Wheel up                       | Switch to previous buffer  | bufferlist_mouse_switch_prev
Ctrl-Wheel down                     | Switch to previous buffer  | bufferlist_mouse_switch_next

You can make custom mouse binding using `/key` command. For example, to close a
buffer with Alt-Right button:

    /key bindctxt mouse @item(bufferlist):alt-button2 hsignal:bufferlist_mouse_close

If you want an action performed immediately while you're holding down the button,
use the `*-event-*` key code instead of `*-gesture-*`. For example, here's the
default binding for selection using Right button:

    /key bindctxt mouse @item(bufferlist):button2-event-* hsignal:bufferlist_mouse_select

To run custom commands on selected buffers, you can use the `/bufferlist run`
command. For example, change title of selected buffers:

    /key bindctxt mouse @item(bufferlist):ctrl-alt-button1 /bufferlist run /buffer set title foobar

See [Weechat user guide][wee-mouse] for list of mouse key codes.

## Command

If you don't like using mouse or cursor mode, the script has `/bufferlist`
command that you can use in key bindings or entered manually. It only has 4
functionalities:

- **jump**: Jump/activate a buffer
- **select**: Add buffers into selection
- **deselect**: Remove buffers from selection
- **run**: Evaluate and run Weechat commands on selected buffers.

Other functionalities can be achieved by using a combination of **select** and
**run**. For example hiding multiple buffers:

    /bufferlist select 7-16
    /bufferlist run /buffer hide

**select** and **deselect** accepts eval expression to find matching buffers.
For example select all buffers with message notification count larger than 500
and clear their notification count:

    /bufferlist select if ${hotlist_message} > 500
    /bufferlist run /buffer set hotlist -1

See `/help bufferlist` for more description.

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

#### bufferlist.look.use_hotlist_color_on_name

Use color of highest hotlist activity on buffer name.

#### bufferlist.look.rel_char_(start|middle|end|none)

Characters that will be displayed in item `rel` for indicating the
position of related buffers. `rel_char_none` is for buffers that are not
related.

For example in `same_server` relation mode, if you want to have
similar indenting-style like buffers.pl you can use:

    /set bufferlist.look.rel_char_middle "  "
    /set bufferlist.look.rel_char_end    "  "

or if you want to have tree-like display:

    /set bufferlist.look.rel_char_start  "┌"
    /set bufferlist.look.rel_char_middle "├─"
    /set bufferlist.look.rel_char_end    "└─"


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

#### bufferlist.look.default_mouse_bindings

Set default mouse bindings. Disable this option if you want to set your own mouse
bindings. See [this table](#mouse-actions) for list of hsignal.

### Color options

All color options used by this script are using [`weechat_color`][color] syntax.
This is to reduce the amount of options created (no unnecessary splitting of
fg/bg options).

[buffers.pl]: https://github.com/weechat/scripts/blob/master/perl/buffers.pl
[color]: https://weechat.org/doc/api#_color
[demo-mouse]: https://streamable.com/7ybq
[demo-scroll]: https://streamable.com/9u3p
[wee-mouse]: https://weechat.org/doc/user#mouse_bind_events

weekey
======

*(This script requires WeeChat 1.0 or newer)*

Display recently pressed key combo and the command bound to it on bar items.

The name of the bar items are:

- **weekey_combo**: The key combo
- **weekey_command**: The command for the key combo
- **weekey_context**: Context of the key combo

Here's a how it looks with item weekey_combo and weekey_command added to input
bar:

![demo][]

### Overriding combo name

You can customize the combo name displayed on bar item **weekey_combo** with:

    /set plugins.var.lua.weekey.name.<internal-weechat-key-code> <new-name>

This is useful for when your terminal has key codes that this script doesn't
recognize.

Please note that internal Weechat key code is not the same as the code you get
from `Alt-k` (or `/input grab_key_command`). Internal code starts with `\x01`.
If it's followed by a single `[`, then it's the same as `meta-` key from `Alt-k`
output. If there's another `[` after that, then it's a `meta2-`. If no `[` after
`\x01` then it's a `ctrl-`. Some examples:

Tab (`ctrl-I`):

    /set plugins.var.lua.weekey.name.\x01I Tabulation

Arrow up (`meta2-A`):

    /set plugins.var.lua.weekey.name.\x01[[A ↑

Alt-PageUp in XTerm (`meta2-5;3~`):

    /set plugins.var.lua.weekey.name.\x01[[5;3~ You pressed Alt and PageUp!

F1 in Tmux (`meta-OP`):

    /set plugins.var.lua.weekey.name.\x01[OP Vroom! Vroom!


### Options

##### plugins.var.lua.weekey.duration

Numbers of second the bar items should be displayed after user pressed a key
combo.

##### plugins.var.lua.weekey.mod_separator

Separator between modifiers (`Ctrl`, `Meta`, `Shift`).

##### plugins.var.lua.weekey.key_separator

Character for separating multiple key codes in a combo (for example the default
bind `Alt-j Alt-r`).

##### plugins.var.lua.weekey.local_bindings

Local key bindings are custom key bindings set on specific buffer. For example
the `/script` buffer has Arrow Up key set for moving the highlight up. If this
option is enabled, these local bindings will be shown on `weekey_*` bar items.

##### plugins.var.lua.weekey.color_command

Color for item `weekey_command`.


##### plugins.var.lua.weekey.color_context

Color for item `weekey_context`.

##### plugins.var.lua.weekey.color_key

Color for keys in item `weekey_combo`.

##### plugins.var.lua.weekey.color_separator

Color for key/modifier separator.

##### plugins.var.lua.weekey.color_local_command

Color for command from local bindings.

[demo]: https://i.imgur.com/62hkrVp.gif

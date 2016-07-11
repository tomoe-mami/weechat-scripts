nickcompletewrapper
=====================

Wraps nick completion with custom prefix and/or suffix.

![demo][]

[luautf8][] (or [utf8][]) module is an optional dependency. The script will
fallback to Weechat's string function if the module doesn't exist.

### Settings

This script uses buffer local variable `ncw_prefix` and `ncw_suffix` for setting
custom prefix/suffix. Example:

    /buffer set localvar_set_ncw_prefix ~
    /buffer set localvar_set_ncw_suffix >

These variables only stay as long as the buffer isn't closed. If you want to
keep the values, you can use the `/autosetbuffer` command from script
[buffer_autoset.py][autoset]. For example:

    /autosetbuffer add irc.bitlbee.#twitter_* localvar_set_ncw_prefix @

### TODO

1. Better name

[autoset]: https://github.com/weechat/scripts/blob/master/python/buffer_autoset.py
[demo]: https://i.imgur.com/Dhzj9DP.gif
[utf8]: https://luarocks.org/modules/dannote/utf8
[luautf8]: https://luarocks.org/modules/xavier-wang/luautf8

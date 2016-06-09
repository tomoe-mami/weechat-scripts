nick_complete_wrapper
=====================

Wraps nick completion with custom prefix and/or suffix.

### Settings

This script uses buffer local variable `ncw_prefix` and `ncw_suffix` for setting
custom prefix/suffix. Example:

    /buffer set localvar_set_ncw_prefix ~
    /buffer set localvar_set_ncw_suffix >

These variables only stay as long as the buffer isn't closed. If you want to
keep the values, you can use the `/autosetbuffer` command from script
[buffer_autoset.py][1]. For example:

    /autosetbuffer add irc.bitlbee.#twitter_* localvar_set_ncw_prefix @

### TODO

1. Compatibility with empty_complete.lua
2. Better name

[1]: https://github.com/weechat/scripts/blob/master/python/buffer_autoset.py

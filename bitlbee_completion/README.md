# bitlbee_completion

A script that provides completion for Bitlbee commands. It's similar to
[bitlbee_completion.py][1] except this one actually works.

You need to add `%(bitlbee)` to option `weechat.completion.default_template` to
use the completions provided by this script. For example:

    /set weechat.completion.default_template "%(nicks)|%(irc_channels)|%(bitlbee)"

The script only has 1 option: `plugins.var.lua.bitlbee_completion.buffer` which
is a comma separated list of `server-name:channel-or-query-name`. Wildcard `*`
is allowed. To exclude a channel/query, prepend the entry with `!`. The default
value is `localhost:&bitlbee,localhost:root`. If you're using recent Bitlbee
with multiple control channels support, you can change the option to:

    /set plugins.var.lua.bitlbee_completion.buffer "localhost:&*,localhost:root"

[1]: https://github.com/weechat/scripts/blob/master/python/bitlbee_completion.py

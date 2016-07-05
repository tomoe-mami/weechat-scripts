active_nicks
===============

Show only active users in nicklist.

### Settings

##### plugins.var.lua.active_nicks.delay

Delay (in minutes) since the last message from a user before hiding them again.

##### plugins.var.lua.active_nicks.conditions

Conditions for buffers where this script will be active. Value is evaluated (see
`/help eval`). For example if you want to only watch buffers with more than 20
nicks you can use: `${buffer.nicklist_nicks_count} > 20`

##### plugins.var.lua.active_nicks.tags

Comma separated list of tags. User will be count as active if their message
matched at least one of these tags (logical OR). To combine multiple tags with
logical AND, use `+`. Wildcard `*` is allowed.

For example: `host_foo@*,irc_privmsg+log1`

##### plugins.var.lua.active_nicks.ignore_filtered

Do not count messages that are filtered.

##### plugins.var.lua.active_nicks.groups

Comma separated list of nick groups that will be watched by this script.
Wildcard `*` is allowed, a name beginning with `!` is excluded (always
visible).

To see the available nick groups in a buffer, you can use command:

    /buffer set nicklist_display_groups 1

IRC channel uses the `PREFIX` modes from `005` reply for its nick groups
(`o` for operator, `v` for voiced, `h` for half-operator, etc).  Regular nicks
without prefix are grouped under `...`.

For example if you want all operators to be always visible, set this option to:
`*,!o`

prettype
========

A Weechat script for prettifying text as you type it in input bar by performing
auto-capitalization and replacing standard symbols with their unicode
equivalents. For example, if you type this:

    "uh...i think i've seen dr. manhattan's blue dong in it." --- Internet User

it will be converted to this:

    “Uh… I think I’ve seen Dr. Manhattan’s blue dong in it.” — Internet User

### Dependencies

This script requires **utf8** and **lrexlib-pcre** modules. You can get them
using [luarocks][1]:

```
luarocks install utf8
luarocks install lrexlib-pcre
```

### Escaping Text

If you want to keep portions of text (like, code snippets) to not be modified by
script, you can mark them with escape characters using command `/prettype
escape` (as usual, bind it to a key to make it useful). The command has to be
called twice, one at the beginning of portion of text you want to protect and
another one at the end of it.

URLs will be escaped automatically. If you want to auto-escape nick completion,
you can combine this script with [nick_complete_wrapper.lua][2].

### Original Text

If you decided to not want send the modified text, you can use `/prettype
send-original` to send the original version. Like any other command, you can
bind it to a key. For example, if you want to bind it to Alt-Enter run the
following command:

    /key bind meta-ctrl-M /prettype send-original

There's also `/prettype print-original` to print the original text to current
buffer (not sending it).

### Modifier `prettype_before` and `prettype_after`

You can use modifier `prettype_before` to alter the text in input bar before it
is modified by prettype script and `prettype_after` to alter the text after
prettype modified it. For example using trigger:

```
/trigger add kaomoji modifier prettype_before
/trigger set kaomoji regex /:kiss:/( ˘ ³˘)❤/tg_string /:confused:/(´･_･`)/tg_string
```

### Option

##### plugins.var.lua.prettype.buffers

A comma separated list of buffers where script will be active. Wildcard (`*`) is
allowed. To exclude certain buffers, you can prefix it with `!`. Default is
`irc.*,!irc.server.*,!*.nickserv,!*.chanserv`.

##### plugins.var.lua.prettype.escape_color

Color that will be used to mark escaped text. Default is `magenta`.

##### plugins.var.lua.prettype.ncw_compat

Compatibility with script [nick_complete_wrapper.lua][2]. If enabled, prettype
will set local variable `ncw_prefix` and `ncw_suffix` to the escape character.


[1]: https://luarocks.org
[2]: nick_complete_wrapper

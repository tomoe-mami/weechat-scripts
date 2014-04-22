prettype
========

*This script requires* ***slnunicode*** *and* ***lrexlib-pcre*** *modules*

A Weechat script for prettifying text as you type it in input bar by performing
auto-capitalization and replacing standard symbols with their unicode
equivalents. For example, if you type this:

    "uh...i think i've seen dr. manhattan's blue dong in it." --- Internet User

it will be converted to this:

    “Uh… I think I’ve seen Dr. Manhattan’s blue dong in it.” — Internet User

### Escaping Text

If you want to keep portions of text (like, code snippets) to not be modified by
script, you can mark them with escape characters using command `/prettype
escape` (as usual, bind it to a key to make it useful). The command has to be
called twice, one at the beginning of portion of text you want to protect and
another one at the end of it.

Nick completion that occurs at the start of input and URLs will be escaped
automatically.

### Input Modes

This script provides two modes for inserting characters. The first is `mnemonic`
input mode where you can use character mnemonics as defined in [RFC 1345][] and
the other one is `codepoint` mode where you can use 4 hexadecimal digits to
specify UTF-8 codepoint. To use an input mode, you can run `/prettype`
followed by the mode name in the first argument. For example:

    /prettype mnemonic
    /prettype codepoint

For `mnemonic` mode, only 2 characters will be read by default. To use mnemonics
longer than 2 characters, specify a number in the second argument.
For example:

    /prettype mnemonic 4

You can bind the above commands to shortcut keys for easier access. For example:

    /key bind meta-U /prettype codepoint
    /key bind meta-M /prettype mnemonic

The above commands will bind Alt-Shift-U for codepoint input and Alt-Shift-M for
mnemonic input.

To know which mode currently active, you can use bar item `prettype_mode`.

### Original Text

If you decided to not want send the modified text, you can use `/prettype
send-original` to send the original version. Like any other command, you can
bind it to a key. For example, if you want to bind it to Alt-Enter run the
following command:

    /key bind meta-ctrl-M /prettype send-original

There's also `/prettype print-original` to print the original text to current
buffer (not sending it).

### Option

##### plugins.var.lua.prettype.buffers

A comma separated list of buffers where script will be active. Wildcard (`*`) is
allowed. To exclude certain buffers, you can prefix it with `!`. Default is
`irc.*,!irc.server.*,!*.nickserv,!*.chanserv`.

##### plugins.var.lua.prettype.mode_color

The color for `prettype_mode` bar item. Default is `lightgreen`.

##### plugins.var.lua.prettype.escape_color

Color that will be used to mark escaped text. Default is `magenta`.

[rfc 1345]: http://tools.ietf.org/html/rfc1345


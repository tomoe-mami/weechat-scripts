prettype
========

*This script requires* ***slnunicode*** *and* ***lrexlib-pcre*** *modules*

A Weechat script for prettifying text as you type it in input bar by performing
auto-capitalization and replacing standard symbols with their unicode
equivalents.

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

### Sending Raw Text

If you decided to not want send the modified text, you can use `/prettype
send-original` to send the unmodified version. Like any other command, you can
bind it to a key. For example, if you want to bind it to Alt-Enter run the
following command:

    /key bind meta-ctrl-M /prettype send-original

### Option

There's only 1 option, `plugins.var.lua.prettype.mode_color`. It's used as the
color of bar item `prettype_mode`.

[rfc 1345]: http://tools.ietf.org/html/rfc1345


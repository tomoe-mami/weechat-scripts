TypeAss
=======

A Lua script for Weechat to convert "regular quotes" into “ldquo and rdquo pairs”,
capitalize first letter of sentences, and other unnecessary replacements.

You can enclose part of text with backticks (`\`like this\``) to keep it
unmodified.

This script only has 1 config `plugins.var.lua.typeass.buffers` which is
a comma separated list of buffer name. `*` means all buffers (which is the
default). You can exclude certain buffers by prefixing it with `!`.

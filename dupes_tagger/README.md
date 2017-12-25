# dupes\_tagger

Add `duplicate` tag to incoming lines if its message has already exist in the buffer.
You can then make a filter that use this tag to hide duplicate messages. For example:

    /filter add duplicate_lines * duplicate *

### Options

#### plugins.var.lua.dupes\_tagger.condition

Only check for lines that matched this condition. Content is evaluated (see `/help eval`).

Pointers that you can use: [`${buffer}`][h_buffer], [`${line}`][h_line], [`${line_data}`][h_line_data].

Extra variables: `${tags}` (comma separated list of tags) and `${message}` content of the incoming message
with colors removed and spaces trimmed.

Default is `${tags} =~ ,log1,`.

#### plugins.var.lua.dupes\_tagger.search\_limit

Give up search after reaching this amount of lines but found no duplicates. Useful if you have ridiculously
huge limit in `weechat.history.max_buffer_lines_*` options. Default is 1000.

[h_buffer]: https://weechat.org/doc/api#hdata_buffer
[h_line]: https://weechat.org/doc/api#hdata_line
[h_line_data]: https://weechat.org/doc/api#hdata_line_data

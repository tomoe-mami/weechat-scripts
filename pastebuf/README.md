# pastebuf

View the content of pastebin inside buffer.

Supported sites:

- bpaste.net
- dpaste.de
- gist.github.com
- paste.debian.net
- pastebin.ca
- pastebin.com
- pastie.org
- sprunge.us

### Usage

    /pastebuf <url-of-the-paste> [<optional-syntax-language>]

If the optional syntax language parameter is specified, the text will be
highlighted using external command specified in
`plugins.var.lua.pastebuf.syntax_highlighter` (see **Options** below).


### Options

##### plugins.var.lua.pastebuf.fetch_timeout

Timeout for fetching the paste URL in milliseconds (default: 5000)

##### plugins.var.lua.pastebuf.highlighter_timeout

Timeout for running syntax highlighter in milliseconds (default: 3000)

##### plugins.var.lua.pastebuf.color_line_number

Color for line numbers. See documentation for `weechat_color`][color info] for
valid values. (default: `default,darkgray`)

##### plugins.var.lua.pastebuf.color_line

Color for line content. See documentation for `weechat_color`][color info] for
valid values. (default: `default,default`)

##### plugins.var.lua.pastebuf.syntax_highlighter

External program that will be called to apply syntax highlighting. If the value
contains `$lang`, it will be replaced by the name of syntax language specified
with `/pastebuf` command. Set to empty string to disable syntax highlighting.
(default: `pygmentize -l $lang`)

[color info]:
http://weechat.org/files/doc/devel/weechat_plugin_api.en.html#_weechat_color


### Known Issues

- Script doesn't know how to detect the syntax language of a paste
- Script doesn't know how to get syntax language info selected in the original
  paste.
- If a gist contain multiple files, only the first file will be fetch.

### Nice to have

- Save the paste to a file
- Search inside the content of a paste
- Change the syntax of an already opened paste without issuing `/pastebuf`
  command again

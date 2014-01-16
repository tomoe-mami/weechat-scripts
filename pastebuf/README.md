# pastebuf

View the content of pastebin inside buffer. Requires Weechat 0.4.3 or higher.


Supported sites:

- bpaste.net
- dpaste.de
- gist.github.com
- paste.debian.net
- pastebin.ca
- pastebin.com
- pastie.org
- sprunge.us

For gist with multiple files, only the first file in a gist will be fetch. To
enable fetching multiple files, you have to install [lua-cjson][] module.

[lua-cjson]: https://github.com/mpx/lua-cjson

### Usage

    /pastebuf <url-of-the-paste> [<optional-syntax-language>]

If the optional syntax language parameter is specified, the text will be
highlighted using external command specified in
`plugins.var.lua.pastebuf.syntax_highlighter` (see [**Options**](#options)).


### Command inside paste buffer

    lang <new-syntax-language>

Change the syntax language of current buffer.

    save <filename>

Save the content of current buffer to a file.


### Options

##### plugins.var.lua.pastebuf.fetch_timeout

Timeout for fetching the paste URL in milliseconds (default: `12000`)

##### plugins.var.lua.pastebuf.highlighter_timeout

Timeout for running syntax highlighter in milliseconds (default: `3000`)

##### plugins.var.lua.pastebuf.show_line_number

Set to `1` to enable line number and `0` to disable it. (default: 1)

##### plugins.var.lua.pastebuf.indent_width

Numbers of spaces used for indentation. All tab characters at the start of line
will be replaced by these spaces. (default: `4`)

##### plugins.var.lua.pastebuf.color_line_number

Color for line numbers. See documentation for [`weechat_color`][color info] for
valid values. (default: `default,darkgray`)

##### plugins.var.lua.pastebuf.color_line

Color for line content. See documentation for [`weechat_color`][color info] for
valid values. (default: `default,default`)

##### plugins.var.lua.pastebuf.syntax_highlighter

External program that will be called to apply syntax highlighting. If the value
contains `$lang`, it will be replaced by the name of syntax language specified
with `/pastebuf` command. Set to empty string to disable syntax highlighting.
(default: none)


[color info]:
http://weechat.org/files/doc/devel/weechat_plugin_api.en.html#_weechat_color


### Known Issues

- Script doesn't know how to detect the syntax language of a paste
- Script doesn't know how to get syntax language info selected in the original
  paste.
- If a gist contain multiple files, only the first file will be fetch.

### Nice to have

- Search inside the content of a paste

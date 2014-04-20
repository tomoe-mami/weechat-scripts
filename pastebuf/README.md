# pastebuf

View the content of pastebin inside buffer. Requires Weechat 0.4.3 or higher.

Supported sites:

- bpaste.net
- codepad.org
- dpaste.com
- dpaste.de
- fpaste.org
- gist.github.com
- ideone.com
- paste.debian.net
- pastebin.ca
- pastebin.com
- pastebin.osuosl.org
- pastie.org
- sprunge.us
- vpaste.net
- paste.is

For gist with multiple files, only the first file in a gist will be fetch. To
enable fetching multiple files, you have to install [lua-cjson][] module.

[lua-cjson]: https://github.com/mpx/lua-cjson

### Usage

    /pastebuf <url-of-the-paste> [<optional-syntax-language>]

If the optional syntax language parameter is specified, the text will be
highlighted using external command specified in
`plugins.var.lua.pastebuf.syntax_highlighter` (see [**Options**](#options)).

##### Note about sprunge.us and vpaste.net

These services specify the language in the query part of their URL (eg:
`http://sprunge.us/iFWA?lua`, `http://vpaste.net/TNSz8?ft=cpp`). If the third
argument of `/pastebuf` is not specified, script will try to use this query info
to detect the language of a paste.

##### Note about gist.github.com and Sticky Notes

Gist and sites using Sticky Notes (fpaste.org, pastebin.osuosl.org) provide an
API to get information about a paste. If **lua-cjson** module is installed,
script will try to use the API to detect the language of a paste automatically
or open all files inside a gist with multiple files.

##### Note about language autodetection

The name of the language provided by paste services might be not supported by the
syntax highlighter you use. When this happened, nothing will be shown in the
paste buffer and there will be an error message in Weechat's core buffer. You
can still view the content of the paste by entering `lang none` (or the correct
name of language supported by your syntax highlighter) inside the paste buffer.

### Scan URLs

You can can tell script to scan the current buffer for any URL from supported
paste services and open them immediately. To do that just call:

    /pastebuf **open-recent-url [<optional-number-of-urls>]

If `optional-number-of-urls` isn't specified this will scan only 1 recent URL.
If you tell it to scan more than 1 URL, the order of pastes opened might be not
the same as the order of recent URLs appear inside current buffer.

### Command inside paste buffer

    lang <new-syntax-language>

Change the syntax language of current buffer. Use `none` to disable syntax
highlighting.

    save <filename>

Save the content of current buffer to a file.


### Options

##### plugins.var.lua.pastebuf.fetch_timeout

Timeout for fetching the paste URL in milliseconds (default: `30000`)

##### plugins.var.lua.pastebuf.highlighter_timeout

Timeout for running syntax highlighter in milliseconds (default: `3000`)

##### plugins.var.lua.pastebuf.show_line_number

Set to `1` to enable line number and `0` to disable it. (default: `1`)

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



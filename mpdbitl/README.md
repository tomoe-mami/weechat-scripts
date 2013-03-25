mpdbitl
=================================================================================

A Lua script for [Weechat][] that automatically change [Bitlbee][] status
message into currently playing [MPD][] track. Requires [luasocket][] module.

Usage
---------------------------------------------------------------------------------

Put it in `${WEECHAT_HOME}/lua` and load it like any other Lua script:

	/lua load lua/mpdbitl.lua

Commands
---------------------------------------------------------------------------------

You can use `/mpdbitl toggle` to toggle the status update and `/mpdbitl change`
to change the status immediately.

Status Format
---------------------------------------------------------------------------------

This script provides four different status options, each for different
state of MPD server:

- `mpdbitl.bitlbee.format_playing` is used when MPD is playing a song

- `mpdbitl.bitlbee.format_paused` is used when MPD is paused

- `mpdbitl.bitlbee.format_stopped` is used when MPD is stopped and current song
  is not empty.

- `mpdbitl.bitlbee.format_none` is used when MPD is stopped and current song is
  empty.

The current song info will be empty if there's nothing on current playlist
or MPD has reached the end of the playlist.

You can use the following patterns in all of the above status options except
`mpdbitl.bitlbee.format_none`:

- `{{artist}}`
- `{{album}}`
- `{{track}}`
- `{{time}}`
- `{{last_modified}}`
- `{{date}}`
- `{{genre}}`
- `{{disc}}`
- `{{composer}}`
- `{{file}}` (file path relative to MPD's music\_directory)
- `{{pos}}` (song position in current playlist)
- `{{id}}` (MPD song ID)


[Weechat]: http://www.weechat.org/
[Bitlbee]: http://bitlbee.org
[MPD]: http://mpd.wikia.com
[luasocket]: http://luaforge.net/projects/luasocket/

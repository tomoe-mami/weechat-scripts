mpdbitl.lua
=================================================================================

A Lua script for [Weechat][] that automatically change [Bitlbee][] status
message into currently playing [MPD][] track. Requires [luasocket][] module.

Usage
---------------------------------------------------------------------------------

Put it in `${WEECHAT_HOME}/lua` and load it like any other Lua script:

	/lua load lua/mpdbitl.lua

Commands
---------------------------------------------------------------------------------

There's only one command at the moment (`/mpdbitl`) for changing the status
immediately.



[Weechat]: http://www.weechat.org/
[Bitlbee]: http://bitlbee.org
[MPD]: http://mpd.wikia.com
[luasocket]: http://luaforge.net/projects/luasocket/

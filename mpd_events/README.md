# mpd_events

*(Requires Weechat ≥ 1.5, MPD ≥ 0.14, and [LuaSocket][])*

A script that sends hsignal on any MPD event like song changed, playback paused,
song added to current playlist, etc.

The script is pretty much useless on its own but you can combine it with
trigger (or another script) to do some stuffs. For example, setting your
away message to the currently playing song:

    /trigger add mpd hsignal mpd_events
    /trigger set mpd conditions ${events} =~ ,song_changed,
    /trigger set mpd command /away -all Listening to ${song.artist} - ${song.title}


[luasocket]: https://luarocks.org/modules/luarocks/luasocket

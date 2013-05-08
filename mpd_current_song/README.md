# mpd_current_song

A bar item for showing currently playing song on MPD.

Requires: mpc (and mpd of course)

## Connection Setting

If MPD server is not located in localhost or read access to it is protected by
password, you must set `MPD_HOST` environment variable to
*"password@host-of-mpd"* (or just *"host-of-mpd"* if it's not password
protected) before running Weechat. Alternately, you can create a shell script
that wraps mpc and declare the variable there then sets
`plugins.var.lua.mpd_current_song.client` to the location of that shell script.

For example, this is the shell script:

```sh
#!/bin/sh
MPD_HOST="3xXtrE|\/|eP4Zz\/\/O|2D@localhost" mpc "$@"
```

You save it as `~/bin/mpc-pass.sh`. Then in Weechat do:

```
/set plugins.var.lua.mpd_current_song.client "~/bin/mpc-pass.sh"
```

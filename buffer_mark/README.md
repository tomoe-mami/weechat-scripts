# ATTENTION, RANDOM INTERNET USERS!

THIS SCRIPT SUCKS AND YOU SHOULD NOT USE IT!

***

# buffer_mark

![screenshot](http://i.imgur.com/9mP7fjH.png)

See those colorful stripes on the right of channel/buffer names? That's what this
script does.

A couple notes before you install this script:

- This script prepend the marker *into* message prefix, which means it will be
  saved into your log file.

- If your message prefix is right aligned, this script will pad the prefix with
  useless spaces just to make the marker aligned correctly. And that means your
  log file will contain more junks!

- The god damn marker doesn't go away when you zoom in one of the merged
  buffers.

- If you haven't guessed already, the marker will be shown even if the buffer
  isn't merged with anything.

- slnunicode module is optional, but good luck trying to have a well aligned
  prefix without it. If you don't want to install slnunicode, sets your prefix
  alignment to anything other than `right` or don't use any multibyte characters
  in `plugins.var.lua.buffer_mark.string`.

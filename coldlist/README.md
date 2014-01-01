# Coldlist

A bar item that works similar to Weechat's hotlist but for showing notification
of messages that are hidden behind currently active zoomed buffer.

### Options

This script uses 3 options from hotlist

- weechat.look.hotlist_short_names
- weechat.look.hotlist_buffer_separator
- weechat.look.hotlist_count_min_msg

### Known issues

- Notification is currently only for messages. Joins/parts/quits/etc are not
  listed.
- If a buffer is shown in coldlist and then without unzooming first you switch to
  another buffer that is not merged with the buffer shown in the coldlist, the
  next new message notification for that buffer will appear both in coldlist and
  hotlist.
- The author has bad english so the previous issue (or this whole README) might
  be unclear to a lot of people.

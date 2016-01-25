# colorize_short_name

Apply colors from `weechat.color.chat_nick_colors` to buffers' short_name
property. Probably only useful for merged buffers.

![screenshot](https://i.imgur.com/03ilWyF.png)

This is basically an abuse of nick colors.

Make sure option `weechat.look.color_inactive_prefix_buffer` is set to `off`.

If you're using buffers.pl and option `buffers.look.short_names` is
enabled (the default), the colors applied by this script will override
colors from buffers.pl. This is not a bug :)

# infolist_var.lua

Info hook for infolist's variable. It's created because no one in #weechat would
tell me how to get buffer name in `buffer_opened` signal trigger when all the
available data is just a buffer pointer.

The syntax for this info in eval is as follows:

    ${info:list,<infolist-name>;[<pointer>];[<argument>];[<index>];[<variable>]}

See documentation for [`weechat_infolist_get`][1] for explanation of infolist
name, pointer, and argument. Index is the position of infolist cursor starting
from 0 (first item). Use negative index to move backwards (-1 means last item,
-2 is second to last, etc). Variable is the name of variable in current infolist
item. If you leave it blank, all available variables will be returned.

You can use `buf` info as a shorthand for `${info:list,buffer;<pointer>;;0;<variable>}`.

## Examples

###### Get the full name of the first buffer (core buffer)

    /eval -n ${info:list,buffer;;;;full_name}

###### Using `buf` info inside trigger

    /trigger set new_buffer condition ${info:buf,${tg_signal_data};full_name} == exec.exec.highlights

For trigger's command the semicolon should be escaped because it is used by
trigger as command separator. For example:

    /trigger set new_buffer command /wait 100ms /command -buffer ${info:buf,${tg_signal_data}\;full_name} core buffer set time_for_each_line 1




[1]: https://weechat.org/files/doc/devel/weechat_plugin_api.en.html#_weechat_infolist_get

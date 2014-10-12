local w = weechat

function scroll_cb(param)
   local buffer, amount = param:match("^([^:]+):(.+)$")
   if buffer and amount then
      w.command(buffer, "/window scroll -" .. amount)
   end
   return w.WEECHAT_RC_OK
end

function stop_search_cb(_, buffer)
   local win_ptr = w.current_window()
   local lines_after = w.window_get_integer(win_ptr, "lines_after")
   local height = w.window_get_integer(win_ptr, "win_chat_height")
   if lines_after > 0 then
      local amount = lines_after + height - 1
      w.hook_timer(200, 0, 1, "scroll_cb", buffer .. ":" .. amount)
   end
   return w.WEECHAT_RC_OK
end

assert(
   w.register(
      "keep_search_position",
      "tomoe-mami <https://github.com/tomoe-mami>",
      "0.1",
      "WTFPL",
      "Keep search position",
      "", ""),
   "Unable to register script. Perhaps it has been loaded before?")


w.hook_command_run("/input search_stop", "stop_search_cb", "")

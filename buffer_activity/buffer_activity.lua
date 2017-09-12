w, script_name = weechat, "buffer_activity"
g = {
   buffers = {}
}

function main()
   local reg_ok = w.register(
      script_name,
      "singalaut",
      "0.1",
      "WTFPL",
      "Count recent activities in a buffer",
      "", "")

   if reg_ok then
      init_config()
      w.hook_signal("buffer_line_added", "line_added_cb", "")
      w.hook_signal("buffer_closed", "closed_cb", "")
   end
end

function init_config()
   local value = "log1"
   if w.config_is_set_plugin("tags") == 1 then
      value = w.config_get_plugin("tags")
   else
      w.config_set_plugin("tags", value)
      w.config_set_desc_plugin("tags", [[
Comma separated list of tags. A line will be count as activity if it contains any of these tags.
Wildcard (*) is allowed. Prefix a tag with exclamation mark (!) to exclude it.]])
   end
   config_cb(nil, "tags", value)

   value = 300
   if w.config_is_set_plugin("delay") == 1 then
      value = w.config_get_plugin("delay")
   else
      local ptr_opt = w.config_get("irc.look.smart_filter_delay")
      if ptr_opt ~= "" then
         value = w.config_integer(ptr_opt) * 60
      end
      w.config_set_plugin("delay", value)
      w.config_set_desc_plugin("delay", "Delay (in second) between message before resetting activity counter")
   end
   config_cb(nil, "delay", value)

   w.hook_config("plugins.var.lua."..script_name..".*", "config_cb", "")
end

function config_cb(_, name, value)
   name = name:gsub("^plugins%.var%.lua%."..script_name.."%.", "")
   if name == "delay" then
      hook_timer()
   elseif name == "tags" then
      local tags = { _all = false }
      for tag in value:gmatch("([^,]+)") do
         local neg = false
         if tag:sub(1, 1) == "!" then
            neg, tag = true, tag:sub(2)
         elseif tag == "*" then
            tags._all = true
         end
         tags[#tags+1] = { tag, neg }
      end
      table.sort(tags, function (a, b)
         return a[1] < b[1]
      end)
      g.tags = tags
   end
   return w.WEECHAT_RC_OK
end

function hook_timer()
   local delay = tonumber(w.config_get_plugin("delay")) or 0
   if g.timer then
      w.unhook(g.timer)
   end
   if delay < 1 then
      g.timer = nil
   else
      local interval = 1000
      if delay >= 60 then
         interval = interval * math.floor(delay / (math.log10(delay) * 4))
      end
      g.timer = w.hook_timer(interval, 0, 0, "timer_cb", "")
      if g.tags then
         count_past_activities()
      end
   end
end

function count_past_activities()
   local buffers = g.buffers
   local delay = tonumber(w.config_get_plugin("delay")) or 0
   local min_time = os.time() - delay
   for ptr_buffer in iter_buffers() do
      local count = 0
      for ptr_data, h_line_data in iter_lines(ptr_buffer, true) do
         local time = w.hdata_time(h_line_data, ptr_data, "date")
         if time < min_time then
            break
         end
         if match_tags(ptr_data, h_line_data) then
            if not buffers[ptr_buffer] then
               buffers[ptr_buffer] = {}
            end
            count = count + 1
            buffers[ptr_buffer][count] = time
         end
      end
      if count == 0 then
         set_localvar(ptr_buffer)
         send_signal(ptr_buffer, false)
      else
         table.sort(buffers[ptr_buffer])
         set_localvar(ptr_buffer, count, buffers[ptr_buffer][count])
         send_signal(ptr_buffer, true)
      end
   end
end

function iter_lines(ptr_buffer, reverse)
   local h_line, h_line_data = w.hdata_get("line"), w.hdata_get("line_data")
   local ptr_lines = w.hdata_pointer(w.hdata_get("buffer"), ptr_buffer, "own_lines")
   local ptr_line = w.hdata_pointer(w.hdata_get("lines"), ptr_lines, reverse and "last_line" or "first_line")
   return function ()
      if ptr_line and ptr_line ~= "" then
         local ptr_data = w.hdata_pointer(h_line, ptr_line, "data")
         ptr_line = w.hdata_pointer(h_line, ptr_line, reverse and "prev_line" or "next_line")
         return ptr_data, h_line_data
      end
   end
end

function iter_buffers()
   local h_buffer = w.hdata_get("buffer")
   local ptr_buffer = w.hdata_get_list(h_buffer, "gui_buffers")
   return function ()
      if ptr_buffer and ptr_buffer ~= "" then
         local ret_buffer = ptr_buffer
         ptr_buffer = w.hdata_pointer(h_buffer, ret_buffer, "next_buffer")
         return ret_buffer, h_buffer
      end
   end
end

function timer_cb()
   local buffers= g.buffers
   local delay = tonumber(w.config_get_plugin("delay")) or 0
   local min_time = os.time() - delay
   for ptr_buffer, times in pairs(buffers) do
      local t, count = {}, 0
      for k, v in ipairs(times) do
         if v >= min_time then
            count = count + 1
            t[count] = v
         end
      end
      buffers[ptr_buffer] = t
      set_localvar(ptr_buffer, count)
      if count == 0 then
         send_signal(ptr_buffer, false)
      end
   end
   return w.WEECHAT_RC_OK
end

function line_added_cb(_, _, ptr_line)
   local tags, buffers, h_line_data = g.tags, g.buffers, w.hdata_get("line_data")
   local ptr_data = w.hdata_pointer(w.hdata_get("line"), ptr_line, "data")
   if match_tags(ptr_data, h_line_data) then
      local ptr_buffer = w.hdata_pointer(h_line_data, ptr_data, "buffer")
      if not buffers[ptr_buffer] then
         buffers[ptr_buffer] = {}
      end
      local count = #buffers[ptr_buffer]
      local time = w.hdata_time(h_line_data, ptr_data, "date")
      count = count + 1
      buffers[ptr_buffer][count] = time
      set_localvar(ptr_buffer, count, time)
      if count == 1 then
         send_signal(ptr_buffer, true)
      end
   end
   return w.WEECHAT_RC_OK
end

function send_signal(ptr_buffer, start)
   w.hook_signal_send(script_name..(start and "_start" or "_end"), w.WEECHAT_HOOK_SIGNAL_POINTER, ptr_buffer)
end

function closed_cb(_, _, ptr_buffer)
   if g.buffers[ptr_buffer] then
      g.buffers[ptr_buffer] = nil
   end
   return w.WEECHAT_RC_OK
end

function set_localvar(ptr_buffer, count, time)
   if not count or count == 0 then
      w.buffer_set(ptr_buffer, "localvar_del_"..script_name.."_count", "")
   else
      w.buffer_set(ptr_buffer, "localvar_set_"..script_name.."_count", count)
   end
   if time then
      w.buffer_set(ptr_buffer, "localvar_set_"..script_name.."_time", time)
   end
end

function match_tags(ptr_data, h_line_data)
   local patterns, result = g.tags, false
   local tags_count = w.hdata_integer(h_line_data, ptr_data, "tags_count")
   if tags_count == 0 then
      return patterns._all
   end
   for i = 0, tags_count do
      local tag = w.hdata_string(h_line_data, ptr_data, i.."|tags_array")
      for _, pattern in ipairs(patterns) do
         if w.string_match(tag, pattern[1], 0) == 1 then
            if pattern[2] then
               return false
            else
               result = true
            end
         end
      end
   end
   return result
end

main()

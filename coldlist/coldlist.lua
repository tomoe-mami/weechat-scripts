g = {
   script = {
      name = "coldlist",
      author = "rumia <https://github.com/rumia>",
      version = "0.1",
      license = "WTFPL",
      description = "Like hotlist, but cold"
   },
   config = {
      short_name = true,
      separator = ", ",
      count_min_msg = 2
   },
   buffers = {
      -- i hate lua table
      list = {},
      positions = {},
      numbers = {}
   }
}

function load_config()
   local opt = weechat.config_get("weechat.look.hotlist_short_names")
   if opt ~= "" then
      g.config.short_name = (weechat.config_boolean(opt) == 1)
   end
   local opt = weechat.config_get("weechat.look.hotlist_buffer_separator")
   if opt ~= "" then
      g.config.separator = weechat.config_string(opt)
   end
   local opt = weechat.config_get("weechat.look.hotlist_count_min_msg")
   if opt ~= "" then
      g.config.count_min_msg = weechat.config_integer(opt)
   end
end

function print_cb(_, buffer, date, ntags, displayed, highlight, prefix, message)
   local active = weechat.buffer_get_integer(buffer, "active")
   local buffer_num = weechat.buffer_get_integer(buffer, "number")

   local win = weechat.current_window()
   local win_buffer = weechat.window_get_pointer(win, "buffer")
   local win_buffer_active = weechat.buffer_get_integer(win_buffer, "active")
   local win_buffer_num = weechat.buffer_get_integer(win_buffer, "number")

   if active == 0 and win_buffer_num == buffer_num and win_buffer_active == 2 then
      if not g.buffers.positions[buffer] then
         local pos = #g.buffers.list + 1
         g.buffers.list[pos] = {
             pointer = buffer,
             count = 1
          }

         g.buffers.positions[buffer] = pos
         if not g.buffers.numbers[buffer_num] then
            g.buffers.numbers[buffer_num] = {}
         end
         table.insert(g.buffers.numbers[buffer_num], buffer)
      else
         local pos = g.buffers.positions[buffer]
         g.buffers.list[pos].count = g.buffers.list[pos].count + 1
      end
      weechat.bar_item_update(g.script.name)
   end
   return weechat.WEECHAT_RC_OK
end

function bar_item_cb()
   local list = {}
   for _, buf in ipairs(g.buffers.list) do
      local name, key
      if g.config.short_name then
         key = "short_name"
      else
         key = "name"
      end
      name = weechat.buffer_get_string(buf.pointer, key)
      local number = weechat.buffer_get_integer(buf.pointer, "number")
      local entry = string.format("%d:%s", number, name)
      if g.config.count_min_msg > 0 and buf.count >= g.config.count_min_msg then
         entry = entry .. string.format(" (%d)", buf.count)
      end
      table.insert(list, entry)
   end
   return table.concat(list, g.config.separator)
end

function update_positions(start_pos)
   local end_pos = #g.buffers.list
   if not start_pos then
      start_pos = 1
   end

   for i = start_pos, end_pos do
      if g.buffers.list[i] then
         local pointer = g.buffers.list[i].pointer
         g.buffers.positions[pointer] = i
      end
   end
end

function buffer_unzoom_cb(_, signal, buffer)
   local buffer_num = weechat.buffer_get_integer(buffer, "number")
   if g.buffers.numbers[buffer_num] then
      for _, pointer in ipairs(g.buffers.numbers[buffer_num]) do
         local pos = g.buffers.positions[pointer]
         g.buffers.positions[pointer] = nil
         table.remove(g.buffers.list, pos)
      end
      g.buffers.numbers[buffer_num] = nil
      update_positions()
      weechat.bar_item_update(g.script.name)
   end
   return weechat.WEECHAT_RC_OK
end

function buffer_switch_cb(_, signal, buffer)
   if g.buffers.positions[buffer] then
      local pos = g.buffers.positions[buffer]
      local pointer = g.buffers.list[pos].pointer
      local num = weechat.buffer_get_integer(pointer, "number")

      table.remove(g.buffers.list, pos)
      g.buffers.positions[buffer] = nil

      if g.buffers.numbers[num] then
         local copy = {}
         for _, v in pairs(g.buffers.numbers[num]) do
            if v ~= buffer then
               table.insert(copy, buffer)
            end
         end
         if #copy > 0 then
            g.buffers.numbers[num] = copy
         else
            g.buffers.numbers[num] = nil
         end
      end
      update_positions(pos)
      weechat.bar_item_update(g.script.name)
   end
   return weechat.WEECHAT_RC_OK
end

function config_cb(_, name, value)
   weechat.print("", name .. ":" .. value .. " (" .. type(value) .. ")")
   if name == "weechat.look.hotlist_short_names" then
      g.config.short_name = (value == "on")
   elseif name == "weechat.look.hotlist_buffer_separator" then
      g.config.separator = value
   elseif name == "weechat.look.hotlist_count_min_msg" then
      g.config.count_min_msg = tonumber(value)
   end
   return weechat.WEECHAT_RC_OK
end

function setup()
   weechat.register(
      g.script.name,
      g.script.author,
      g.script.version,
      g.script.license,
      g.script.description,
      "", "")

   load_config()

   weechat.bar_item_new(g.script.name, "bar_item_cb", "")
   weechat.hook_signal("buffer_unzoomed", "buffer_unzoom_cb", "")
   weechat.hook_signal("buffer_switch", "buffer_switch_cb", "")
   weechat.hook_config("weechat.look.hotlist*", "config_cb", "")
   weechat.hook_print("", "irc_privmsg", "", 0, "print_cb", "")
end

setup()

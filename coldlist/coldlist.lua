g = {
   script = {
      name = "coldlist",
      author = "rumia <https://github.com/rumia>",
      version = "0.1",
      license = "WTFPL",
      description = "Like hotlist, but cold"
   },
   config = {},
   defaults = {
      boolean = {
         short_name = {
            value = true,
            related = "weechat.look.hotlist_short_names",
            description = ""
         }
      },
      ["string"] = {
         separator = {
            value = ", ",
            related = "weechat.look.hotlist_buffer_separator",
            description = ""
         },
         prefix = {
            value = "C: ",
            description = "Text displayed at the beginning of coldlist"
         },
         suffix = {
            value = "",
            description = "Text displayed at the end of coldlist"
         }
      },
      integer = {
         count_min_msg = {
            value = 2,
            related = "weechat.look.hotlist_count_min_msg",
            description = "Display messages count if number of messages is greater or equal to this value"
         }
      },
      color = {
         color_buffer_name = {
            value = "default",
            description = ""
         },
         color_count_highlight = {
            value = "magenta",
            related = "weechat.color.status_count_highlight",
            description = ""
         },
         color_count_msg = {
            value = "brown",
            related = "weechat.color.status_count_msg"
         },
         color_count_private = {
            value = "green",
            related = "weechat.color.status_count_private"
         },
         color_count_other = {
            value = "green",
            related = "weechat.color.status_count_other"
         },
         color_bufnumber_highlight = {
            value = "lightmagenta",
            related = "weechat.color.status_data_highlight"
         }
      }
   },
   buffers = {
      -- i hate lua table

      -- this is for list of buffers that are in the coldlist
      list = {},

      -- this is map of positions of buffers inside the previous table.
      -- this is needed because lua does not support ordered hashtable.
      positions = {},

      -- this is for list of buffer numbers that are in the coldlist.
      numbers = {}
   }
}

function init_option(name, option_type, weechat_option_name, description)
   if weechat.config_is_set_plugin(name) == 0 then
      local val = g.config[name]
      if weechat_option_name then
         local opt = weechat.config_get(weechat_option_name)
         local func = weechat["config_" .. option_type]

         if func and type(func) == "function" then
            val = func(opt)
         else
            option_type = "string"
            val = weechat.config_get_string(opt)
         end

         if option_type == "boolean" then
            g.config[name] = (val == 1)
         else
            g.config[name] = val
         end
      end
      weechat.config_set_plugin(name, val)
      if description then
         weechat.config_set_desc_plugin(name, description)
      end
   else
      local val = weechat.config_get_plugin(name)
      if option_type == "integer" then
         val = tonumber(val)
      elseif option_type == "boolean" then
         val = (val == "1")
      end
      g.config[name] = val
   end
end

function load_config()
   for option_type, option_list in pairs(g.defaults) do
      for name, info in pairs(option_list) do
         init_option(name, option_type, info.related, info.description)
      end
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
             count = 1,
             highlight = highlight
          }

         g.buffers.positions[buffer] = pos
         if not g.buffers.numbers[buffer_num] then
            g.buffers.numbers[buffer_num] = {}
         end
         table.insert(g.buffers.numbers[buffer_num], buffer)
      else
         local pos = g.buffers.positions[buffer]
         g.buffers.list[pos].count = g.buffers.list[pos].count + 1
         if highlight then
            g.buffers.list[pos].highlight = g.buffers.list[pos].highlight + 1
         end
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

function config_cb(_, option_name, option_value)
   local name = option_name:match("([^%.]+)$")
   if g.config[name] then
      local option_type = type(g.config[name])
      if option_type == "number" then
         option_value = tonumber(option_value)
      elseif option_type == "boolean" then
         option_value = (option_value == "1")
      end
      g.config[name] = option_value
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
   weechat.hook_config("plugins.var.lua." .. g.script.name .. ".*", "config_cb", "")
   weechat.hook_print("", "irc_privmsg", "", 0, "print_cb", "")
end

setup()

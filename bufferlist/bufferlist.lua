w, script_name = weechat, "bufferlist"

g = {
   -- TODO: we should use our own config file
   defaults = {
      format = {
         type = "string",
         value = "number , name, (hotlist)",
         desc = [[
Format of buffer entry. The syntax is a bit similar with bar items except a
comma won't add extra space and '+' is just literal character. The variables you
can use in this option are: number, name, hotlist, rel, index]]
      },
      bar_name = {
         type = "string",
         value = script_name,
         desc = "The name of bar that will have autoscroll feature"
      },
      always_show_number = {
         type = "boolean",
         value = "on",
         desc = "Always display the buffer number"
      },
      show_hidden_buffers = {
         type = "boolean",
         value = "off",
         desc = "Show hidden buffers"
      },
      relation = {
         type = "string",
         value = "merged",
         choices = { merged = true, same_server = true },
         desc = ""
      },
      rel_char_start = {
         type = "string",
         value = "",
         desc = "Characters for the first entry in a set of related buffers"
      },
      rel_char_end = {
         type = "string",
         value = "",
         desc = "Characters for the last entry in a set of related buffers"
      },
      rel_char_middle = {
         type = "string",
         value = "",
         desc = "Characters for the middle entries in a set of related buffers"
      },
      rel_char_none = {
         type = "string",
         value = "",
         desc = "Characters for non related buffers"
      },
      color_number = {
         type = "color",
         value = "green",
         desc = "Color for buffer numbers and indexes"
      },
      color_normal = {
         type = "color",
         value = "default,default",
         desc = "Color for normal buffer entry"
      },
      color_current = {
         type = "color",
         value = "white,red",
         desc = "Color for current buffer entry"
      },
      color_other_win = {
         type = "color",
         value = "white,default",
         desc = "Color for buffers that are displayed in other windows"
      },
      color_out_of_zoom = {
         type = "color",
         value = "darkgray,default",
         desc = "Color for merged buffers that are not visible because there's a zoomed buffer"
      },
      color_hidden = {
         type = "color",
         value = "darkgray,default",
         desc = "Color for hidden buffers when option `show_hidden_buffers` is enabled"
      },
      color_hotlist_low = {
         type = "color",
         value = "default",
         desc = "Color for buffers with hotlist level low (joins, quits, etc)"
      },
      color_hotlist_message = {
         type = "color",
         value = "yellow",
         desc = "Color for buffers with hotlist level message (channel conversation)"
      },
      color_hotlist_private = {
         type = "color",
         value = "lightgreen",
         desc = "Color for buffers with hotlist level private"
      },
      color_hotlist_highlight = {
         type = "color",
         value = "magenta",
         desc = "Color for buffers with hotlist level highlight"
      },
      color_rel = {
         type = "color",
         value = "default",
         desc = "Color for rel chars"
      }
   },
   config = {},
   max_num_length = 0,
   current_index = 0,
   buffers = {},
   hotlist = {
      buffers = {},
      levels = { "low", "message", "private", "highlight" }
   },
   bar = {},
   colors = {},
   hooks = {},
   output = "",
   mouse_keys = {
      ["@item("..script_name.."):*"] = "hsignal:"..script_name.."_mouse_action",
      ["@item("..script_name.."):*-event-*"] = "hsignal:"..script_name.."_mouse_event"
   }
}

function main()
   local reg = w.register(
      script_name, "singalaut <https://github.com/tomoe-mami>",
      "0.1", "WTFPL", "", "unload_cb", "")

   if reg then
      config_init()
      bar_init()

      w.bar_item_new(script_name, "item_cb", "")

      update_hotlist()
      rebuild_cb(nil, "script_init", w.current_buffer())

      local signals = {
         ["rebuild_cb"] = {
            "buffer_opened", "buffer_closed", "buffer_hidden", "buffer_unhidden",
            "buffer_merged", "buffer_unmerged", "buffer_moved", "buffer_renamed",
            "window_opened", "window_closing",
            "buffer_localvar_*"
         },
         ["prop_change_cb"] = {
            "buffer_switch", "buffer_zoomed", "buffer_unzoomed"
         },
         ["redraw_cb"] = { "signal_sigwinch", "window_switch" }
      }
      for callback, names in pairs(signals) do
         for _, name in ipairs(names) do
            w.hook_signal(name, callback, "")
         end
      end
      w.hook_signal("hotlist_changed", "hotlist_cb", "")
      w.hook_config("plugins.var.lua."..script_name..".*", "config_cb", "")

      w.hook_command_run("/buffer +1", "cmd_switch_buffer_cb", "next")
      w.hook_command_run("/buffer -1", "cmd_switch_buffer_cb", "prev")

      w.hook_command(
         script_name,
         "Command helper for bufferlist script",
         "switch next|prev|<index>"..
         " || move <index1> <index2>"..
         " || swap <index1> <index2>"..
         " || close <index1> [<index2>]",
[[
   select:
     move:
     swap:
    close:
 <index*>: Buffer index
]],
         "",
         "command_cb", "")

      mouse_init()
   end
end

function config_init()
   local defaults, colors = g.defaults, g.colors
   for name, info in pairs(defaults) do
      local value
      if w.config_is_set_plugin(name) == 1 then
         value = w.config_get_plugin(name)
      else
         w.config_set_plugin(name, info.value)
         w.config_set_desc_plugin(name, info.desc)
         value = info.value
      end
      config_cb("script_init", name, value)
   end
   g.colors.color_delim = w.color("bar_delim")
end

function config_cb(param, opt_name, opt_value)
   opt_name = opt_name:gsub("^plugins%.var%.lua%."..script_name..".", "")
   local info = g.defaults[opt_name]
   if info then
      if info.type == "boolean" then
         opt_value = w.config_string_to_boolean(opt_value) == 1
      elseif info.choices and not info.choices[opt_value] then
         opt_value = info.value
      end
      g.config[opt_name] = opt_value
      if info.type == "color" then
         g.colors[opt_name] = w.color(opt_value)
      end
   end
   if param ~= "script_init" then
      if opt_name == "bar_name" then
         bar_init()
      elseif opt_name == "relation" then
         return rebuild_cb(nil, "change_relation")
      elseif opt_name == "show_hidden_buffers" then
         return rebuild_cb(nil, "hidden_flag")
      end
      w.bar_item_update(script_name)
   end
   return w.WEECHAT_RC_OK
end

function bar_init()
   local name = g.config.bar_name
   local ptr_bar = w.bar_search(name)
   if ptr_bar == "" then
      ptr_bar = w.bar_new(
         name, "off", 100, "root", "", "left", "columns_vertical", "vertical",
         0, 20, "default", "cyan", "default", "on", script_name)
   end
   return ptr_bar
end

function mouse_init()
   w.hook_focus(script_name, "focus_cb", "")
   w.hook_hsignal(script_name.."_mouse_action", "mouse_action_cb", "")
   w.hook_hsignal(script_name.."_mouse_event", "mouse_event_cb", "")
   w.key_bind("mouse", g.mouse_keys)
end

-- when a mouse event occurred, focus_cb are called first and the returned table will
-- be passed to mouse_cb
function focus_cb(_, t)
   local index = t._bar_item_line + 1
   if t._bar_name == script_name and g.buffers[index] then
      for k, v in pairs(g.buffers[index]) do
         t[k] = v
      end
   end
   return t
end

function mouse_action_cb(_, _, t)
   if t._key == "button1" then
      if t._bar_item_line == t._bar_item_line2 then
         w.buffer_set(t.pointer, "display", "1")
         return w.WEECHAT_RC_OK
      end
   end
   return w.WEECHAT_RC_OK
end

function mouse_event_cb(_, _, t)
   dump_keys(t)
   return w.WEECHAT_RC_OK
end

function dump_keys(t)
   local ptr_buffer = w.buffer_search("lua", script_name.."_keys")
   if ptr_buffer == "" then
      ptr_buffer = w.buffer_new(script_name.."_keys", "", "", "", "")
      if ptr_buffer == "" then
         return
      end
      w.buffer_set(ptr_buffer, "type", "free")
      w.buffer_set(ptr_buffer, "title", script_name)
      w.buffer_set(ptr_buffer, "clear", "0")
      w.buffer_set(ptr_buffer, "display", "1")
   end
   local cols = { {}, {} }
   local width = { 0, 0 }
   for k, v in pairs(t) do
      if not k:match("_localvar_") then
         local i = k:sub(-1) == "2" and 2 or 1
         local line = string.format("%s = %q", k, v)
         if #line > width[i] then
            width[i] = #line
         end
         table.insert(cols[i], line)
      end
   end
   table.sort(cols[1])
   table.sort(cols[2])
   local total_lines = #cols[2] > #cols[1] and #cols[2] or #cols[1]

   w.buffer_clear(ptr_buffer)
   for i = 1, total_lines do
      w.print_y(ptr_buffer, i - 1, string.format("%-"..width[1].."s %-"..width[2].."s", cols[1][i] or "", cols[2][i] or ""))
   end
end

function rebuild_cb(_, signal_name, ptr_buffer)
   g.buffers, g.max_num_length = get_buffer_list()
   w.bar_item_update(script_name)
   if signal_name == "script_init" then
      w.hook_timer(30, 0, 1, "autoscroll", "")
   else
      autoscroll()
   end
   return w.WEECHAT_RC_OK
end

function prop_change_cb(_, signal_name, ptr)
   local current_buffer = w.current_buffer()
   local h_buffer = w.hdata_get("buffer")
   for i, row in ipairs(g.buffers) do
      row.displayed = w.hdata_integer(h_buffer, row.pointer, "num_displayed") > 0
      row.current = row.pointer == current_buffer
      row.zoomed = w.hdata_integer(h_buffer, row.pointer, "zoomed") == 1
      row.active = w.hdata_integer(h_buffer, row.pointer, "active")
      row.hidden = w.hdata_integer(h_buffer, row.pointer, "hidden") == 1
      if row.current then
         g.current_index = i
      end
   end

   w.bar_item_update(script_name)
   autoscroll()
   return w.WEECHAT_RC_OK
end

function redraw_cb(_, signal_name, ptr)
   -- TODO: do some checkings here
   w.bar_item_update(script_name)
   autoscroll()
   return w.WECHAT_RC_OK
end

function update_hotlist()
   local hl, list = g.hotlist, {}
   local h_hotlist = w.hdata_get("hotlist")
   local ptr_hotlist = w.hdata_get_list(h_hotlist, "gui_hotlist")
   while ptr_hotlist ~= "" do
      local ptr_buffer = w.hdata_pointer(h_hotlist, ptr_hotlist, "buffer")
      list[ptr_buffer] = {}
      for i, v in ipairs(hl.levels) do
         list[ptr_buffer][v] = w.hdata_integer(h_hotlist,
                                               ptr_hotlist,
                                               (i-1).."|count")
      end
      ptr_hotlist = w.hdata_pointer(h_hotlist, ptr_hotlist, "next_hotlist")
   end
   hl.buffers = list
end

function hotlist_cb()
   update_hotlist()
   w.bar_item_update(script_name)
   return w.WEECHAT_RC_OK
end

function get_buffer_list()
   local entries, groups, conf = {}, {}, g.config
   local index, max_num_len = 0, 0
   local current_buffer = w.current_buffer()
   local h_buffer = w.hdata_get("buffer")
   local ptr_buffer = w.hdata_get_list(h_buffer, "gui_buffers")
   while ptr_buffer ~= "" do
      local t = {
         pointer = ptr_buffer,
         number = w.hdata_integer(h_buffer, ptr_buffer, "number"),
         full_name = w.hdata_string(h_buffer, ptr_buffer, "full_name"),
         name = w.hdata_string(h_buffer, ptr_buffer, "short_name"),
         hidden = w.hdata_integer(h_buffer, ptr_buffer, "hidden") == 1,
         active = w.hdata_integer(h_buffer, ptr_buffer, "active"),
         zoomed = w.hdata_integer(h_buffer, ptr_buffer, "zoomed") == 1,
         merged = false,
         displayed = w.hdata_integer(h_buffer, ptr_buffer, "num_displayed") > 0,
         current = ptr_buffer == current_buffer,
         var = w.hdata_hashtable(h_buffer, ptr_buffer, "local_variables"),
         rel = ""
      }

      local num_len = #tostring(t.number)
      if num_len > max_num_len then
         max_num_len = num_len
      end

      if t.name == "" then
         t.name = w.hdata_string(h_buffer, ptr_buffer, "name")
      end

      if not t.hidden or conf.show_hidden_buffers then
         index = index + 1
         if t.current then
            g.current_index = index
         end

         if conf.relation == "same_server" then
            if (t.var.type == "server" or
                t.var.type == "channel" or
                t.var.type == "private") and
                t.var.server and
                t.var.server ~= "" then

               if not groups[t.var.server] then
                  groups[t.var.server] = {}
               end
               table.insert(groups[t.var.server], index)

            end
         elseif conf.relation == "merged" then
            if not groups[t.number] then
               groups[t.number] = index
               local before = index - 1
               if entries[before] and entries[before].merged then
                  entries[before].rel = "end"
               end
            else
               if type(groups[t.number]) ~= "table" then
                  entries[ groups[t.number] ].merged = true
                  entries[ groups[t.number] ].rel = "start"
                  groups[t.number] = { groups[t.number] }
               end
               t.merged = true
               t.rel = "middle"
               table.insert(groups[t.number], index)
            end
         end
      end

      ptr_buffer = w.hdata_pointer(h_buffer, ptr_buffer, "next_buffer")

      if not t.hidden or conf.show_hidden_buffers then
         entries[index] = t
      end

   end

   if conf.relation == "same_server" then
      entries = group_by_server(entries, groups)
   end

   return entries, max_num_len
end

function group_by_server(entries, groups)
   local new_list, copied, new_index = {}, {}, 0
   for index, row in ipairs(entries) do
      if not copied[index] then
         if not row.var.server or
            row.var.server == "" or
            not groups[row.var.server] then
            new_index = new_index + 1
            new_list[new_index] = row
            copied[index] = new_index
            if row.current then
               g.current_index = new_index
            end
         else
            local size = #groups[row.var.server]
            for i, orig_index in ipairs(groups[row.var.server]) do
               new_index = new_index + 1
               if i == 1 then
                  entries[orig_index].rel = size == 1 and "" or "start"
               elseif i == size then
                  entries[orig_index].rel = "end"
               else
                  entries[orig_index].rel = "middle"
               end
               new_list[new_index] = entries[orig_index]
               copied[orig_index] = new_index
               if entries[orig_index].current then
                  g.current_index = new_index
               end
            end
         end
      end
   end
   return new_list
end

function generate_output()
   local buffers = g.buffers
   if not buffers then
      return ""
   end
   local total_entries = #buffers
   if total_entries == 0 then
      return ""
   end
   local hl, conf, c = g.hotlist, g.config, g.colors
   local num_len = g.max_num_length
   local num_fmt = "%s%s%"..num_len.."s"
   local idx_fmt = "%s%s%"..#tostring(total_entries).."s"
   local entries, last_num = {}, 0
   local rels = {
      start = conf.rel_char_start,
      middle = conf.rel_char_middle,
      ["end"] = conf.rel_char_end,
      none = conf.rel_char_none
   }
   for i, b in ipairs(buffers) do
      local parts, color_base = {}
      if b.current then
         color_base = c.color_current
      elseif b.displayed and b.active > 0 then
         color_base = c.color_other_win
      elseif b.zoomed and b.active == 0 then
         color_base = c.color_out_of_zoom
      elseif b.hidden then
         color_base = c.color_hidden
      else
         color_base = c.color_normal
      end

      parts.rel = rels[b.rel] or rels.none
      if parts.rel ~= "" then
         parts.rel = c.color_rel..parts.rel
      end

      local number = b.number
      if not conf.always_show_number and b.merged and b.rel ~= "start" then
         number = ""
      end
      parts.index = idx_fmt:format(color_base, c.color_number, i)
      parts.number = num_fmt:format(color_base, c.color_number, number)

      local hotlist, color_highest_lev = hl.buffers[b.pointer]
      if hotlist then
         local h = {}
         for k = #hl.levels, 1, -1 do
            local lev = hl.levels[k]
            if hotlist[lev] > 0 then
               if not color_highest_lev then
                  color_highest_lev = c["color_hotlist_"..lev]
               end
               table.insert(h, c["color_hotlist_"..lev]..hotlist[lev])
            end
         end
         parts.hotlist = table.concat(h, c.color_delim..",")
      end

      parts.name = b.name
      if (b.zoomed and b.active == 0) or b.hidden then
         parts.name = color_base..parts.name
      else
         parts.name = (color_highest_lev or color_base)..parts.name
      end

      local entry = ""
      for seg in conf.format:gmatch("([^,]+)") do
         local before, key, after = seg:match("^(.-)(\\?[a-z]+)(.-)$")
         if key then
            local val
            if key:sub(1, 1) == "\\" then
               key = key:sub(2)
               if b.var[key] and b.var[key] ~= "" then
                  val = color_base..b.var[key]
               end
            elseif parts[key] and parts[key] ~= "" then
               val = parts[key]
            end
            if val then
               entry = entry..color_base..c.color_delim..before..
                       val..c.color_delim..after
            end
         end
      end
      buffers[i].length = w.strlen_screen(entry)
      if b.current then
         entry = color_base..strip_bg_color(entry)
      end
      table.insert(entries, entry)
   end
   return table.concat(entries, "\n")
end

function scroll_bar_area(t)
   local width = w.hdata_integer(t.h_area, t.ptr_area, "width")
   local height = w.hdata_integer(t.h_area, t.ptr_area, "height")
   if width < 1 or height < 1 then
      return
   end
   local col_height = w.hdata_integer(t.h_area, t.ptr_area, "screen_lines")
   if t.fill:sub(1, 8) == "columns_" and col_height < 1 then
      return
   end
   local col_width = w.hdata_integer(t.h_area, t.ptr_area, "screen_col_size")
   local scroll_x = w.hdata_integer(t.h_area, t.ptr_area, "scroll_x")
   local scroll_y = w.hdata_integer(t.h_area, t.ptr_area, "scroll_y")
   local cur_y, col_count, bottom_y = t.cur_y, 0, scroll_y + height
   local amount_y, amount_x

   if t.fill == "columns_vertical" then
      cur_y = t.cur_y % col_height
   elseif t.fill == "columns_horizontal" then
      col_count = math.floor(width / col_width)
      cur_y = math.floor(cur_y / col_count) % col_height
   end
   if cur_y < scroll_y then
      amount_y = cur_y - scroll_y - 1
   elseif cur_y >= bottom_y then
      amount_y = "+"..cur_y - bottom_y + 1
   end

   if amount_y then
      w.command(t.ptr_buffer, string.format(
                                 "/bar scroll %s %s y%s",
                                 t.bar_name,
                                 t.win_num,
                                 amount_y))
   end
end

function autoscroll()
   local bar_name = g.config.bar_name
   local ptr_bar = w.bar_search(bar_name)
   if ptr_bar == "" then
      return
   end
   local opt_prefix = "weechat.bar."..bar_name.."."
   local opt_items = w.config_string(w.config_get(opt_prefix.."items"))
   local opt_hidden = w.config_boolean(w.config_get(opt_prefix.."hidden"))
   if opt_hidden == 1 or opt_items ~= script_name then
      return
   end

   local param = {
      h_bar = w.hdata_get("bar"),
      h_area = w.hdata_get("bar_window"),
      ptr_buffer = w.current_buffer(),
      ptr_bar = ptr_bar,
      pos = w.config_string(w.config_get(opt_prefix.."position")),
      cur_y = g.current_index - 1,
      bar_name = bar_name
   }
   if param.pos == "top" or param.pos == "bottom" then
      param.fill = w.config_string(w.config_get(opt_prefix.."filling_top_bottom"))
   else
      param.fill = w.config_string(w.config_get(opt_prefix.."filling_left_right"))
   end
   local ptr_area = w.hdata_pointer(param.h_bar, ptr_bar, "bar_window")
   if ptr_area ~= "" then
      -- root bar
      param.ptr_area = ptr_area
      param.win_num = "*"
      scroll_bar_area(param)
   else
      -- using non-root bar for buffer list is stupid.
      -- but if i don't support it, someone will file an issue just to piss me off
      local h_win = w.hdata_get("window")
      local ptr_win = w.hdata_get_list(h_win, "gui_windows")
      while ptr_win ~= "" do
         local ptr_area = w.hdata_pointer(h_win, ptr_win, "bar_windows")
         while ptr_area ~= "" do
            local ptr_bar = w.hdata_pointer(param.h_area, ptr_area, "bar")
            if ptr_bar == param.ptr_bar then
               param.ptr_area = ptr_area
               param.win_num = w.hdata_integer(h_win, ptr_win, "number")
               scroll_bar_area(param)
            end
            ptr_area = w.hdata_pointer(param.h_area, ptr_area, "next_bar_window")
         end
         ptr_win = w.hdata_pointer(h_win, ptr_win, "next_window")
      end
   end
end

function item_cb()
   return generate_output()
end

function split_args(text)
end

function command_cb(_, ptr_buffer, param)
   return w.WEECHAT_RC_OK
end

function cmd_switch_buffer_cb(dir)
   local idx, total = g.current_index, #g.buffers
   if dir == "next" then
      idx = idx + 1
   elseif dir == "prev" then
      idx = idx - 1
   end
   if idx < 1 then
      idx = total
   elseif idx > total then
      idx = 1
   end
   local buf = g.buffers[idx]
   if buf then
      w.buffer_set(buf.pointer, "display", "1")
      return w.WEECHAT_RC_OK_EAT
   end
   return w.WEECHAT_RC_OK
end

function unload_cb()
   for key, _ in pairs(g.mouse_keys) do
      w.key_unbind("mouse", key)
   end
   return w.WEECHAT_RC_OK
end

function strip_bg_color(text)
   local attr = "[%*!/_|]*"
   local patterns = {
      ["\025B%d%d"] = "",
      ["\025B@%d%d%d%d%d"] = "",
      ["\025bB"] = "",
      ["\025%*("..attr..")(%d%d),%d%d"] = "\025F%1%2",
      ["\025%*("..attr..")(%d%d),@%d%d%d%d%d"] = "\025F%1%2",
      ["\025%*("..attr..")(@%d%d%d%d%d),%d%d"] = "\025F%1%2",
      ["\025%*("..attr..")(@%d%d%d%d%d),@%d%d%d%d%d"] = "\025F%1%2"
   }
   for p, r in pairs(patterns) do
      text = text:gsub(p, r)
   end
   return text
end

main()

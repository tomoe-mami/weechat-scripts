w, script_name = weechat, "bufferlist"

g = {
   config_loaded = false,
   max_num_length = 0,
   current_index = 0,
   buffers = {
      list = {},
      pointers = {}
   },
   selection = {},
   hotlist = {
      buffers = {},
      levels = { "low", "message", "private", "highlight" }
   },
   bar = {},
   colors = {},
   hooks = {},
   mouse = {
      keys = {
         ["@item("..script_name.."):*"] = "hsignal:"..script_name.."_mouse_event",
         ["@item("..script_name.."):*-event-*"] = "hsignal:"..script_name.."_mouse_event"
      }
   }
}

function main()
   local reg = w.register(
      script_name, "singalaut <https://github.com/tomoe-mami>",
      "0.1", "WTFPL", "", "unload_cb", "")

   if reg then
      local wee_ver = tonumber(w.info_get("version_number", "")) or 0
      if wee_ver < 0x01000000 then
         error("\nError: This script requires WeeChat >= 1.0")
      end

      check_utf8_support()
      config_init()
      w.bar_item_new(script_name, "item_cb", "")
      update_hotlist()
      rebuild_cb(nil, "script_init", w.current_buffer())
      register_hooks()
      mouse_init()
   end
end

function config_init()
   local conf_file = w.config_new(script_name, "", "")
   if conf_file == "" then
      error(string.format("\nError initiating file %s.conf in directory %s",
                          script_name,
                          w.info_get("weechat_dir", "")))
   end

   local sections = {}
   for _, name in ipairs({"look", "color"}) do
      sections[name] = w.config_new_section(
         conf_file, name, 0, 0, "", "", "", "", "", "",
         "", "", "", "")

      if sections[name] == "" then
         w.config_free(conf_file)
         error(string.format("\nError initiating section %s in file %s.conf",
                             name,
                             script_name))
      end
   end

   local options = {}
   options.look = config_create_options {
      file = conf_file,
      section = sections.look,
      options = {
         format = {
            default = "number ,rel,prefix,short_name, (hotlist)",
            desc = "Format of buffer entry",
            change_cb = "redraw_cb"
         },
         bar_name = {
            default = script_name,
            desc = "The name of bar that will have autoscroll feature",
            change_cb = "config_bar_cb"
         },
         always_show_number = {
            type = "boolean",
            default = "off",
            desc = "Always show buffer number",
            change_cb = "redraw_cb"
         },
         show_hidden_buffers = {
            type = "boolean",
            default = "on",
            desc = "Show hidden buffers",
            change_cb = "rebuild_cb"
         },
         enable_lag_indicator = {
            type = "boolean",
            default  = "off",
            desc = "Enable lag indicator in format",
            change_cb = "lag_hooks"
         },
         prefix_placeholder = {
            default = " ",
            desc = "Placeholder for item prefix",
            change_cb = "rebuild_cb"
         },
         max_name_length = {
            type = "integer",
            default  = "0",
            min = 0,
            max = 128,
            desc = "Maximum length of buffer name (0 = no limit)",
            change_cb = "rebuild_cb"
         },
         align_number = {
            type = "integer",
            default  = "right",
            enum = { "left", "right", "none" },
            desc = "Alignment of numbers and indexes",
            change_cb = "redraw_cb"
         },
         relation = {
            type = "integer",
            default  = "merged",
            enum = { "merged", "same_server", "none" },
            desc = "Relation mode of buffers",
            change_cb = "rebuild_cb"
         },
         rel_char_start = {
            default = "",
            desc = "Text of item `rel` for the first related buffer",
            change_cb = "redraw_cb"
         },
         rel_char_end = {
            default = "",
            desc = "Text of item `rel` for the last related buffer",
            change_cb = "redraw_cb"
         },
         rel_char_middle = {
            default = "",
            desc = "Text of item `rel` for related buffers in the middle",
            change_cb = "redraw_cb"
         },
         rel_char_none = {
            default = "",
            desc = "Text of item `rel` for non-related buffers",
            change_cb = "redraw_cb"
         },
         char_more = {
            default = "+",
            desc = "Text added to buffer name when it is truncated",
            change_cb = "rebuild_cb"
         },
         char_selection = {
            default = "",
            desc = "Selection marker character (for item `sel`)",
            change_cb = "redraw_cb"
         }
      }
   }

   options.color = config_create_options {
      file = conf_file,
      section = sections.color,
      options = {
         number = {
            default = "yellow",
            desc = "Color for buffer numbers and indexes",
            change_cb = "config_color_cb"
         },
         normal = {
            default = "default,default",
            desc = "Color for normal buffer entry",
            change_cb = "config_color_cb"
         },
         current = {
            default = "white,red",
            desc = "Color for current buffer entry",
            change_cb = "config_color_cb"
         },
         selected = {
            default  = "white,blue",
            desc = "Color of selected buffer",
            change_cb = "config_color_cb"
         },
         other_win = {
            default = "white,default",
            desc = "Color for buffers that are displayed in other windows",
            change_cb = "config_color_cb"
         },
         out_of_zoom = {
            default = "darkgray,default",
            desc = "Color for merged buffers that are not visible because there's a zoomed buffer",
            change_cb = "config_color_cb"
         },
         hidden = {
            default = "darkgray,default",
            desc = "Color for hidden buffers",
            change_cb = "config_color_cb"
         },
         hotlist_low = {
            default = "default",
            desc = "Color for buffers with hotlist level low (joins, quits, etc)",
            change_cb = "config_color_cb"
         },
         hotlist_message = {
            default = "cyan",
            desc = "Color for buffers with hotlist level message (channel conversation)",
            change_cb = "config_color_cb"
         },
         hotlist_private = {
            default  = "lightgreen",
            desc = "Color for buffers with hotlist level private",
            change_cb = "config_color_cb"
         },
         hotlist_highlight = {
            default  = "lightmagenta",
            desc = "Color for buffers with hotlist level highlight",
            change_cb = "config_color_cb"
         },
         rel = {
            default = "default",
            desc = "Color for rel chars",
            change_cb = "config_color_cb"
         },
         prefix_placeholder = {
            default = "red",
            desc = "Color for option prefix_placeholder",
            change_cb = "config_color_cb"
         },
         delim = {
            default = "bar_delim",
            desc = "Color for delimiter",
            change_cb = "config_color_cb"
         },
         lag = {
            default = "default",
            desc = "Color for lag indicator",
            change_cb = "config_color_cb"
         }
      }
   }

   w.config_read(conf_file)

   g.config_file = conf_file
   g.config_sections = sections
   g.options = options

   local cur_val = w.config_string(options.look.bar_name)
   local default = w.config_string_default(options.look.bar_name)
   if cur_val == default then
      config_bar_cb(nil, options.look.bar_name)
   end
   g.colors = config_load_colors(options.color)
   g.config_loaded = true
end

function config_create_options(data)
   local tb_option = {}
   for name, t in pairs(data.options) do
      t.default = t.default or ""
      t.value = t.value or t.default
      tb_option[name] = w.config_new_option(
         data.file,
         data.section,
         name,
         t.type or "string",
         string.gsub(t.desc or "", "\n", " "),
         t.enum and table.concat(t.enum, "|") or "",
         t.min or 0,
         t.max or 0,
         t.default,
         t.value,
         t.allow_null and 1 or 0,
         t.check_cb or "",
         t.check_cb_arg or "",
         t.change_cb or "",
         t.change_cb_arg or "",
         t.delete_cb or "",
         t.delete_cb_arg or "")
   end
   return tb_option
end

function config_color_cb(_, ptr_opt)
   local h_opt = w.hdata_get("config_option")
   local name = w.hdata_string(h_opt, ptr_opt, "name")
   g.colors[name] = w.color(w.config_string(ptr_opt))
   if g.config_loaded then
      redraw_cb()
   end
end

function config_load_colors(list)
   local colors = {}
   for name, ptr_opt in pairs(list) do
      colors[name] = w.color(w.config_string(ptr_opt))
   end
   return colors
end

function config_bar_cb(_, ptr_opt)
   local bar_name = w.config_string(ptr_opt)
   local ptr_bar = w.bar_search(bar_name)
   if ptr_bar == "" then
      ptr_bar = w.bar_new(
         bar_name, "off", 100, "root", "", "left", "columns_vertical", "vertical",
         0, 20, "default", "cyan", "default", "on", script_name)
   else
      local opt_name = "weechat.bar."..bar_name..".items"
      local opt_items = w.config_string(w.config_get(opt_name))
      if opt_items ~= script_name then
         print("Warning: Auto-scroll has been disabled")
      end
   end
   if g.config_loaded then
      redraw_cb()
   end
end

function register_hooks()
   for _, name in ipairs({
      "buffer_opened", "buffer_hidden", "buffer_unhidden", "buffer_closed",
      "buffer_merged", "buffer_unmerged", "buffer_moved"}) do
      w.hook_signal("9000|"..name, "rebuild_cb", "")
   end

   w.hook_signal("9000|window_switch", "window_cb", "")
   w.hook_signal("9000|window_opened", "window_cb", "")
   w.hook_signal("9000|window_closed", "window_cb", "")
   w.hook_signal("9000|buffer_switch", "switch_cb", "")
   w.hook_signal("9000|buffer_renamed", "renamed_cb", "")
   w.hook_signal("9000|buffer_localvar_*", "localvar_changed_cb", "")
   w.hook_signal("9000|buffer_zoomed", "zoom_cb", "")
   w.hook_signal("9000|buffer_unzoomed", "zoom_cb", "")
   w.hook_signal("9000|signal_sigwinch", "redraw_cb", "")
   w.hook_signal("9000|hotlist_changed", "hotlist_cb", "")
   w.hook_signal("9000|nicklist_nick_removed", "nicklist_cb", "")
   w.hook_hsignal("9000|nicklist_nick_added", "nicklist_cb", "")
   w.hook_hsignal("9000|nicklist_nick_changed", "nicklist_cb", "")

   lag_hooks()

   w.hook_command(
      script_name,
      "Extra helper for bufferlist",
      "jump <index>"..
      " || jump next|prev|first|last [related|unrelated]"..
      " || run <command>",
[[
 jump: Jump to buffer based on display position.
  run: Evaluate and run command on selected buffers. If no buffers are selected, current buffer will be used.
]],
      "jump next|prev|first|last related|unrelated || run",
      "command_cb", "")
end

function lag_hooks()
   if not g.config_loaded then
      return
   end
   local options, hooks = g.options, g.hooks
   if hooks.lag then
      w.unhook(hooks.lag)
      hooks.lag = nil
   end
   if w.config_boolean(g.options.look.enable_lag_indicator) == 1 then
      hooks.lag = w.hook_timer(1000, 0, 0, "lag_timer_cb", "")
   end
end

function lag_timer_cb()
   local min_show = w.config_integer(w.config_get("irc.network.lag_min_show"))
   local h_server = w.hdata_get("irc_server")
   local ptr_server = w.hdata_get_list(h_server, "irc_servers")
   local need_refresh = false
   while ptr_server ~= "" do
      if w.hdata_integer(h_server, ptr_server, "is_connected") == 1 then
         local ptr_buffer = w.hdata_pointer(h_server, ptr_server, "buffer")
         local buffer = get_buffer_by_pointer(ptr_buffer)
         if buffer then
            local lag = w.hdata_integer(h_server, ptr_server, "lag_displayed")
            if lag < min_show then
               buffer.lag = nil
            else
               if not need_refresh and buffer.lag ~= lag then
                  need_refresh = true
               end
               buffer.lag = lag
            end
         end
      end
      ptr_server = w.hdata_pointer(h_server, ptr_server, "next_server")
   end
   if need_refresh then
      w.bar_item_update(script_name)
   end
end

function mouse_init()
   w.hook_focus(script_name, "focus_cb", "")
   w.hook_hsignal(script_name.."_mouse_event", "mouse_event_cb", "")
   w.key_bind("mouse", g.mouse.keys)
end

-- when a mouse event occurred, focus_cb are called first and the returned table will
-- be passed to mouse_cb
function focus_cb(_, t)
   if t._bar_item_name == script_name then
      local k1, k2 = t._key:sub(1, -12), t._key:sub(-11)
      if k2 == "-event-down" then
         t.mode, t.key = "init", k1
      elseif k2 == "-event-drag" then
         t.mode, t.key = "drag", k1
      else
         t.mode, t.key = "action", t._key
      end
      local index = t._bar_item_line + 1
      local buffer = g.buffers.list[index]
      if buffer then
         t.pointer = buffer.pointer
         t.number = buffer.number
      end
   end
   return t
end

function mouse_event_cb(_, _, t)
   if t.mode == "init" then
      g.mouse.drag = false
      if t.key == "button1" then
         return cmd_selection("add", t.pointer)
      elseif t.key == "button2" then
         return cmd_selection("delete", t.pointer)
      end
   elseif t.mode == "drag" then
      g.mouse.drag = true
      if t.key == "button1" then
         return cmd_selection("add", t.pointer2)
      elseif t.key == "button2" then
         return cmd_selection("delete", t.pointer2)
      elseif t.key == "ctrl-button1" then
         return cmd_move(t)
      end
   else
      if t.key == "button1" then
         if not g.mouse.drag then
            cmd_jump_mouse(t.pointer)
         end
      elseif t.key == "ctrl-button2" then
         cmd_selection("clear")
      elseif t.key == "button3" then
         cmd_merge()
      elseif t.key == "ctrl-button3" then
         cmd_unmerge()
      elseif t.key:match("^ctrl%-button1") then
         if t._bar_name2 ~= w.config_string(g.options.look.bar_name) then
            cmd_close()
         end
         if g.mouse.temp_select then
            cmd_selection("clear")
         end
      elseif t.key == "wheelup" then
         cmd_jump("", "prev")
      elseif t.key == "wheeldown" then
         cmd_jump("", "next")
      end
      g.mouse.temp_select = nil
      g.mouse.last_event = nil
      g.mouse.drag = nil
   end
   return w.WEECHAT_RC_OK
end

function rebuild_cb(_, signal_name, ptr_buffer)
   if g.config_loaded then
      g.buffers, g.max_num_length = get_buffer_list()
      w.bar_item_update(script_name)
      if signal_name == "script_init" then
         w.hook_timer(50, 0, 1, "autoscroll", "now")
      else
         autoscroll()
      end
   end
   return w.WEECHAT_RC_OK
end

function regroup_by_server(own_index, buffer, new_var)
   local server_buffer
   if not new_var.type or
      not new_var.server or
      buffer.var.server == new_var.server then
      return
   end
   local buffers = g.buffers
   local server_index
   if w.buffer_get_string(buffer.pointer, "plugin") == "irc" then
      server_buffer = w.info_get("irc_buffer", new_var.server)
      server_index = buffers.pointers[server_buffer]
   elseif new_var.type == "server" then
      server_index = own_index
   else
      for i, row in ipairs(buffers.list) do
         if row.var.type == "server" and row.var.server == new_var.server then
            server_index = i
            break
         end
      end
   end
   if not server_index or not buffers.list[server_index] then
      return
   end
   local pos = 0
   for i = server_index, buffers.total do
      pos = i
      if buffers.list[i].var.server ~= new_var.server or
         buffers.list[i].number > buffer.number then
         break
      end
   end
   if pos > 0 then
      if pos == server_index then
         buffer.rel = ""
      else
         if pos ~= own_index then
            buffers.pointers[buffer.pointer] = pos
            table.insert(buffers.list, pos, buffer)
            table.remove(buffers.list, own_index + 1)
         end
         local next_buffer, prev_buffer = buffers.list[pos+1], buffers.list[pos-1]
         if next_buffer and next_buffer.var.server == new_var.server then
            buffer.rel = "middle"
         else
            buffer.rel = "end"
            if prev_buffer then
               if prev_buffer.rel == "end" then
                  prev_buffer.rel = "middle"
               elseif prev_buffer.rel == "" then
                  prev_buffer.rel = "start"
               end
            end
         end
      end
   end
end

function localvar_changed_cb(_, signal_name, ptr_buffer)
   local options = g.options
   local buffer, index = get_buffer_by_pointer(ptr_buffer)
   if not buffer then
      return w.WEECHAT_RC_OK
   end
   local h_buffer = w.hdata_get("buffer")
   local new_var = w.hdata_hashtable(h_buffer, ptr_buffer, "local_variables")
   if w.config_string(options.look.relation) == "same_server" and
      buffer.var.server ~= new_var.server then
      return rebuild_cb(nil, "server_changed", ptr_buffer)
   end
   if buffer.var.type ~= new_var.type and
      new_var.type == "channel" and
      not buffer.prefix then
      buffer.prefix = w.config_string(options.look.prefix_placeholder)
      buffer.prefix_color = w.config_string(options.color.prefix_placeholder)
   end
   buffer.var = new_var
   w.bar_item_update(script_name)
   return w.WEECHAT_RC_OK
end

function renamed_cb(_, _, ptr_buffer)
   local max_length = w.config_integer(g.options.look.max_name_length)
   local char_more = w.config_string(g.options.look.char_more)
   local buffer = get_buffer_by_pointer(ptr_buffer)
   if buffer then
      for _, k in ipairs({"full_name", "name", "short_name"}) do
         buffer[k] = w.string_remove_color(w.buffer_get_string(buffer.pointer, k), "")
         if max_length > 0 then
            buffer[k] = string_limit(buffer[k], max_length, char_more)
         end
      end
   end
   w.bar_item_update(script_name)
   autoscroll("now")
   return w.WEECHAT_RC_OK
end

function switch_cb(_, _, ptr_buffer)
   local buffer, index = get_buffer_by_pointer(ptr_buffer)
   if buffer then
      local h_buffer = w.hdata_get("buffer")
      buffer.current = true
      buffer.displayed = true
      buffer.active = w.hdata_integer(h_buffer, ptr_buffer, "active")
      local prev = g.buffers.list[g.current_index]
      if prev then
         prev.current = false
         prev.displayed = w.buffer_get_integer(prev.pointer, "num_displayed") > 0
         prev.active = w.buffer_get_integer(prev.pointer, "active")
      end
      g.current_index = index
      w.bar_item_update(script_name)
      autoscroll("now")
   end
   return w.WEECHAT_RC_OK
end

function window_cb(_, signal, ptr_win)
   local ptr_buffer = w.window_get_pointer(ptr_win, "buffer")
   local buffer, index = get_buffer_by_pointer(ptr_buffer)
   if buffer then
      g.buffers.list[g.current_index].current = false
      if signal == "window_opened" or signal == "window_switch" then
         buffer.displayed = true
         buffer.current = true
         g.current_index = index
      elseif signal == "window_closed" then
         buffer.displayed = w.buffer_get_integer(ptr_buffer, "num_displayed") > 0
         ptr_buffer = w.window_get_pointer(w.current_window(), "buffer")
         buffer, index = get_buffer_by_pointer(ptr_buffer)
         if buffer then
            buffer.displayed = true
            buffer.current = true
            g.current_index = index
         end
      end
      w.bar_item_update(script_name)
      autoscroll("now")
   end
   return w.WEECHAT_RC_OK
end

function zoom_cb(_, signal, ptr_buffer)
   local buffer = get_buffer_by_pointer(ptr_buffer)
   if not buffer then
      return w.WEECHAT_RC_OK
   end
   local ptr_current = w.current_buffer()
   local h_buffer = w.hdata_get("buffer")
   local ptr_merged = w.hdata_search(
      h_buffer,
      w.hdata_get_list(h_buffer, "gui_buffers"),
      "${buffer.number} == "..buffer.number, 1)
   while ptr_merged ~= "" do
      if w.hdata_integer(h_buffer, ptr_merged, "number") ~= buffer.number then
         break
      end
      local row = get_buffer_by_pointer(ptr_merged)
      if row then
         row.current = ptr_merged == ptr_current
         row.zoomed = w.hdata_integer(h_buffer, ptr_merged, "zoomed") == 1
         row.active = w.hdata_integer(h_buffer, ptr_merged, "active")
      end
      ptr_merged = w.hdata_pointer(h_buffer, ptr_merged, "next_buffer")
   end

   w.bar_item_update(script_name)
   autoscroll("now")
   return w.WEECHAT_RC_OK
end

function redraw_cb()
   if g.config_loaded then
      w.bar_item_update(script_name)
      autoscroll("now")
   end
   return w.WECHAT_RC_OK
end

function nicklist_cb(_, signal_name, data)
   local ptr_buffer, ptr_nick, nick
   if signal_name == "nicklist_nick_removed" then
      ptr_buffer, nick = data:match("^([^,]+),(.+)$")
   else
      ptr_buffer, ptr_nick = data.buffer, data.nick
   end
   local buffer = get_buffer_by_pointer(ptr_buffer)
   if not buffer or buffer.var.type ~= "channel" then
      return w.WEECHAT_RC_OK
   end
   if not ptr_nick then
      ptr_nick = w.nicklist_search_nick(ptr_buffer, "", nick)
   end
   if not nick then
      nick = w.nicklist_nick_get_string(ptr_buffer, ptr_nick, "name")
   end
   if nick == buffer.var.nick then
      if signal_name == "nicklist_nick_removed" then
         buffer.prefix = w.config_string(g.options.look.prefix_placeholder)
         buffer.prefix_color = w.config_string(g.options.color.prefix_placeholder)
      else
         buffer.prefix = w.nicklist_nick_get_string(ptr_buffer, ptr_nick, "prefix")
         buffer.prefix_color = w.nicklist_nick_get_string(ptr_buffer, ptr_nick, "prefix_color")
      end
      w.bar_item_update(script_name)
   end
   return w.WEECHAT_RC_OK
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

function get_irc_server(server_name)
   local h_server, buffer = w.hdata_get("irc_server")
   local ptr_server = w.hdata_search(
      h_server,
      w.hdata_get_list(h_server, "irc_servers"),
      "${irc_server.name} == "..server_name, 1)
   if ptr_server ~= "" then
      local ptr_buffer = w.hdata_pointer(h_server, ptr_server, "buffer")
      buffer = get_buffer_by_pointer(ptr_buffer)
   end
   return ptr_server, h_server, buffer
end

function get_buffer_by_pointer(ptr_buffer)
   local index = g.buffers.pointers[ptr_buffer]
   if index then
      return g.buffers.list[index], index
   end
end

function get_buffer_list()
   local entries, groups, options = {}, {}, g.options
   local pointers = {}
   local index, prev_index = 0, 0, 0
   local current_buffer = w.current_buffer()
   local h_buffer, h_nick = w.hdata_get("buffer"), w.hdata_get("nick")
   local ptr_buffer = w.hdata_get_list(h_buffer, "gui_buffers")
   local names = { "name", "short_name", "full_name" }
   local prev_number = 0

   local o = {
      show_hidden_buffers = w.config_boolean(options.look.show_hidden_buffers),
      relation = w.config_string(options.look.relation),
      max_name_length = w.config_integer(options.look.max_name_length),
      char_more = w.config_string(options.look.char_more),
      prefix_placeholder = w.config_string(options.look.prefix_placeholder),
      color_prefix_placeholder = w.config_string(options.color.prefix_placeholder)
   }

   while ptr_buffer ~= "" do
      local is_hidden = w.hdata_integer(h_buffer, ptr_buffer, "hidden") == 1
      if not is_hidden or o.show_hidden_buffers == 1 then
         local t = {
            pointer = ptr_buffer,
            number = w.hdata_integer(h_buffer, ptr_buffer, "number"),
            hidden = is_hidden,
            active = w.hdata_integer(h_buffer, ptr_buffer, "active"),
            zoomed = w.hdata_integer(h_buffer, ptr_buffer, "zoomed") == 1,
            merged = false,
            displayed = w.hdata_integer(h_buffer, ptr_buffer, "num_displayed") > 0,
            current = ptr_buffer == current_buffer,
            var = w.hdata_hashtable(h_buffer, ptr_buffer, "local_variables"),
            rel = ""
         }

         prev_index, index = index, index + 1
         pointers[ptr_buffer] = index
         if t.current then
            g.current_index = index
         end

         if index > 1 then
            if t.number == prev_number then
               if not entries[prev_index].merged then
                  entries[prev_index].merged = true
                  if o.relation == "merged" then
                     entries[prev_index].rel = "start"
                  end
               end
               t.merged = true
               if o.relation == "merged" then
                  t.rel = "middle"
               end
            elseif entries[prev_index].merged and o.relation == "merged" then
               entries[prev_index].rel = "end"
            end
         end

         prev_number = t.number

         for _, k in pairs(names) do
            t[k] = w.string_remove_color(w.hdata_string(h_buffer, ptr_buffer, k), "")
            if o.max_name_length > 0 then
               t[k] = string_limit(t[k], o.max_name_length, o.char_more)
            end
         end

         if t.var.type == "channel" then
            local nicks = w.hdata_integer(h_buffer, ptr_buffer, "nicklist_nicks_count")
            if nicks > 0 and t.var.nick and t.var.nick ~= "" then
               local ptr_nick = w.nicklist_search_nick(ptr_buffer, "", t.var.nick)
               if ptr_nick ~= "" then
                  t.prefix = w.hdata_string(h_nick, ptr_nick, "prefix")
                  t.prefix_color = w.hdata_string(h_nick, ptr_nick, "prefix_color")
               end
            else
               t.prefix = o.prefix_placeholder
               t.prefix_color = o.color_prefix_placeholder
            end
         end

         if o.relation == "same_server" and
            t.var.server and t.var.server ~= "" and
            (t.var.type == "server" or t.var.type == "channel" or t.var.type == "private") then
            if not groups[t.var.server] then
               groups[t.var.server] = {}
            end
            if t.var.type == "server" then
               table.insert(groups[t.var.server], 1, index)
            else
               table.insert(groups[t.var.server], index)
            end
         end

         entries[index] = t
      end -- if not is_hidden ...

      ptr_buffer = w.hdata_pointer(h_buffer, ptr_buffer, "next_buffer")

   end -- while ptr_buffer ...

   if o.relation == "same_server" then
      entries, pointers = group_by_server(entries, groups, pointers)
   end

   return { list = entries, pointers = pointers, total = index }, #tostring(prev_number)
end

function group_by_server(entries, groups)
   local new_list, new_pointers, copied, new_index = {}, {}, {}, 0
   for index, row in ipairs(entries) do
      if not copied[index] then
         if not row.var.server or
            row.var.server == "" or
            not groups[row.var.server] then
            new_index = new_index + 1
            new_list[new_index] = row
            copied[index] = new_index
            new_pointers[row.pointer] = new_index
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
               new_pointers[ entries[orig_index].pointer ] = new_index
               if entries[orig_index].current then
                  g.current_index = new_index
               end
            end
         end
      end
   end
   return new_list, new_pointers
end

function replace_format(fmt, items, vars, colors, char_more)
   return string.gsub(fmt..",", "([^,]-),", function (seg)
      if seg == "" then
         return colors.delim..","
      else
         local before, plus_before, key, plus_after, after =
            seg:match("^(.-)(%+?)(%%?[a-z0-9_]+)(%+?)(.-)$")
         if not key then
            return colors.delim..seg
         else
            local item_color = colors[key] or colors.base
            local val
            if key:sub(1, 1) == "%" then
               key = key:sub(2)
               if vars[key] and vars[key] ~= "" then
                  val = vars[key]
               end
            elseif items[key] and items[key] ~= "" then
               val = items[key]
            end
            if val then
               return colors.base..
                      (plus_before == "" and colors.delim or item_color)..before..
                      item_color..val..
                      (plus_after == "" and colors.delim or item_color)..after
            end
         end
      end
      return ""
   end)
end

function generate_output()
   local buffers = g.buffers
   if not buffers.list or not buffers.total or buffers.total < 1 then
      return ""
   end
   local hl, options, c, sel = g.hotlist, g.options, g.colors, g.selection
   local num_fmt, idx_fmt
   local o = {
      align_number = w.config_string(options.look.align_number),
      char_selection = w.config_string(options.look.char_selection),
      always_show_number = w.config_boolean(options.look.always_show_number),
      format = w.config_string(options.look.format),
      char_more = w.config_string(options.look.char_more),
      enable_lag_indicator = w.config_boolean(options.look.enable_lag_indicator)
   }

   if o.align_number ~= "none" then
      local minus = o.align_number == "left" and "-" or ""
      num_fmt = "%"..minus..g.max_num_length.."s"
      idx_fmt = "%"..minus..#tostring(buffers.total).."s"
   end
   local entries, last_num = {}, 0
   local rels = {
      start = w.config_string(options.look.rel_char_start),
      middle = w.config_string(options.look.rel_char_middle),
      ["end"] = w.config_string(options.look.rel_char_end),
      none = w.config_string(options.look.rel_char_none)
   }
   local sel_phold
   if o.char_selection ~= "" then
      sel_phold = string.rep(" ", w.strlen_screen(o.char_selection))
   end
   local prev_number = 0
   for i, b in ipairs(buffers.list) do
      local items = {
         name = b.name,
         short_name = b.short_name,
         full_name = b.full_name
      }
      local colors = {
         delim = c.delim,
         rel = c.rel,
         hotlist = c.delim,
         base = c.normal
      }
      if b.current then
         colors.base = c.current
      elseif sel[b.pointer] and not sel_phold then
         colors.base = c.selected
      elseif b.displayed and b.active > 0 then
         colors.base = c.other_win
      elseif b.zoomed and b.active == 0 then
         colors.name = c.out_of_zoom
      elseif b.hidden then
         colors.name = c.hidden
      end

      items.rel = rels[b.rel] or rels.none
      items.number = b.number
      if o.always_show_number == 0 and prev_number == b.number then
         items.number = ""
      end
      prev_number = b.number
      items.index = idx_fmt and idx_fmt:format(i) or i
      colors.index, colors.number = c.number, c.number
      if num_fmt then
         items.number = num_fmt:format(items.number)
      end

      local hotlist, color_highest_lev = hl.buffers[b.pointer]
      if hotlist then
         local h = {}
         for k = #hl.levels, 1, -1 do
            local lev = hl.levels[k]
            if hotlist[lev] > 0 then
               if not color_highest_lev then
                  color_highest_lev = c["hotlist_"..lev]
               end
               table.insert(h, c["hotlist_"..lev]..hotlist[lev])
            end
         end
         items.hotlist = table.concat(h, c.delim..",")
      end

      if not colors.name then
         colors.name = color_highest_lev or colors.base
      end
      colors.hotlist = color_highest_lev
      colors.short_name, colors.full_name = colors.name, colors.name
      if items.short_name == "" then
         items.short_name = items.name
      end

      if b.prefix then
         items.prefix = b.prefix
         colors.prefix = w.color(b.prefix_color)
      else
         items.prefix, colors.prefix = " ", colors.base
      end

      if o.enable_lag_indicator == 1 and b.lag then
         items.lag = string.format("%.3g", b.lag / 1000)
         colors.lag = c.lag
      end

      if sel[b.pointer] then
         items.sel = o.char_selection
         colors.sel = c.selected
      elseif sel_phold then
         items.sel = sel_phold
      end

      local entry = replace_format(o.format, items, b.var, colors, o.char_more)
      buffers.list[i].length = w.strlen_screen(entry)
      if b.current then
         entry = c.current..strip_bg_color(entry)
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
   local scroll_x = w.hdata_integer(t.h_area, t.ptr_area, "scroll_x")

   if t.fill == "horizontal" then
      local visible_chars = width * height
      local buffers, length_before = g.buffers.list, 0
      for i = 1, t.offset do
         length_before = length_before + (buffers[i].length or 0) + 1
      end
      local own_length = (buffers[t.offset+1].length or 0) + 1
      local last_visible_x = visible_chars + scroll_x
      local amount_x
      if length_before < scroll_x then
         amount_x = length_before - scroll_x - 1
      elseif length_before + own_length > last_visible_x then
         amount_x = "+"..(length_before - last_visible_x) + own_length
      end
      if amount_x then
         w.command(t.ptr_buffer, string.format(
                                    "/bar scroll %s %s x%s",
                                    t.bar_name,
                                    t.win_num,
                                    amount_x))
      end
   else
      local col_height = w.hdata_integer(t.h_area, t.ptr_area, "screen_lines")
      if t.fill:sub(1, 8) == "columns_" and col_height < 1 then
         return
      end
      local col_width = w.hdata_integer(t.h_area, t.ptr_area, "screen_col_size")
      local scroll_y = w.hdata_integer(t.h_area, t.ptr_area, "scroll_y")
      local cur_y, col_count, bottom_y = t.offset, 0, scroll_y + height

      if scroll_x > 0 then
         w.command(t.ptr_buffer, string.format(
                                    "/bar scroll %s %s xb",
                                    t.bar_name,
                                    t.win_num))
      end

      if cur_y > scroll_y and cur_y < bottom_y then
         return
      end

      local amount_y
      if t.fill == "columns_vertical" then
         cur_y = cur_y % col_height
      elseif t.fill == "columns_horizontal" then
         col_count = math.floor(width / col_width)
         cur_y = math.floor(cur_y / col_count) % col_height
      end
      if cur_y < scroll_y then
         amount_y = cur_y - scroll_y
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
end

function autoscroll(mode)
   local bar_name = w.config_string(g.options.look.bar_name)
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
      offset = g.current_index - 1,
      bar_name = bar_name
   }
   if param.pos == "top" or param.pos == "bottom" then
      param.fill = w.config_string(w.config_get(opt_prefix.."filling_top_bottom"))
   else
      param.fill = w.config_string(w.config_get(opt_prefix.."filling_left_right"))
   end
   if param.fill == "horizontal" and mode ~= "now" then
      -- FIXME: FUCK HORIZONTAL BAR!
      w.hook_timer(100, 0, 1, "autoscroll", "now")
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

function get_selection()
   local sel, buffers = g.selection, g.buffers
   local t = {}
   for ptr, _ in pairs(sel) do
      local i = buffers.pointers[ptr]
      local buffer = buffers.list[i]
      if i and buffer then
         buffer.index = i
         table.insert(t, buffer)
      end
   end
   if #t > 0 then
      table.sort(t, function (a, b) return a.index < b.index end)
   end
   return t
end

function cmd_selection(param, ptr_buffer)
   if param == "clear" then
      g.selection = {}
   elseif ptr_buffer and ptr_buffer ~= "" then
      local sel = g.selection
      if not param or param == "add" then
         sel[ptr_buffer] = true
      elseif param == "delete" then
         sel[ptr_buffer] = false
      elseif param == "toggle" then
         sel[ptr_buffer] = not sel[ptr_buffer]
      end
   end
   w.bar_item_update(script_name)
   return w.WEECHAT_RC_OK
end

function cmd_merge()
   local sel = get_selection()
   if #sel < 2 then
      print("Error: You must select at least 2 buffers first before you can use the merge command")
      return w.WEECHAT_RC_ERROR
   end
   local first = table.remove(sel, 1)
   for _, entry in ipairs(sel) do
      w.buffer_merge(entry.pointer, first.pointer)
   end
   return w.WEECHAT_RC_OK
end

function cmd_unmerge()
   local sel = get_selection()
   local h_buffer = w.hdata_get("buffer")
   for _, buffer in ipairs(sel) do
      if buffer.merged then
         local zoomed, ptr_other = buffer.zoomed
         if zoomed then
            ptr_other = w.hdata_pointer(h_buffer, buffer.pointer, "prev_buffer")
            if ptr_other == "" or
               w.hdata_integer(h_buffer, ptr_other, "number") ~= buffer.number then
               ptr_other = w.hdata_pointer(h_buffer, buffer.pointer, "next_buffer")
            end
            w.command(buffer.pointer, "/input zoom_merged_buffer")
         end
         w.buffer_unmerge(buffer.pointer, -1)
         if zoomed and ptr_other ~= "" then
            w.command(ptr_other, "/input zoom_merged_buffer")
         end
      end
   end
   return w.WEECHAT_RC_OK
end

function cmd_jump_mouse(ptr_buffer)
   if ptr_buffer and ptr_buffer ~= "" then
      cmd_selection("clear")
      w.buffer_set(ptr_buffer, "display", "1")
   end
   return w.WEECHAT_RC_OK
end

function cmd_move(t)
   if not t._bar_item_name2 or t._bar_item_name2 ~= script_name then
      return w.WEECHAT_RC_OK
   end
   local target_num = tonumber(t.number2)
   if not target_num or target_num < 1 then
      return w.WEECHAT_RC_OK
   end
   local sel = get_selection()
   local total = #sel
   if total == 0 then
      cmd_selection("add", t.pointer)
      sel = get_selection()
      g.mouse.temp_select = true
      total = #sel
   end

   local line_start
   if total > 1 then
      local last = g.mouse.last_event
      if last then
         line_start = tonumber(last._bar_item_line2)
      end
   end
   if not line_start then
      line_start = tonumber(t._bar_item_line)
   end
   local line_end = tonumber(t._bar_item_line2)
   local dist = line_end - line_start
   if dist == 0 then
      return w.WEECHAT_RC_OK
   end
   local num_end = target_num + total - 1
   local h_buffer = w.hdata_get("buffer")
   local last_buffer = w.hdata_get_list(h_buffer, "last_gui_buffer")
   local last_num = w.hdata_integer(h_buffer, last_buffer, "number")
   if num_end > last_num then
      num_end = last_num
   end
   local p1, p2, p3, n
   if dist < 0 then
      p1, p2, p3, n = 1, total, 1, target_num
   else
      p1, p2, p3, n = total, 1, -1, num_end
   end
   for i = p1, p2, p3 do
      local buffer = sel[i]
      w.buffer_set(buffer.pointer, "number", n)
      n = n + p3
   end
   g.mouse.last_event = t
   return w.WEECHAT_RC_OK
end

function cmd_close()
   local sel = get_selection()
   for _, entry in ipairs(sel) do
      w.buffer_close(entry.pointer)
   end
   cmd_selection("clear")
   return w.WEECHAT_RC_OK
end

function get_related_buffer(dir, index)
   local buffers = g.buffers
   index = index or g.current_index
   if not buffers.list[index].rel or buffers.list[index].rel == "" then
      return
   end
   if (dir == "first" and buffers.list[index].rel == "start") or
      (dir == "last" and buffers.list[index].rel == "end") then
      return
   end
   local target, p
   local forward = { index + 1, buffers.total, 1, "end", "start" }
   local backward = { index - 1, 1, -1, "start", "end" }
   if dir == "next" or dir == "last" then
      p = forward
   else
      p = backward
   end
   for i = p[1], p[2], p[3] do
      local rel = buffers.list[i].rel
      if not rel or rel == "" or rel == p[5] then
         break
      elseif rel == "middle" or rel == p[4] then
         target = i
         if dir == "next" or dir == "prev" then
            break
         end
      end
   end
   if not target then
      if dir == "first" or dir == "last" then
         return
      end
      p = dir == "next" and backward or forward
      for i = p[1], p[2], p[3] do
      local rel = buffers.list[i].rel
         if not rel or rel == "" or rel == p[5] then
            break
         end
         target = i
      end
   end
   return buffers.list[target], target
end

function cmd_jump_related(dir)
   local buffer = get_related_buffer(dir)
   if buffer then
      w.buffer_set(buffer.pointer, "display", "1")
      return w.WEECHAT_RC_OK
   end
end

function cmd_jump_unrelated(dir)
   if dir == "first" or dir == "last" then
      return cmd_jump_normal(dir)
   end
   local buffer, index = get_related_buffer(dir == "next" and "last" or "first")
   if not buffer then
      return cmd_jump_normal(dir)
   end
   if dir == "next" then
      return cmd_jump_normal(index + 1)
   elseif dir == "prev" then
      return cmd_jump_normal(index - 1)
   end
end

function cmd_jump_normal(param)
   local index, buffers = g.current_index, g.buffers
   if type(param) == "number" then
      index = param
   elseif param == "first" then
      index = 1
   elseif param == "last" then
      index = buffers.total
   elseif param == "next" then
      index = index + 1
   elseif param == "prev" then
      index = index - 1
   else
      return w.WEECHAT_RC_ERROR
   end
   if index < 1 then
      index = buffers.total
   elseif index > buffers.total then
      index = 1
   end
   if buffers.list[index] then
      w.buffer_set(buffers.list[index].pointer, "display", "1")
   end
   return w.WEECHAT_RC_OK

end

function cmd_jump(ptr_buffer, param)
   local arg1, arg2 = param:match("^(%S+)%s*(%S*)")
   local dirs = { next = true, prev = true, first = true, last = true }
   if not arg1 or not dirs[arg1] then
      arg1 = tonumber(arg1)
      if not arg1 then
         return w.WEECHAT_RC_ERROR
      end
   end
   if arg2 and (arg2 == "related" or arg2 == "unrelated") then
      local relation = w.config_string(g.options.look.relation)
      if relation ~= "none" then
         if arg2 == "related" then
            return cmd_jump_related(arg1)
         elseif arg2 == "unrelated" then
            return cmd_jump_unrelated(arg1)
         end
      end
   end
   return cmd_jump_normal(arg1)
end

function cmd_run(ptr_buffer, param)
   local sel = get_selection()
   if #sel == 0 then
      table.insert(sel, g.buffers.list[g.current_index])
   end
   for _, buffer in ipairs(sel) do
      local cmd = w.string_eval_expression(
                     param, { buffer = buffer.pointer }, {}, {})
      w.command(buffer.pointer, cmd)
   end
   return w.WEECHAT_RC_OK
end

function command_cb(_, ptr_buffer, param)
   local cmd, param = param:match("^(%S+)%s*(.*)")
   if not cmd then
      return w.WEECHAT_RC_ERROR
   end
   local func
   if cmd == "jump" then
      func = cmd_jump
   elseif cmd == "run" then
      func = cmd_run
   else
      print("Error: Unknown command: ${cmd}", { cmd = cmd })
      return w.WEECHAT_RC_ERROR
   end
   return func(ptr_buffer, param)
end

function item_cb()
   return generate_output()
end

function unload_cb()
   for key, _ in pairs(g.mouse.keys) do
      w.key_unbind("mouse", key)
   end
   w.config_write(g.config_file)
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

function module_exists(name)
   for _, searcher in ipairs(package.searchers or package.loaders) do
      local loader = searcher(name)
      if type(loader) == "function" then
         package.preload[name] = loader
         return true
      end
   end
end

function check_utf8_support()
   if not utf8 then
      for _, name in ipairs({"lua-utf8", "utf8"}) do
         if module_exists(name) then
            utf8 = require(name)
            break
         end
      end
   end
   if not utf8 then
      print("Warning: Your version of Lua is missing UTF8 support.")
      return
   end
end

function string_limit(text, limit, char_more)
   limit = tonumber(limit)
   if not limit or limit < 1 then
      return text
   end
   local nbytes, swidth = #text, w.strlen_screen(text)
   if swidth <= limit then
      return text
   end
   if nbytes == swidth or not utf8 then
      text = text:sub(1, limit)
      if #text < nbytes then
         text = text..char_more
      end
      return text
   else
      local text2 = ""
      for _, codepoint in utf8.codes(text) do
         local char = utf8.char(codepoint)
         if w.strlen_screen(text2..char) > limit then
            text2 = text2..char_more
            break
         else
            text2 = text2..char
         end
      end
      return text2
   end
end

function print(fmt, var)
   w.print("", script_name.."\t"..
               w.string_eval_expression(fmt, {}, var or {}, {}))
end

main()

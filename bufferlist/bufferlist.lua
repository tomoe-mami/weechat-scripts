w, script_name = weechat, "bufferlist"

g = {
   -- we really should use our own config file
   defaults = {
      format = {
         type = "string",
         value = "number ,rel, short_name,(lag), (hotlist)",
         desc = [[
Format of buffer entry. The syntax is a bit similar with bar items except a
comma won't add extra space and '+' is used to apply color of item to the
characters around it. Available item names are: number, short_name, name,
full_name, hotlist, nick_prefix, lag, rel, index. You can also insert buffer's
local variable by prefixing the name with '%' (eg: %type will insert
the value of local variable "type")]]
      },
      bar_name = {
         type = "string",
         value = script_name,
         desc = "The name of bar that will have autoscroll feature"
      },
      always_show_number = {
         type = "boolean",
         value = "off",
         desc = "Always show buffer number"
      },
      show_hidden_buffers = {
         type = "boolean",
         value = "on",
         desc = "Show hidden buffers"
      },
      prefix_not_joined = {
         type = "string",
         value = " ",
         desc = [[Text that will be shown in item `nick_prefix` when you're not
joined the channel]]
      },
      enable_lag_indicator = {
         type = "boolean",
         value = "on",
         desc = [[If enabled, you can use item `lag` in format option to show
lag indicator]],
      },
      max_name_length = {
         type = "number",
         value = "0",
         desc = "Maximum length of buffer name"
      },
      align_number = {
         type = "string",
         value = "right",
         choices = { left = true, right = true, none = true },
         desc = "Align numbers and indexes"
      },
      relation = {
         type = "string",
         value = "merged",
         choices = { merged = true, same_server = true, none = true },
         desc = [[Relation mode between buffers (merged = merged buffers,
same_server = buffers within the same server, none = no relation).]],
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
      char_more = {
         type = "string",
         value = "+",
         desc = "Characters that will be appended to an item when it's truncated"
      },
      char_selection = {
         type = "string",
         value = " ",
         desc = "Character that will be used for selection marker."
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
      color_selected = {
         type = "color",
         value = "emphasis",
         desc = "Color of selected buffer"
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
      },
      color_prefix_not_joined = {
         type = "color",
         value = "red",
         desc = "Color for option prefix_not_joined"
      },
      color_delim = {
         type = "color",
         value = "bar_delim",
         desc = "Color for delimiter"
      },
      color_lag = {
         type = "color",
         value = "default",
         desc = "Color for lag indicator"
      }
   },
   config = {},
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
         print("Error: This script requires WeeChat >= 1.0")
         w.command("", "/wait 3ms /lua unload "..script_name)
         return
      end

      check_utf8_support()
      config_init()
      bar_init()
      w.bar_item_new(script_name, "item_cb", "")
      update_hotlist()
      rebuild_cb(nil, "script_init", w.current_buffer())
      register_hooks()
      mouse_init()
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

   w.hook_config("plugins.var.lua."..script_name..".*", "config_cb", "")
end

function lag_hooks()
   local conf, hooks = g.config, g.hooks
   if not conf.enable_lag_indicator then
      if hooks.lag then
         for server, timers in pairs(hooks.lag) do
            for name, ptr in pairs(timers) do
               w.unhook(ptr)
            end
         end
         hooks.lag = nil
      end
      if hooks.irc_connected then
         w.unhook(hooks.irc_connected)
         hooks.irc_connected = nil
      end
      return
   end
   if not hooks.lag then
      hooks.lag = {}
   end
   local min_show = w.config_integer(w.config_get("irc.network.lag_min_show"))
   local h_server = w.hdata_get("irc_server")
   local ptr_server = w.hdata_get_list(h_server, "irc_servers")
   while ptr_server ~= "" do
      if w.hdata_integer(h_server, ptr_server, "is_connected") == 1 then
         local ptr_buffer = w.hdata_pointer(h_server, ptr_server, "buffer")
         local buffer = get_buffer_by_pointer(ptr_buffer)
         if buffer then
            lag_init_buffer(h_server, ptr_server, buffer, min_show)
         end
      end
      ptr_server = w.hdata_pointer(h_server, ptr_server, "next_server")
   end
   hooks.irc_connected = w.hook_signal("irc_server_connected", "irc_connected_cb", "")
end

function lag_init_buffer(h_server, ptr_server, buffer, min_show)
   local lag = w.hdata_integer(h_server, ptr_server, "lag")
   buffer.lag = lag >= min_show and lag or nil
   lag_set_timer(
      "check",
      w.hdata_string(h_server, ptr_server, "name"),
      w.hdata_time(h_server, ptr_server, "lag_next_check"))
end

function irc_connected_cb(_, _, server_name)
   local ptr_server, h_server, buffer = get_irc_server(server_name)
   if ptr_server ~= "" and buffer then
      local min_show = w.config_integer(w.config_get("irc.network.lag_min_show"))
      lag_init_buffer(h_server, ptr_server, buffer, min_show)
   end
   return w.WEECHAT_RC_OK
end

function lag_set_timer(timer_type, server_name, t, callback)
   local hooks = g.hooks
   if not hooks.lag then
      hooks.lag = {}
   end
   if not hooks.lag[server_name] then
      hooks.lag[server_name] = {}
   end
   if timer_type == "check" then
      t = t - os.time()
   elseif timer_type == "refresh" then
      t = w.config_integer(w.config_get("irc.network.lag_refresh_interval"))
   end

   hooks.lag[server_name][timer_type] = w.hook_timer(t * 1000, 0, 1,
                                                     callback or "lag_timer_cb",
                                                     timer_type..","..server_name)
   return hooks.lag[server_name][timer_type]
end

function lag_update_data(server_name)
   local ptr_server, h_server, buffer = get_irc_server(server_name)
   if ptr_server ~= "" and buffer then
      local min_show = w.config_integer(w.config_get("irc.network.lag_min_show"))
      if w.hdata_integer(h_server, ptr_server, "is_connected") == 0 then
         buffer.lag = nil
         return buffer, os.time() - 10, false
      else
         local lag = w.hdata_integer(h_server, ptr_server, "lag")
         buffer.lag = lag >= min_show and lag or nil
         return buffer, w.hdata_time(h_server, ptr_server, "lag_next_check"), true
      end
   end
   return false
end


function lag_timer_cb(param)
   local timer_type, server_name = param:match("^([^,]+),(.+)$")
   if not timer_type or not server_name then
      return w.WEECHAT_RC_OK
   end
   local buffer, next_check, connected = lag_update_data(server_name)
   if buffer then
      local cur_time = os.time()
      local min_show = w.config_integer(w.config_get("irc.network.lag_min_show"))
      if buffer.lag and buffer.lag >= min_show then
         lag_set_timer("refresh", server_name)
      elseif connected then
         if next_check <= cur_time then
            local interval = w.config_integer(w.config_get("irc.network.lag_check"))
            if interval > 0 then
               next_check = cur_time + interval
            end
         end
         if next_check > cur_time then
            lag_set_timer("check", server_name, next_check)
         end
      end
      g.hooks.lag[server_name][timer_type] = nil
      w.bar_item_update(script_name)
   end
   return w.WEECHAT_RC_OK
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
end

function config_cb(param, opt_name, opt_value)
   opt_name = opt_name:gsub("^plugins%.var%.lua%."..script_name..".", "")
   local info = g.defaults[opt_name]
   if info then
      if info.type == "boolean" then
         opt_value = w.config_string_to_boolean(opt_value) == 1
      elseif info.type == "number" then
         opt_value = tonumber(opt_value)
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
      elseif opt_name == "enable_lag_indicator" then
         lag_hooks()
      elseif opt_name == "relation" or
         opt_name == "show_hidden_buffers" or
         opt_name == "max_name_length" or
         opt_name == "prefix_not_joined" or
         opt_name == "color_prefix_not_joined" then
         return rebuild_cb(nil, "config_changed")
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
            return cmd_switch(t.pointer)
         end
      elseif t.key == "ctrl-button2" then
         return cmd_selection("clear")
      elseif t.key == "button3" then
         return cmd_merge()
      elseif t.key == "ctrl-button3" then
         return cmd_unmerge()
      elseif t.key:match("^ctrl%-button1") then
         if t._bar_item_name2 ~= script_name then
            cmd_close()
         end
         if g.mouse.temp_select then
            g.mouse.temp_select = nil
            cmd_selection("clear")
         end
         if g.mouse.last_event then
            g.mouse.last_event = nil
         end
      end
   end
   return w.WEECHAT_RC_OK
end

function rebuild_cb(_, signal_name, ptr_buffer)
   g.buffers, g.max_num_length = get_buffer_list()
   w.bar_item_update(script_name)
   if signal_name == "script_init" then
      w.hook_timer(50, 0, 1, "autoscroll", "now")
   else
      autoscroll()
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
   for i = server_index, #buffers.list do
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
   local conf = g.config
   local buffer, index = get_buffer_by_pointer(ptr_buffer)
   if not buffer then
      return w.WEECHAT_RC_OK
   end
   local h_buffer = w.hdata_get("buffer")
   local new_var = w.hdata_hashtable(h_buffer, ptr_buffer, "local_variables")
   if conf.relation == "same_server" and buffer.var.server ~= new_var.server then
      return rebuild_cb(nil, "server_changed", ptr_buffer)
   end
   if buffer.var.type ~= new_var.type and
      new_var.type == "channel" and
      not buffer.nick_prefix then
      buffer.nick_prefix = g.config.prefix_not_joined
      buffer.nick_prefix_color = g.config.color_prefix_not_joined
   end
   buffer.var = new_var
   w.bar_item_update(script_name)
   return w.WEECHAT_RC_OK
end

function renamed_cb(_, _, ptr_buffer)
   local max_length, char_more = g.config.max_name_length, g.config.char_more
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

function redraw_cb(_, signal_name, ptr)
   w.bar_item_update(script_name)
   autoscroll("now")
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
         buffer.nick_prefix = g.config.prefix_not_joined
         buffer.nick_prefix_color = g.config.color_prefix_not_joined
      else
         buffer.nick_prefix = w.nicklist_nick_get_string(ptr_buffer, ptr_nick, "prefix")
         buffer.nick_prefix_color = w.nicklist_nick_get_string(ptr_buffer, ptr_nick, "prefix_color")
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
   local entries, groups, conf = {}, {}, g.config
   local pointers = {}
   local index, prev_index, max_num_len = 0, 0, 0
   local current_buffer = w.current_buffer()
   local h_buffer, h_nick = w.hdata_get("buffer"), w.hdata_get("nick")
   local ptr_buffer = w.hdata_get_list(h_buffer, "gui_buffers")
   local names = { "name", "short_name", "full_name" }
   local num_list = {}
   local prev_number = 0
   while ptr_buffer ~= "" do
      local is_hidden = w.hdata_integer(h_buffer, ptr_buffer, "hidden") == 1
      if not is_hidden or conf.show_hidden_buffers then
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

         local num_len = #tostring(t.number)
         if num_len > max_num_len then
            max_num_len = num_len
         end

         prev_index, index = index, index + 1
         pointers[ptr_buffer] = index
         if t.current then
            g.current_index = index
         end

         if index > 1 then
            if t.number == prev_number then
               if not entries[prev_index].merged then
                  entries[prev_index].merged = true
                  if conf.relation == "merged" then
                     entries[prev_index].rel = "start"
                  end
               end
               t.merged = true
               if conf.relation == "merged" then
                  t.rel = "middle"
               end
            elseif entries[prev_index].merged and conf.relation == "merged" then
               entries[prev_index].rel = "end"
            end
         end

         prev_number = t.number

         for _, k in pairs(names) do
            t[k] = w.string_remove_color(w.hdata_string(h_buffer, ptr_buffer, k), "")
            if conf.max_name_length > 0 then
               t[k] = string_limit(t[k], conf.max_name_length, conf.char_more)
            end
         end

         if t.var.type == "channel" then
            local nicks = w.hdata_integer(h_buffer, ptr_buffer, "nicklist_nicks_count")
            if nicks > 0 and t.var.nick and t.var.nick ~= "" then
               local ptr_nick = w.nicklist_search_nick(ptr_buffer, "", t.var.nick)
               if ptr_nick ~= "" then
                  t.nick_prefix = w.hdata_string(h_nick, ptr_nick, "prefix")
                  t.nick_prefix_color = w.hdata_string(h_nick, ptr_nick, "prefix_color")
               end
            else
               t.nick_prefix = conf.prefix_not_joined
               t.nick_prefix_color = conf.color_prefix_not_joined
            end
         end

         if conf.relation == "same_server" and
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

   if conf.relation == "same_server" then
      entries, pointers = group_by_server(entries, groups, pointers)
   end

   return { list = entries, pointers = pointers }, max_num_len
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
   if not buffers.list then
      return ""
   end
   local total_entries = #buffers.list
   if total_entries == 0 then
      return ""
   end
   local hl, conf, c, sel = g.hotlist, g.config, g.colors, g.selection
   local num_fmt, idx_fmt
   if conf.align_number ~= "none" then
      local minus = conf.align_number == "left" and "-" or ""
      num_fmt = "%"..minus..g.max_num_length.."s"
      idx_fmt = "%"..minus..#tostring(total_entries).."s"
   end
   local entries, last_num = {}, 0
   local rels = {
      start = conf.rel_char_start,
      middle = conf.rel_char_middle,
      ["end"] = conf.rel_char_end,
      none = conf.rel_char_none
   }
   local sel_phold
   if conf.char_selection ~= "" then
      sel_phold = string.rep(" ", w.strlen_screen(conf.char_selection))
   end
   local prev_number = 0
   for i, b in ipairs(buffers.list) do
      local items = {
         name = b.name,
         short_name = b.short_name,
         full_name = b.full_name
      }
      local colors = {
         delim = c.color_delim,
         rel = c.color_rel,
         hotlist = c.color_delim,
         base = c.color_normal
      }
      if b.current then
         colors.base = c.color_current
      elseif sel[b.pointer] and not sel_phold then
         colors.base = c.color_selected
      elseif b.displayed and b.active > 0 then
         colors.base = c.color_other_win
      elseif b.zoomed and b.active == 0 then
         colors.name = c.color_out_of_zoom
      elseif b.hidden then
         colors.name = c.color_hidden
      end

      items.rel = rels[b.rel] or rels.none
      items.number = b.number
      if not conf.always_show_number and prev_number == b.number then
         items.number = ""
      end
      prev_number = b.number
      items.index = idx_fmt and idx_fmt:format(i) or i
      colors.index, colors.number = c.color_number, c.color_number
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
                  color_highest_lev = c["color_hotlist_"..lev]
               end
               table.insert(h, c["color_hotlist_"..lev]..hotlist[lev])
            end
         end
         items.hotlist = table.concat(h, c.color_delim..",")
      end

      if not colors.name then
         colors.name = color_highest_lev or colors.base
      end
      colors.hotlist = color_highest_lev
      colors.short_name, colors.full_name = colors.name, colors.name
      if items.short_name == "" then
         items.short_name = items.name
      end

      if b.nick_prefix then
         items.nick_prefix = b.nick_prefix
         colors.nick_prefix = w.color(b.nick_prefix_color)
      else
         items.nick_prefix, colors.nick_prefix = " ", colors.base
      end

      if b.lag then
         items.lag = string.format("%.3g", b.lag / 1000)
         colors.lag = c.color_lag
      end

      if sel[b.pointer] then
         items.sel = conf.char_selection
         colors.sel = c.color_selected
      elseif sel_phold then
         items.sel = sel_phold
      end

      local entry = replace_format(conf.format, items, b.var, colors, conf.char_more)
      buffers.list[i].length = w.strlen_screen(entry)
      if b.current then
         entry = c.color_current..strip_bg_color(entry)
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
end

function autoscroll(mode)
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
   for _, buffer in ipairs(sel) do
      w.buffer_unmerge(buffer.pointer, -1)
   end
   return w.WEECHAT_RC_OK
end

function cmd_switch(ptr_buffer)
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

function cmd_set_property(name, value)
   local sl = get_selection()
   for _, entry in ipairs(sel) do
      w.buffer_set(entry.pointer, name, value)
   end
   return w.WEECHAT_RC_OK
end

function item_cb()
   return generate_output()
end

function unload_cb()
   for key, _ in pairs(g.mouse.keys) do
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

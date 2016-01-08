w, table.unpack, script_name = weechat, table.unpack or unpack, "active_nicklist"
g = {
   config = {},
   defaults = {
      delay = {
         type = "integer",
         min = 0,
         max = 10080,
         value = "5", -- default value will be replaced by irc.look.smart_filter_delay
         description = [[Delay before hiding nick again (in minutes,
         values: 0..10080). Set to 0 to disable (once active, nick will stay visible).]]
      },
      ignore_filtered = {
         type = "boolean",
         value = "on",
         description = "Ignore filtered line."
      },
      conditions = {
         type = "string",
         value = "${buffer.nicklist}",
         description = [[Only watch buffers that matched these conditions.
         See /help eval for syntax. Example: ${buffer.nicklist_nicks_count} > 20]]
      },
      tags = {
         type = "string",
         value = "nick_*+log1",
         description = [[Only count activity from messages with these tags.
         See https://weechat.org/doc/api#_hook_print for syntax of tags]]
      }
   },
   hooks = {},
   buffers = {}
}

function main()
   local reg_ok = w.register(
      script_name,
      "singalaut <https://github.com/tomoe-mami>",
      "0.1",
      "WTFPL",
      "Show only active users in nicklist",
      "unload_cb", "")

   if reg_ok then
      local wee_ver = tonumber(w.info_get("version_number", "") or 0)
      if wee_ver < 0x01000000 then
         w.print("", w.prefix("error").."Upgrade your WeeChat, dumbass!")
         return
      end

      init_config()
      hide_all_nicks()
      init_hooks()
   end
end

function empty(v)
   return not v or v == ""
end

function iter_buffers(name)
   local list = w.infolist_get("buffer", "", name or "")
   if not empty(list) then
      return function ()
         if w.infolist_next(list) ~= 1 then
            w.infolist_free(list)
         else
            return w.infolist_string(list, "full_name"),
                   w.infolist_pointer(list, "pointer")
         end
      end
   end
end

function iter_nicklist(buffer)
   local list = w.infolist_get("nicklist", buffer, "")
   if not empty(list) then
      return function ()
         local t
         while t ~= "nick" do
            if w.infolist_next(list) ~= 1 then
               w.infolist_free(list)
               return
            end
            t = w.infolist_string(list, "type")
         end
         local nick_name = w.infolist_string(list, "name")
         return nick_name, w.nicklist_search_nick(buffer, "", nick_name)
      end
   end
end

function get_valid_option_value(value, default)
   if default.callback and type(default.callback) == "function" then
      return default.callback(value)
   else
      if default.type == "integer" then
         value = math.floor(tonumber(value) or 0)
         if default.min and value < default.min then
            value = default.min
         end
         if default.max and value > default.max then
            value = default.max
         end
      elseif default.type == "boolean" then
         value = w.config_string_to_boolean(value) == 1
      elseif default.type == "string" and default.choices and not default.choices[value] then
         value = default.value
      end
      return value
   end
end

function init_config()
   local conf = {}
   g.defaults.delay.value = w.config_integer(w.config_get("irc.look.smart_filter_delay"))
   for name, info in pairs(g.defaults) do
      local value
      if w.config_is_set_plugin(name) == 0 then
         value = info.value
         w.config_set_plugin(name, value)
         w.config_set_desc_plugin(name, (info.description:gsub("%s+", " ")))
      else
         value = w.config_get_plugin(name)
      end
      conf[name] = get_valid_option_value(value, info)
   end
   g.config = conf
end

function config_cb(_, opt_name, opt_value)
   local prefix = "plugins.var.lua."..script_name.."."
   local name = opt_name:sub(#prefix + 1)
   if name and g.defaults[name] then
      g.config[name] = get_valid_option_value(opt_value, g.defaults[name])
      if name == "delay" then
         hook_timer()
      elseif name == "tags" then
         hook_print()
      elseif name == "conditions" then
         recheck_buffer_conditions()
      end
   end
   return w.WEECHAT_RC_OK
end

function pause_flag(buffer, flag)
   if flag == nil then
      return w.buffer_get_string(buffer, "localvar_"..script_name.."_paused") == "1"
   else
      local action = flag and "set" or "del"
      w.buffer_set(buffer, "localvar_"..action.."_"..script_name.."_paused", "1")
   end
end

function check_buffer_conditions(buffer, ignore_pause_flag)
   if not ignore_pause_flag and pause_flag(buffer) then
      return false
   end
   if not empty(g.config.conditions) then
      local result = w.string_eval_expression(
         g.config.conditions,
         { buffer = buffer },
         {},
         { type = "condition" })
      return result == "1"
   end
   return true
end

function recheck_buffer_conditions()
   for buf_name, buf_ptr in iter_buffers() do
      local v
      if not check_buffer_conditions(buf_ptr, true) then
         v = "1"
         if g.buffers[buf_name] then
            g.buffers[buf_name] = nil
         end
      elseif not g.buffers[buf_name] then
         v = "0"
      end
      if v ~= nil then
         for nick_name, nick_ptr in iter_nicklist(buf_ptr) do
            w.nicklist_nick_set(buf_ptr, nick_ptr, "visible", v)
         end
      end
   end
end

function hide_all_nicks(flag)
   flag = flag == false and "1" or "0"
   for buf_name, buf_ptr in iter_buffers() do
      pause_flag(buf_ptr, false)
      local total_nicks = w.buffer_get_integer(buf_ptr, "nicklist_nicks_count")
      if total_nicks > 0 and check_buffer_conditions(buf_ptr, true) then
         for nick_name, nick_ptr in iter_nicklist(buf_ptr) do
            w.nicklist_nick_set(buf_ptr, nick_ptr, "visible", flag)
         end
      end
   end
end

function show_nick(buffer, nick_name, timestamp)
   local buf_name = w.buffer_get_string(buffer, "full_name")
   if not g.buffers[buf_name] then
      g.buffers[buf_name] = {}
   end
   local ptr = w.nicklist_search_nick(buffer, "", nick_name)
   if not empty(ptr) then
      g.buffers[buf_name][nick_name] = timestamp
      if w.nicklist_nick_get_integer(buffer, ptr, "visible") == 0 then
         w.nicklist_nick_set(buffer, ptr, "visible", "1")
      end
   end
end

function print_cb(_, buffer, time, tags, displayed)
   if g.config.ignore_filtered and displayed == 0 then
      return w.WEECHAT_RC_OK
   end
   local nick = string.match(","..tags..",", ",nick_([^,]-),")
   if empty(nick) then
      return w.WEECHAT_RC_OK
   end
   if check_buffer_conditions(buffer) then
      show_nick(buffer, nick, tonumber(time))
   end
   return w.WEECHAT_RC_OK
end

function nick_added_cb(_, _, param)
   local buffer, nick_name = param:match("^([^,]-),(.+)$")
   if check_buffer_conditions(buffer) then
      local ptr = w.nicklist_search_nick(buffer, "", nick_name)
      if not empty(ptr) then
         w.nicklist_nick_set(buffer, ptr, "visible", "0")
      end
   end
   return w.WEECHAT_RC_OK
end

function nick_removing_cb(_, _, param)
   local buffer, nick_name = param:match("^([^,]-),(.+)$")
   if check_buffer_conditions(buffer) then
      local buf_name = w.buffer_get_string(buffer, "full_name")
      if g.buffers[buf_name] and g.buffers[buf_name][nick_name] then
         g.buffers[buf_name][nick_name] = nil
      end
      -- weechat doesn't decrease nicklist_visible_count when an invisible nick
      -- is removed. so we have to make sure it's visible first
      local ptr = w.nicklist_search_nick(buffer, "", nick_name)
      if not empty(ptr) then
         w.nicklist_nick_set(buffer, ptr, "visible", "1")
      end
   end
   return w.WEECHAT_RC_OK
end

function buffer_closing_cb(_, _, buffer)
   if check_buffer_conditions(buffer) then
      local buf_name = w.buffer_get_string(buffer, "full_name")
      if g.buffers[buf_name] then
         g.buffers[buf_name] = nil
      end
   end
   return w.WEECHAT_RC_OK
end

function names_received_cb(_, modifier, server, msg)
   local info = w.info_get_hashtable("irc_message_parse", { message = msg })
   if info and type(info) == "table" and info.text then
      local channel = info.text:match("^%S+ (%S+)")
      if channel then
         local buf_ptr = w.info_get("irc_buffer", server..","..channel)
         if not empty(buf_ptr) and check_buffer_conditions(buf_ptr) then
            pause_flag(buf_ptr, true)
            for nick_name, nick_ptr in iter_nicklist(buf_ptr) do
               w.nicklist_nick_set(buf_ptr, nick_ptr, "visible", "1")
            end
         end
      end
   end
   return msg
end

function names_end_cb(_, signal, msg)
   local server = signal:match("^([^,]+)")
   if server then
      local info = w.info_get_hashtable("irc_message_parse", { message = msg })
      if info and type(info) == "table" and info.channel then
         local buf_ptr = w.info_get("irc_buffer", server..","..info.channel)
         if not empty(buf_ptr) and check_buffer_conditions(buf_ptr, true) then
            local active_nicks = g.buffers[w.buffer_get_string(buf_ptr, "full_name")]
            for nick_name, nick_ptr in iter_nicklist(buf_ptr) do
               if not active_nicks or not active_nicks[nick_name] then
                  w.nicklist_nick_set(buf_ptr, nick_ptr, "visible", "0")
               end
            end
            pause_flag(buf_ptr, false)
         end
      end
   end
   return w.WEECHAT_RC_OK
end

function timer_cb()
   local start_time = os.time() - (g.config.delay * 60)
   local buffers = g.buffers
   for buf_name, nicks in pairs(buffers) do
      local buf_ptr = w.buffer_search("==", buf_name)
      if empty(buf_ptr) then
         g.buffers[buf_name] = nil
      else
         for nick_name, timestamp in pairs(nicks) do
            if timestamp < start_time then
               local nick_ptr = w.nicklist_search_nick(buf_ptr, "", nick_name)
               if not empty(nick_ptr) then
                  w.nicklist_nick_set(buf_ptr, nick_ptr, "visible", "0")
               end
               g.buffers[buf_name][nick_name] = nil
            end
         end
      end
   end
end

function hook_timer()
   if g.hooks.timer then
      w.unhook(g.hooks.timer)
   end
   if g.config.delay > 0 then
      g.hooks.timer = w.hook_timer(60000, 0, 0, "timer_cb", "")
   else
      g.hooks.timer = nil
   end
end

function hook_print()
   if g.hooks.print then
      w.unhook(g.hooks.print)
   end
   g.hooks.print = w.hook_print("", g.config.tags, "", 0, "print_cb", "")
end

function init_hooks()
   w.hook_config("plugins.var.lua."..script_name..".*", "config_cb", "")
   w.hook_signal("buffer_closing", "buffer_closing_cb", "")
   w.hook_signal("nicklist_nick_added", "nick_added_cb", "")
   w.hook_signal("nicklist_nick_removing", "nick_removing_cb", "")
   w.hook_modifier("irc_in2_353", "names_received_cb", "")
   w.hook_signal("*,irc_in_366", "names_end_cb", "")
   hook_print()
   hook_timer()
end

function unload_cb()
   hide_all_nicks(false)
end

main()

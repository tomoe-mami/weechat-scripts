w, script_name = weechat, "weekey"

g = {
   recent_combo = "",
   recent_command = "",
   recent_context = "",
   hook = {},
   context = {
      default = "gui_keys",
      search = "gui_keys_search",
      cursor = "gui_keys_cursor"
   },
   config = {},
   binding = {},
   default = {
      local_bindings = { "off", "Monitor per buffer key bindings set via local variable key_bind_*" },
      mod_separator = { "-", "Separator between modifier(s)" },
      key_separator = { " ", "Separator between keys" },
      duration = { 800, "Duration for showing key/command (in milliseconds)" },
      color_context = { "", "Color of context. Set to empty string to use the color of command/local command" },
      color_command = { "default", "Color of command" },
      color_local_command = { "cyan", "Color for local command" },
      color_key = { "yellow", "Color of key" },
      color_separator = { "bar_delim", "Color of separator" }
   },
   item = { "combo", "command", "context" },
   names = {
      shift = "Shift",     ctrl = "Ctrl",
      meta = "Meta",       meta2 = "Meta2",
      up = "Up",           left = "Left",
      down = "Down",       right = "Right",
      tab = "Tab",         space = "Space",
      backspace = "Back",  enter = "Enter",
      insert = "Ins",      delete = "Del",
      home = "Home",       ["end"] = "End",
      pageup = "PgUp",     pagedown = "PgDown",
      f1 = "F1",           f2 = "F2",
      f3 = "F3",           f4 = "F4",
      f5 = "F5",           f6 = "F6",
      f7 = "F7",           f8 = "F8",
      f9 = "F9",           f10 = "F10",
      f11 = "F11",         f12 = "F12",
   }
}

function main()
   local reg_ok = w.register(
      script_name, "singalaut <https://github.com/tomoe-mami>", "0.1", "WTFPL",
      "Display recently pressed key combo in bar items", "", "")

   if reg_ok then
      local wee_ver = tonumber(w.info_get("version_number", "") or 0)
      if wee_ver < 0x01000000 then
         w.print("", w.prefix("error")..script_name..": This script requires WeeChat v1.0 or newer.")
         w.command("", "/wait 1ms /lua unload "..script_name)
         return
      end

      init_config()
      collect_bindings()
      setup_key_map()
      setup_key_map = nil
      for _, item in ipairs(g.item) do
         w.bar_item_new(script_name.."_"..item, "item_"..item.."_cb", "")
      end
      for ctx, _ in pairs(g.context) do
         w.hook_signal("9000|key_combo_"..ctx, "key_combo_cb", ctx)
      end
      -- w.hook_focus("chat", "focus_cb", "")
      w.hook_signal("key_bind", "key_bind_cb", "")
      w.hook_signal("key_unbind", "key_bind_cb", "")
      w.hook_config("plugins.var.lua."..script_name..".*", "config_cb", "")

      w.hook_command(
         script_name,
         string.format([[
The command /%s only dumps the list of known key combos (for debugging).

If you need help on how to configure this script please see the README at
https://github.com/tomoe-mami/weechat-scripts/tree/master/%s]], script_name, script_name),
         "", "", "", "command_cb", "")
   end
end

function collect_bindings()
   local binds = g.binding
   local h_key = w.hdata_get("key")
   for ctx, list_name in pairs(g.context) do
      binds[ctx] = {}
      local key = w.hdata_get_list(h_key, list_name)
      while key and key ~= "" do
         local key_code = w.hdata_string(h_key, key, "key")
         local command = w.hdata_string(h_key, key, "command")
         binds[ctx][key_code] = command
         key = w.hdata_pointer(h_key, key, "next_key")
      end
   end
end

function init_config()
   local conf = {}
   for k, v in pairs(g.default) do
      if w.config_is_set_plugin(k) ~= 1 then
         w.config_set_plugin(k, v[1])
         w.config_set_desc_plugin(k, v[2])
         conf[k] = v[1]
      else
         conf[k] = w.config_get_plugin(k)
      end
   end
   g.config = conf
   validate_duration()
   check_local_bindings()
end

function validate_duration()
   local duration = tonumber(g.config.duration) or -1
   if duration < 0 then
      duration = g.default.duration[1]
   end
   g.config.duration = duration
end

function check_local_bindings()
   local opt = w.config_string_to_boolean(g.config.local_bindings or "off")
   if opt == 0 then
      g.binding.buffer = nil
      g.config.local_bindings = false
      if g.hook.buffer_closed then
         w.unhook(g.hook.buffer_closed)
         g.hook.buffer_closed = nil
      end
      if g.hook.buffer_switch then
         w.unhook(g.hook.buffer_switch)
         g.hook.buffer_switch = nil
      end
   else
      g.binding.buffer = {}
      g.config.local_bindings = true
      collect_local_bindings(w.current_buffer())
      if not g.hook.buffer_closed then
         g.hook.buffer_closed = w.hook_signal("buffer_closed", "buffer_closed_cb", "")
      end
      if not g.hook.buffer_switch then
         g.hook.buffer_switch = w.hook_signal("buffer_switch", "buffer_switch_cb", "")
      end
   end
end

function collect_local_bindings(buf_ptr)
   local h_buffer, h_key = w.hdata_get("buffer")
   if w.hdata_integer(h_buffer, buf_ptr, "keys_count") < 1 then
      g.binding.buffer[buf_ptr] = nil
      return
   end
   local h_key, keys = w.hdata_get("key"), {}
   local key = w.hdata_pointer(h_buffer, buf_ptr, "keys")
   while key ~= "" do
      local code = w.hdata_string(h_key, key, "key")
      keys[code] = w.hdata_string(h_key, key, "command")
      key = w.hdata_pointer(h_key, key, "next_key")
   end
   g.binding.buffer[buf_ptr] = keys
end

function item_combo_cb()
   return g.recent_combo
end

function item_command_cb()
   return g.recent_command
end

function item_context_cb()
   return g.recent_context
end

function update_items()
   for _, item in ipairs(g.item) do
      w.bar_item_update(script_name.."_"..item)
   end
end

function key_combo_cb(ctx, _, signal_data)
   local buf_ptr = w.current_buffer()
   if g.hook.item_timer then
      w.unhook(g.hook.item_timer)
      g.hook.item_timer = nil
   end
   local found_bind, found_bind_ctx = get_binding(ctx, signal_data, buf_ptr)
   update_recent_combo(signal_data, found_bind, found_bind_ctx)
   update_recent_command(found_bind, found_bind_ctx)
   if g.config.duration > 0 then
      g.hook.item_timer = w.hook_timer(g.config.duration, 0, 1, "item_timer_cb", "")
   end
   update_items()
   return w.WEECHAT_RC_OK
end

function get_binding(context, key, buf_ptr)
   local cmd, ctx
   if g.config.local_bindings and
      buf_ptr and
      buf_ptr ~= "" and
      g.binding.buffer[buf_ptr] and
      g.binding.buffer[buf_ptr][key] then
      cmd, ctx = g.binding.buffer[buf_ptr][key], "local"
   elseif g.binding[context] and g.binding[context][key] then
      cmd, ctx = g.binding[context][key], context
   end
   if cmd == "" then
      cmd, ctx = nil, nil
   end
   return cmd, ctx
end

function update_recent_command(cmd, ctx)
   if cmd and cmd ~= "" then
      local conf, color_cmd, color_ctx = g.config
      if ctx == "local" then
         color_cmd = w.color(conf.color_local_command)
      else
         color_cmd = w.color(conf.color_command)
      end
      if conf.color_context == "" then
         color_ctx = color_cmd
      else
         color_ctx = w.color(conf.color_context)
      end
      g.recent_command = color_cmd..cmd
      g.recent_context = color_ctx..ctx
   else
      g.recent_command = ""
      g.recent_context = ""
   end
end

function update_recent_combo(signal_data, found_bind, ctx)
   local conf = g.config
   local color_key = w.color(conf.color_key)

   if signal_data:sub(1, 1) ~= "\001" then
      if not found_bind then
         g.recent_combo = ""
      else
         g.recent_combo = color_key..signal_data
      end
      return
   end

   local names, keys, overrides = g.names, g.keys, g.overrides
   local combo, i, partial = {}, 1, false
   local color_separator = w.color(conf.color_separator)

   for ch in signal_data:gmatch("(\001[^\001]*)") do
      local seq = {}
      if partial then
         i = i - 1
         table.insert(seq, combo[i])
      end
      if overrides[ch] then
         table.insert(seq, overrides[ch])
         partial = false
      elseif keys[ch] then
         if type(keys[ch]) == "table" then
            for _, k in ipairs(keys[ch]) do
               table.insert(seq, k)
            end
         else
            table.insert(seq, keys[ch])
         end
         partial = false
      else
         local brackets, str = ch:match("^\001(%[?%[?)(.*)$")
         if brackets == "[" then
            table.insert(seq, names.meta)
         elseif brackets == "[[" then
            table.insert(seq, names.meta2)
         elseif brackets == "" then
            table.insert(seq, names.ctrl)
         end
         if str ~= "" then
            table.insert(seq, str)
            partial = false
         else
            partial = true
         end
      end
      combo[i] = color_key..table.concat(seq, color_separator..conf.mod_separator..color_key)
      i = i + 1
   end
   if #combo == 0 then
      g.recent_combo = ""
   else
      g.recent_combo = table.concat(combo, color_separator..conf.key_separator)
   end
end

function item_timer_cb()
   g.hook.item_timer = nil
   g.recent_combo = ""
   g.recent_command = ""
   g.recent_context = ""
   update_items()
   return w.WEECHAT_RC_OK
end

function focus_cb(_, info)
   local binds, found_key, found_cmd, test_key = g.binding.cursor
   if info._buffer_full_name then
      test_key = string.format("@chat(%s):%s", cursor_key)
      if binds[test_key] then
         found_cmd = binds[test_key]
         found_key = test_key
      end
   end
   if not found_key then
      test_key = string.format("@chat:%s", cursor_key)
      if binds[test_key] then
         found_cmd = binds[test_key]
         found_key = test_key
      end
   end
   return info
end

function key_bind_cb()
   if g.hook.key_bind_timer then
      w.unhook(g.hook.key_bind_timer)
   end
   g.hook.key_bind_timer = w.hook_timer(300, 0, 1, "key_bind_timer_cb", w.current_buffer())
   return w.WEECHAT_RC_OK
end

function key_bind_timer_cb(buf_ptr)
   g.hook.key_bind_timer = nil
   if g.config.local_bindings then
      collect_local_bindings(buf_ptr)
   end
   collect_bindings()
   return w.WEECHAT_RC_OK
end

function config_cb(_, full_name, value)
   local name = full_name:gsub("^plugins%.var%.lua%."..script_name.."%.", "")
   if name:sub(1, 5) == "name." then
      local key_code = convert_escape(name:sub(6))
      if key_code ~= "" then
         g.overrides[key_code] = value ~= "" and value or nil
      end
   elseif g.default[name] then
      g.config[name] = value
      if name == "duration" then
         validate_duration()
      elseif name == "local_bindings" then
         check_local_bindings()
      end
   end
   return w.WEECHAT_RC_OK
end

function buffer_closed_cb(_, _, buf_ptr)
   if g.binding.buffer and g.binding.buffer[buf_ptr] then
      g.binding.buffer[buf_ptr] = nil
   end
   return w.WEECHAT_RC_OK
end

function buffer_switch_cb(_, _, buf_ptr)
   if g.binding.buffer and not g.binding.buffer[buf_ptr] then
      collect_local_bindings(buf_ptr)
   end
   return w.WEECHAT_RC_OK
end

function command_cb(_, buffer, param)
   local names, keys, overrides, conf = g.names, g.keys, g.overrides, g.config
   local delim, reset = w.color("chat_delimiters"), w.color("reset")
   local o = {}
   for k, v in pairs(keys) do
      local code = k:gsub("\001%[", delim.."^["..reset)
                    :gsub("\001", delim.."^"..reset)

      local str
      if type(v) == "table" then
         str = table.concat(v, conf.mod_separator)
      else
         str = v
      end
      table.insert(o, code.."\t"..str)
   end
   table.sort(o)
   for _, v in ipairs(o) do
      w.print("", v)
   end
   return w.WEECHAT_RC_OK
end

function setup_key_map()
   local n, term = g.names, os.getenv("TERM")
   local keys = {
      ["\001I"] = n.tab,
      ["\001M"] = n.enter,
      ["\001@"] = { n.ctrl, n.space},
      ["\001[[A"] = n.up,
      ["\001[[B"] = n.down,
      ["\001[[C"] = n.right,
      ["\001[[D"] = n.left,
      ["\001[[Z"] = { n.shift, n.tab },
      ["\001[OA"] = { n.ctrl, n.up },
      ["\001[OB"] = { n.ctrl, n.down },
      ["\001[OC"] = { n.ctrl, n.right },
      ["\001[OD"] = { n.ctrl, n.left },
      ["\001[ "] = { n.meta, n.space },

      ["\001[OP"] = n.f1,
      ["\001[OQ"] = n.f2,
      ["\001[OR"] = n.f3,
      ["\001[OS"] = n.f4,
      ["\001[[15~"] = n.f5,
      ["\001[[17~"] = n.f6,
      ["\001[[18~"] = n.f7,
      ["\001[[19~"] = n.f8,
      ["\001[[20~"] = n.f9,
      ["\001[[21~"] = n.f10,
      ["\001[[23~"] = n.f11,
      ["\001[[24~"] = n.f12,

      ["\001[[1~"] = n.home,
      ["\001[[2~"] = n.insert,
      ["\001[[3~"] = n.delete,
      ["\001[[4~"] = n["end"],
      ["\001[[5~"] = n.pageup,
      ["\001[[6~"] = n.pagedown,

      ["\001[[H"] = n.home,
      ["\001[[F"] = n["end"]
   }

   local xterm_mods = {
      [2] = { n.shift },
      [3] = { n.meta },
      [4] = { n.meta, n.shift },
      [5] = { n.ctrl },
      [6] = { n.ctrl, n.shift },
      [7] = { n.meta, n.ctrl },
      [8] = { n.meta, n.ctrl, n.shift },
   }

   local add = function (t1, t2, ...)
      local t = {}
      for _, v in ipairs(t1) do
         table.insert(t, v)
      end
      for _, v in ipairs(t2) do
         table.insert(t, v)
      end
      keys[string.format(...)] = t
   end

   for i, m in pairs(xterm_mods) do
      add(m, { n.up }, "\001[[1;%sA", i)
      add(m, { n.down }, "\001[[1;%sB", i)
      add(m, { n.right }, "\001[[1;%sC", i)
      add(m, { n.left }, "\001[[1;%sD", i)

      add(m, { n.home }, "\001[[1;%sH", i)
      add(m, { n["end"] }, "\001[[1;%sF", i)

      add(m, { n.insert }, "\001[[2;%s~", i)
      add(m, { n.delete }, "\001[[3;%s~", i)
      add(m, { n.pageup }, "\001[[5;%s~", i)
      add(m, { n.pagedown }, "\001[[6;%s~", i)
   end

   -- FIXME: this sucks
   if term:match("^xterm") then
      keys["\001H"] = n.backspace
      keys["\001?"] = { n.ctrl, n.backspace }
   else
      keys["\001?"] = n.backspace
      keys["\001H"] = { n.ctrl, n.backspace }
   end
   g.keys = keys
   g.overrides = collect_overrides()
end

function convert_escape(s)
   s = s:gsub("(\\+)([xX]%x%x?)", function (b, n)
              if #b % 2 == 0 then
                 return b..n
              else
                 return b:sub(2)..string.char(tonumber(n:sub(2), 16))
              end
           end)
   return (s:gsub("\\\\", "\\"))
end

function collect_overrides()
   local h_file = w.hdata_get("config_file")
   local file = w.hdata_search(h_file,
                               w.hdata_get_list(h_file, "config_files"),
                               "${config_file.name} == plugins", 1)
   if not file or file == "" then
      return
   end
   local section = w.config_search_section(file, "var")
   if not section or section == "" then
      return
   end
   local h_option, keys = w.hdata_get("config_option"), {}
   local option = w.hdata_pointer(w.hdata_get("config_section"), section, "options")
   local opt_prefix = "lua."..script_name..".name."
   while option and option ~= "" do
      local name = w.hdata_string(h_option, option, "name")
      if #name > #opt_prefix and name:sub(1, #opt_prefix) == opt_prefix then
         local key_code = convert_escape(name:sub(#opt_prefix + 1))
         local seq = w.config_string(option)
         keys[key_code] = seq
      end
      option = w.hdata_pointer(h_option, option, "next_option")
   end
   return keys
end

main()

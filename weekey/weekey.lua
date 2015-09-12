-- A dumb script for displaying key combo in a bar
--
-- It creates 3 bar items:
--
-- 1. weekey_combo: the key combo
-- 2. weekey_command: the command for that key combo 
-- 3. weekey_context: context for the key combo
--
-- Requires Weechat 1.0 or newer

w, script_name = weechat, "weekey"

g = {
   recent_combo = "",
   recent_command = "",
   recent_context = "",
   hook = {},
   modifier = {
      shift = "Shift",
      ctrl = "Ctrl",
      meta = "Meta",
      meta2 = "Meta2"
   },
   context = { "default", "search", "cursor" },
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
      color_delim = { "bar_delim", "Color of delimiter" }
   },
   item = { "combo", "command", "context" }
}

function main()
   if w.register(script_name, "singalaut", "0.1", "WTFPL", "Key monitoring", "", "") then
      init_config()
      collect_bindings()

      for _, item in ipairs(g.item) do
         w.bar_item_new(script_name.."_"..item, "item_"..item.."_cb", "")
      end
      for _, ctx in ipairs(g.context) do
         w.hook_signal("9000|key_combo_"..ctx, "key_combo_cb", ctx)
      end
      w.hook_signal("key_bind", "key_bind_cb", "")
      w.hook_signal("key_unbind", "key_bind_cb", "")
      w.hook_config("plugins.var.lua."..script_name..".*", "config_cb", "")
   end
end

function collect_bindings()
   local binds = g.binding
   for _, ctx in ipairs(g.context) do
      local list = w.infolist_get("key", "", ctx)
      if list and list ~= "" then
         binds[ctx] = {}
         while w.infolist_next(list) == 1 do
            local key_code = w.infolist_string(list, "key_internal")
            local command = w.infolist_string(list, "command")
            binds[ctx][key_code] = command
         end
         w.infolist_free(list)
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
   local list = w.infolist_get("buffer", buf_ptr, "")
   if list and list ~= "" and w.infolist_next(list) == 1 then
      local fields = ","..w.infolist_fields(list)..","
      local keys = {}
      for id in fields:gmatch(",s:key_(%d+),") do
         local code = w.infolist_string(list, "key_"..id)
         keys[code] = w.infolist_string(list, "key_command_"..id)
      end
      w.infolist_free(list)
      g.binding.buffer[buf_ptr] = keys
   end
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
   update_recent_combo(signal_data, found_bind)
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

function update_recent_combo(signal_data, found_bind)
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

   local mod, keys = g.modifier, g.keys
   local combo, i, partial = {}, 1, false
   local color_delim = w.color(conf.color_delim)

   for ch in signal_data:gmatch("(\001[^\001]*)") do
      local seq = {}
      if partial then
         i = i - 1
         table.insert(seq, combo[i])
      end
      if keys[ch] then
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
            table.insert(seq, mod.meta)
         elseif brackets == "[[" then
            table.insert(seq, mod.meta2)
         elseif brackets == "" then
            table.insert(seq, mod.ctrl)
         end
         if str ~= "" then
            table.insert(seq, str)
            partial = false
         else
            partial = true
         end
      end
      combo[i] = color_key..table.concat(seq, color_delim..conf.mod_separator..color_key)
      i = i + 1
   end
   if #combo == 0 then
      g.recent_combo = ""
   else
      g.recent_combo = table.concat(combo, color_delim..conf.key_separator)
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
   local prefix = "plugins.var.lua."..script_name.."."
   local name = full_name:sub(#prefix + 1)
   if name and name ~= "" and g.default[name] then
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

-- these are just partial key list.
-- if you want to add another key the generic guides are:
--
-- weechat modifier           internal key code
-- ============================================
-- meta2-                     \001[[
-- meta-                      \001[
-- ctrl-                      \001
-- 
-- of course there are exceptions because terminal keys are fucking annoying

g.keys = {
   ["\001?"] = "Back",
   ["\001H"] = { g.modifier.ctrl, "Back" },
   ["\001I"] = "Tab",
   ["\001M"] = "Enter",
   ["\001@"] = "Space",
   ["\001[[A"] = "Up",
   ["\001[[B"] = "Down",
   ["\001[[C"] = "Right",
   ["\001[[D"] = "Left",
   ["\001[[Z"] = { g.modifier.shift, "Tab" },
   ["\001[OA"] = { g.modifier.ctrl, "Up" },
   ["\001[OB"] = { g.modifier.ctrl, "Down" },
   ["\001[OC"] = { g.modifier.ctrl, "Right" },
   ["\001[OD"] = { g.modifier.ctrl, "Left" },
   ["\001[ "] = { g.modifier.meta, "Space" },

   ["\001[OP"] = "F1",
   ["\001[OQ"] = "F2",
   ["\001[OR"] = "F3",
   ["\001[OS"] = "F4",
   ["\001[[15~"] = "F5",
   ["\001[[17~"] = "F6",
   ["\001[[18~"] = "F7",
   ["\001[[19~"] = "F8",
   ["\001[[20~"] = "F9",
   ["\001[[21~"] = "F10",
   ["\001[[23~"] = "F11",
   ["\001[[24~"] = "F12",

   ["\001[[1~"] = "Home",
   ["\001[[2~"] = "Ins",
   ["\001[[3~"] = "Del",
   ["\001[[4~"] = "End",
   ["\001[[5~"] = "PgDown",
   ["\001[[6~"] = "PgUp",

   -- xterm

   ["\001[[H"] = "Home",
   ["\001[[F"] = "End",
   ["\001[[2;5~"] = { g.modifier.ctrl, "Ins" },
   ["\001[[3;5~"] = { g.modifier.ctrl, "Del" },
}

main()

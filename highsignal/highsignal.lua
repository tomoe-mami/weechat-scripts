local w = weechat
local g = {
   -- globals here
   script = {
      name = "highsignal",
      author = "tomoe-mami <https://github.com/tomoe-mami>",
      version = "0.1",
      license = "WTFPL",
      description = "Send hsignal when a highlight occurs"
   },
   config = {},
   defaults = {
      monitor_pv = {
         type = "boolean",
         value = "0",
         description = "Monitor private message"
      },
      interval = {
         type = "number",
         value = "2000",
         description = "Interval (in milliseconds) before flushing messages"
      },
      message_format = {
         type = "string",
         value = "${stripped_message}\n",
         description = "Format of each message entry when they are combined"
      },
      message_limit = {
         type = "number",
         value = "0",
         description =
            "Flush if total messages from one user exceeded this number. " ..
            "Use 0 to disable"
      }
   },
   timers = {},
   list = {}
}

function print_cb(_, buffer, date, tags, displayed, highlighted, prefix, msg)
   tags = "," .. tags .. ","
   local do_pv = (g.config.monitor_pv and tags:match(",notify_private"))

   if highlighted == "1" or do_pv then
      entry_add(buffer, tonumber(date), prefix, msg)
   end
end

function hsignal_send_normal(entry_id, entry_message, new_message)
   local ht =  {
      buffer_plugin = g.list[entry_id].buffer_plugin,
      buffer_name = g.list[entry_id].buffer_plugin,
      prefix = g.list[entry_id].prefix,
      entry_id = entry_id,
      timestamp = entry_message.timestamp,
      message = entry_message.text,
      new = (new_message and 1 or 0)
   }
   w.hook_hsignal_send(g.script.name .. "_message", ht)
end

function hsignal_send_flush(entry_id)
   local entry = g.list[entry_id]
   local ht =  {
      buffer_plugin = entry.buffer_plugin,
      buffer_name = entry.buffer_plugin,
      prefix = entry.prefix,
      entry_id = entry_id,
      total_messages = #entry.messages,
      all_messages = ""
   }

   for i, m in ipairs(entry.messages) do
      local stripped = w.string_remove_color(m.text, "")
      ht["message_" .. i] = m.text
      ht["timestamp_" .. i] = m.timestamp
      ht["stripped_message_" .. i] = stripped

      local param = {
         time = os.date(g.config.time_format, m.timestamp),
         prefix = ht.prefix,
         message = m.text,
         stripped_message = stripped
      }
      ht.all_messages =
         ht.all_messages ..
         w.string_eval_expression(g.config.message_format, {}, param, {})
   end
   w.hook_hsignal_send(g.script.name .. "_end", ht)
end

function timer_start(entry_id)
   if g.timers[entry_id] then
      w.unhook(g.timers[entry_id])
      g.timers[entry_id] = nil
   end
   g.timers[entry_id] =
      w.hook_timer(g.config.interval, 0, 1, "entry_flush", entry_id)
end

function entry_add(buffer, date, prefix, msg)
   local stripped_prefix = w.string_remove_color(prefix, "")
   local buffer_full_name = w.buffer_get_string(buffer, "full_name")
   local entry_id = buffer_full_name .. "," .. stripped_prefix
   local new_message = false

   if g.list[entry_id] then
      if g.config.message_limit > 0 and
         #g.list[entry_id].messages >= g.config.message_limit then
         entry_flush(entry_id)
      end
   end

   if not g.list[entry_id] then
      g.list[entry_id] = {
         buffer_plugin = w.buffer_get_string(buffer, "plugin"),
         buffer_name = w.buffer_get_string(buffer, "name"),
         prefix = stripped_prefix,
         messages = {}
      }
      new_message = true
   end

   local entry_message = {
      timestamp = date,
      highlighted = highlighted,
      tags = tags,
      text = msg
   }

   table.insert(g.list[entry_id].messages, entry_message)
   timer_start(entry_id)
   hsignal_send_normal(entry_id, entry_message, new_message)
end

function entry_flush(entry_id)
   if g.list[entry_id] then
      hsignal_send_flush(entry_id)
      g.list[entry_id] = nil
      g.timers[entry_id] = nil
   end
   return w.WEECHAT_RC_OK
end

function config_init()
   for name, info in pairs(g.defaults) do
      local value
      if w.config_is_set_plugin(name) ~= 1 then
         value = info.value
         w.config_set_plugin(name, value)
         if info.description then
            w.config_set_desc_plugin(name, info.description)
         end
      else
         value = w.config_get_plugin(name)
      end

      if info.type == "number" or info.type == "bolean" then
         value = tonumber(value)
         if info.type == "boolean" then
            value = (value ~= 0)
         end
      end
      g.config[name] = value
   end
end

function main()
   assert(w.register(
      g.script.name,
      g.script.author,
      g.script.version,
      g.script.license,
      g.script.description,
      "", ""),
      "Unable to register script. Perhaps it has been loaded before?")

   config_init()
   w.hook_print("", "", "", 0, "print_cb", "")
end

main()

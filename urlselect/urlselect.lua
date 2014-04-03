local w = weechat
local g = {
   script = {
      name = "urlselect",
      version = "0.2",
      author = "tomoe-mami <https://github.com/tomoe-mami>",
      license = "WTFPL",
      description = "A bar for selecting URLs"
   },
   defaults = {
      scan_merged_buffers = {
         type = "boolean",
         value = false,
         description = "Scan URLs from buffers that are merged with the current one"
      },
      time_format = {
         type = "string",
         value = "%H:%M:%S",
         description = "Format of time"
      },
      status_timeout = {
         type = "number",
         value = 1300,
         description = "Timeout for displaying status notification (in milliseconds)"
      },
      buffer_name = {
         type = "string",
         value = "normal",
         description =
            "Type of name to use inside urlselect_buffer_name item. " ..
            "Valid values are \"full\", \"normal\", and \"short\""
      },
      url_color = {
         type = "string",
         value = "_lightblue",
         description = "Color for URL"
      },
      nick_color = {
         type = "string",
         value = "",
         description = "Color for nickname. Leave empty to use Weechat's nick color"
      },
      highlight_color = {
         type = "string",
         value = "${weechat.color.chat_highlight},${weechat.color.chat_highlight_bg}",
         description = "Nickname color for highlighted message" 
      },
      index_color = {
         type = "string",
         value = "brown",
         description = "Color for URL index"
      },
      message_color = {
         type = "string",
         value = "default",
         description = "Color for message text"
      },
      time_color = {
         type = "string",
         value = "default",
         description = "Color for time"
      },
      title_color = {
         type = "string",
         value = "default",
         description = "Color for bar title"
      },
      key_color = {
         type = "string",
         value = "cyan",
         description = "Color for list of keys"
      },
      buffer_number_color = {
         type = "string",
         value = "brown",
         description = "Color for buffer number"
      },
      buffer_name_color = {
         type = "string",
         value = "green",
         description = "Color for buffer name"
      },
      help_color = {
         type = "string",
         value = "default",
         description = "Color for help text"
      },
      status_color = {
         type = "string",
         value = "black,green",
         description = "Color for status notification"
      }
   },
   config = {},
   active = false,
   list = "",
   bar_items = { 
      list = {"index", "nick", "url", "time", "message", "buffer_name", "buffer_number"},
      extra = { "title", "help", "status"}
   },
   custom_commands = {},
   hooks = {},
   current_status = "",
   enable_help = false,
   last_index = 0
}

g.bar = {
   main = { name = g.script.name },
   help = { name = g.script.name .. "_help" }
}

g.keys = {
      ["meta2-B"] = "navigate next",
      ["meta2-A"] = "navigate previous",
     ["meta2-1~"] = "navigate last",
     ["meta2-4~"] = "navigate first",
       ["ctrl-P"] = "navigate previous-highlight",
       ["ctrl-N"] = "navigate next-highlight",
       ["ctrl-S"] = "hsignal",
       ["ctrl-C"] = "deactivate",
      ["meta-OP"] = "help",
    ["meta2-11~"] = "help"
}

function setup()
   assert(
      w.register(
         g.script.name,
         g.script.author,
         g.script.version,
         g.script.license,
         g.script.description,
         "", ""),
      "Unable to register script. Perhaps it's already loaded before?")

   local wee_ver = tonumber(w.info_get("version_number", "") or 0)
   if wee_ver < 0x00040400 then
      error("This script requires WeeChat v0.4.4 or higher")
   end

   local first_run, total_cmd = init_config()
   setup_hooks()
   if total_cmd == 0 and first_run then
      print("No custom commands configured. Adding default custom command...")
      w.config_set_plugin("cmd.o", "/exec -bg -nosh xdg-open ${url}")
      w.config_set_plugin("cmd.i", "/input insert ${url}\\x20")
   end
   setup_bar()
end

function print(msg, param)
   if not param or type(param) ~= "table" then
      param = {}
   end
   param.script_name = g.script.name
   if not param.no_eval then
      msg = w.string_eval_expression(msg, {}, param, {})
   end
   local prefix = g.script.name
   if param.prefix_type then
      prefix = w.color("chat_prefix_" .. param.prefix_type) .. prefix
   end
   w.print("", prefix .. "\t" .. msg)
end

function init_config()
   local first_run, total_cmd = true, 0
   for name, info in pairs(g.defaults) do
      local value
      if w.config_is_set_plugin(name) == 0 then
         if info.type == "boolean" then
            value = info.value and 1 or 0
         else
            value = w.string_eval_expression(info.value, {}, {}, {})
         end
         w.config_set_plugin(name, value)
         if info.description and info.description ~= "" then
            w.config_set_desc_plugin(name, info.description)
         end
      else
         first_run = false
         value = w.config_get_plugin(name)
      end
      if info.type == "number" or info.type == "boolean" then
         value = tonumber(value)
         if info.type == "boolean" then
            value = value ~= 0
         end
      end
      g.config[name] = value
   end

   local prefix = "plugins.var.lua." .. g.script.name .. ".cmd."
   local cfg = w.infolist_get("option", "", prefix .. "*")
   if cfg and cfg ~= "" then
      while w.infolist_next(cfg) == 1 do
         local opt_name = w.infolist_string(cfg, "full_name")
         local opt_value = w.infolist_string(cfg, "value")
         local key = opt_name:sub(#prefix + 1)
         if key then
            local label = w.config_get_plugin("label." .. key)
            if set_custom_command(key, opt_value, label, true) then
               total_cmd = total_cmd + 1
            end
         end
      end
      w.infolist_free(cfg)
   end
   return first_run, total_cmd
end

function set_custom_command(key, cmd, label, silent)
   if not key or not key:match("^[0-9a-z]$") then
      w.config_unset_plugin("cmd." .. key)
      if not silent then
         print(
            "You can only bind 1 character for custom command. " ..
            "Valid type of character are digit (0-9) and lowercase " ..
            "alphabet (a-z) ",
            { prefix_type = "error" })
      end
      return false
   else
      local key_code = "meta-" .. key
      if not cmd or cmd == "" then
         if g.keys[key_code] then g.keys[key_code] = nil end
         if g.custom_commands[key] then g.custom_commands[key] = nil end
         if not silent then
            print("Key ${color:bold}${key}${color:-bold} removed", { key = key })
         end
      else
         g.keys[key_code] = "run " .. key
         g.custom_commands[key] = { command = cmd }
         if label and label ~= "" then
            g.custom_commands[key].label = label
         end
         if not silent then
            print(
               "Key ${color:bold}${key}${color:-bold} bound to command: " ..
               "${color:bold}${cmd}${color:-bold}",
               { key = key, cmd = cmd })
         end
      end
      return true
   end
end

function set_custom_label(key, label)
   if key and key ~= "" and g.custom_commands[key] then
      g.custom_commands[key].label = label
   end
end

function setup_hooks()
   w.hook_config("plugins.var.lua." .. g.script.name .. ".*", "config_cb", "")
   w.hook_command(
      g.script.name,
      "Control urlselect script",
      "[activate] " ..
      "|| bind <key> <command> " ..
      "|| unbind <key> " ..
      "|| list-commands " ..
      "|| deactivate " ..
      "|| navigate <direction> " ..
      "|| run <key> " ..
      "|| hsignal " ..
      "|| help",
[[
      activate: Activate the URL selection bar (default action).
          bind: Bind a key to a Weechat command.
        unbind: Unbind key.
 list-commands: List all custom commands and their keys.
         <key>: A single digit character (0-9) or one lowercase alphabet (a-z).
     <command>: Weechat command. The following variables will be replaced with
                their corresponding values from the currently selected URL:
                ${url}, ${nick}, ${time}, ${message}, ${index}.

The following actions are only available when the selection bar is active and
already bound to keys (see KEY BINDINGS below). You'll never need to use these
manually:

    deactivate: Deactivate URL selection bar.
      navigate: Navigate within the list of URLs.
           run: Run the command bound to a key.
       hsignal: Send a "urlselect_current" hsignal with data from currently
                selected URL.
          help: Toggle help bar.
   <direction>: Direction of movement.
                Valid values are: next, previous, first, last,
                next-highlight, previous-highlight.

KEY BINDINGS
--------------------------------------------------------------
       Ctrl-C: Close/deactivate URL selection bar.
           Up: Move to previous (older) URL.
         Down: Move to next (newer) URL.
         Home: Move to oldest URL.
          End: Move to newest URL.
       Ctrl-P: Move to previous URL that contains highlight.
       Ctrl-N: Move to next URL that contains highlight.
       Ctrl-S: Send hsignal.
 Alt-[0-9a-z]: Run custom command.
           F1: Toggle help bar.

]],
      "activate || bind || unbind || list-commands || deactivate || run || " ..
      "navigate next|previous|first|last|previous-highlight|next-highlight || " ..
      "help",
      "command_cb",
      "")
end

function set_keys(buffer, flag)
   local prefix = flag and "key_bind_" or "key_unbind_"
   local cmd
   for key, val in pairs(g.keys) do
      if not flag then
         cmd = ""
      elseif val:sub(1, 1) == "/" then
         cmd = val
      else
         cmd = string.format("/%s %s", g.script.name, val)
      end
      w.buffer_set(buffer, prefix .. key, cmd)
   end
end

function set_bar(key, flag)
   if g.bar[key].ptr and g.bar[key].ptr ~= "" then
      if not flag then
         w.bar_set(g.bar[key].ptr, "hidden", "on")
      else
         w.bar_set(g.bar[key].ptr, "hidden", "off")
      end
   end
end

function extract_nick_from_tags(tags)
   tags = "," .. tags .. ","
   local nick = tags:match(",nick_([^,]+),")
   return nick, tags
end

function new_line_cb(buffer, evbuf, date, tags, displayed, highlighted, prefix, message)
   if displayed == "1" and g.list and g.list ~= "" then
      if g.config.scan_merged_buffers then
         local evbuf_num = w.buffer_get_integer(evbuf, "number")
         local buf_num = w.buffer_get_integer(buffer, "number")
         if evbuf_num ~= buf_num then
            return
         end
      elseif buffer ~= evbuf then
         return
      end

      local data, indexes = {}, {}
      data.nick = extract_nick_from_tags(tags)
      data.prefix = w.string_remove_color(prefix, "")
      data.message = message
      data.time = tonumber(date)
      data.highlighted = tonumber(highlighted)
      data.buffer_full_name = w.buffer_get_string(evbuf, "full_name")
      data.buffer_name = w.buffer_get_string(evbuf, "name")
      data.buffer_short_name = w.buffer_get_string(evbuf, "short_name")
      data.buffer_number = w.buffer_get_integer(evbuf, "number")

      process_urls_in_message(data.message, function (url, msg)
         data.message = msg
         data.index = g.last_index + 1
         g.last_index = data.index
         table.insert(indexes, data.index)

         data.url = url
         create_new_url_entry(g.list, data)
      end)

      if #indexes > 0 then
         set_status("New URL added at index: " .. table.concat(indexes, ", "))
      end
   end
   return w.WEECHAT_RC_OK
end

function cmd_action_activate(buffer, args)
   if not g.active then
      g.list = collect_urls(buffer)
      if g.list and g.list ~= "" then

         g.hooks.switch = w.hook_signal(
            "buffer_switch",
            "buffer_deactivated_cb",
            buffer)

         g.hooks.close = w.hook_signal(
            "buffer_closing",
            "buffer_deactivated_cb",
            buffer)

         g.hooks.print = w.hook_print(
            "",
            "", "://", 1,
            "new_line_cb",
            buffer)

         g.active = true
         set_bar("main", true)
         cmd_action_navigate(buffer, "previous")
         set_keys(buffer, true)
         w.bar_item_update(g.script.name .. "_title")
      end
   else
      cmd_action_deactivate(buffer, "")
   end
   return w.WEECHAT_RC_OK
end

function cmd_action_deactivate(buffer)
   if g.active then
      g.active, g.enable_help, g.last_index = false, false, 0
      set_bar("main", false)
      set_bar("help", false)
      set_keys(buffer, false)
      if g.list and g.list ~= "" then
         w.infolist_free(g.list)
         g.list = nil
      end
      for name, ptr in pairs(g.hooks) do
         w.unhook(ptr)
      end
      g.hooks = {}
   end
   return w.WEECHAT_RC_OK
end

function move_cursor_normal(list, dir)
   local func
   if dir == "next" or dir == "last" then
      func = w.infolist_next
   elseif dir == "previous" or dir == "first" then
      func = w.infolist_prev
   end
   if dir == "first" or dir == "last" then
      w.infolist_reset_item_cursor(list)
   end
   local status = func(list)
   if status == 0 then
      w.infolist_reset_item_cursor(list)
      status = func(list)
   end
   return status == 1
end

function move_cursor_highlight(list, dir)
   local func, alt
   if dir == "next-highlight" then
      func = w.infolist_next
      alt = w.infolist_prev
   elseif dir == "previous-highlight" then
      func = w.infolist_prev
      alt = w.infolist_next
   else
      return false
   end

   local index = w.infolist_integer(list, "index")
   while func(list) == 1 do
      if w.infolist_integer(list, "highlighted") == 1 then
         return true
      end
   end
   while alt(list) == 1 do
      if w.infolist_integer(list, "index") == index then
         break
      end
   end
   set_status("No URL with highlight found")
   return false
end

function cmd_action_navigate(buffer, args)
   if g.active and g.list and g.list ~= "" then
      if args == "next" or
         args == "previous" or
         args == "first" or
         args == "last" then
         move_cursor_normal(g.list, args)
      elseif args == "next-highlight" or
         args == "previous-highlight" then
         move_cursor_highlight(g.list, args)
      end
      update_list_items()
   end
   return w.WEECHAT_RC_OK
end

function cmd_action_bind(buffer, args)
   local key, command = args:match("^([0-9a-z]?)%s(.*)")
   w.config_set_plugin("cmd." .. key, command)
   return w.WEECHAT_RC_OK
end

function cmd_action_unbind(buffer, args)
   w.config_unset_plugin("cmd." .. args)
   return w.WEECHAT_RC_OK
end

function get_current_hashtable(raw_timestamp)
   local tm = w.infolist_integer(g.list, "time")
   if not raw_timestamp then
      tm = os.date(g.config.time_format, tm)
   end

   return {
      url = w.infolist_string(g.list, "url"),
      nick = w.infolist_string(g.list, "nick"),
      time = tm,
      message = w.infolist_string(g.list, "message"),
      index = w.infolist_integer(g.list, "index"),
      buffer_number = w.infolist_integer(g.list, "buffer_number"),
      buffer_name = w.infolist_string(g.list, "buffer_name"),
      buffer_short_name = w.infolist_string(g.list, "buffer_short_name"),
      buffer_full_name = w.infolist_string(g.list, "buffer_full_name")
   }
end

function eval_current_entry(text)
   return w.string_eval_expression(text, {}, get_current_hashtable(), {})
end

function cmd_action_hsignal(buffer, args)
   if g.list and g.list ~= "" then
      w.hook_hsignal_send(
         g.script.name .. "_current",
         get_current_hashtable(true))
   end
   return w.WEECHAT_RC_OK
end

function cmd_action_run(buffer, args)
   if g.list and g.list ~= "" then
      if g.custom_commands[args] then
         local cmd = eval_current_entry(g.custom_commands[args].command)
         local label = g.custom_commands[args].label or args
         set_status("Running cmd " .. label)
         w.command(buffer, cmd)
      end
   end
   return w.WEECHAT_RC_OK
end

function cmd_action_list_commands(buffer, args)
   print("KEYS    COMMANDS")
   print("===============================================")
   local fmt, opt = "Alt-%s    %s", { no_eval = true }
   for k = 0, 9 do
      local c = tostring(k)
      if g.custom_commands[c] then
         print(string.format(fmt, c, g.custom_commands[c].command), opt)
      end
   end
   for k = string.byte('a'), string.byte('z') do
      local c = string.char(k)
      if g.custom_commands[c] then
         print(string.format(fmt, c, g.custom_commands[c].command), opt)
      end
   end
end

function buffer_deactivated_cb(buffer)
   cmd_action_deactivate(buffer)
   return w.WEECHAT_RC_OK
end

function cmd_action_help(buffer, args)
   g.enable_help = not g.enable_help
   set_bar("help", g.enable_help)
   w.bar_item_update(g.script.name .. "_help")
   return w.WEECHAT_RC_OK
end

function command_cb(_, buffer, param)
   local action, args = param:match("^([^%s]+)%s*(.*)$")
   local callbacks = {
      activate          = cmd_action_activate,
      deactivate        = cmd_action_deactivate,
      navigate          = cmd_action_navigate,
      bind              = cmd_action_bind,
      unbind            = cmd_action_unbind,
      run               = cmd_action_run,
      hsignal           = cmd_action_hsignal,
      help              = cmd_action_help,
      ["list-commands"] = cmd_action_list_commands
   }

   if not action then
      action = "activate"
   end

   if not callbacks[action] then
      print(
         "Unknown action: ${color:bold}${action}${color:-bold}. " ..
         "See ${color:bold}/help ${script_name}${color:-bold} for usage info.",
         { action = action, prefix_type = "error" })
      return w.WEECHAT_RC_OK
   else
      return callbacks[action](buffer, args)
   end
end

function process_urls_in_message(msg, callback)
   local pattern = "(%a[%w%+%.%-]+://[%w:!/#_~@&=,;%+%?%[%]%.%%%-]+)"
   msg = w.string_remove_color(msg, "")
   local x1, x2, count = 1, 0, 0
   while x1 and x2 do
      x1, x2, url = msg:find(pattern, x2 + 1)
      if x1 and x2 and url then
         count = count + 1
         local msg2
         if g.config.url_color then
            local left, right = "", ""
            if x1 > 1 then
               left = msg:sub(1, x1 - 1)
            end
            if x2 < #msg then
               right = msg:sub(x2 + 1)
            end
            msg2 =
               left ..
               w.color(g.config.url_color) ..
               url ..
               w.color("reset") ..
               right
         end
         callback(url, msg2)
      end
   end
   return count
end

function create_new_url_entry(list, data)
   local item = w.infolist_new_item(list)
   w.infolist_new_var_string(item, "message", data.message or "")
   w.infolist_new_var_string(item, "nick", data.nick or "")
   w.infolist_new_var_string(item, "prefix", data.prefix or "")
   w.infolist_new_var_integer(item, "time", data.time or 0)
   w.infolist_new_var_string(item, "url", data.url or "")
   w.infolist_new_var_integer(item, "index", data.index or 0)
   w.infolist_new_var_integer(item, "highlighted", data.highlighted or 0)
   w.infolist_new_var_string(item, "buffer_full_name", data.buffer_full_name)
   w.infolist_new_var_string(item, "buffer_name", data.buffer_name)
   w.infolist_new_var_string(item, "buffer_short_name", data.buffer_short_name)
   w.infolist_new_var_integer(item, "buffer_number", data.buffer_number or 0)
   return item
end

function convert_datetime_into_timestamp(time_string)
   local year, month, day, hour, minute, second =
      time_string:match("^(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)$")

   return os.time({
      year  = tonumber(year or 0),
      month = tonumber(month or 0),
      day   = tonumber(day or 0),
      hour  = tonumber(hour or 0),
      min   = tonumber(minute or 0),
      sec   = tonumber(second or 0)
   })
end


function collect_urls(buffer)
   if g.config.scan_merged_buffers then
      local mixed_lines = w.hdata_pointer(
         w.hdata_get("buffer"),
         buffer,
         "mixed_lines")
      if mixed_lines and mixed_lines ~= "" then
         return collect_urls_via_hdata(mixed_lines)
      end
   end
   return collect_urls_via_infolist(buffer)
end

function collect_urls_via_infolist(buffer)
   local index, info, list = 0, {}
   local buf_lines = w.infolist_get("buffer_lines", buffer, "")
   if not buf_lines or buf_lines == "" then
      return
   end

   local buf_full_name = w.buffer_get_string(buffer, "full_name")
   local buf_name = w.buffer_get_string(buffer, "name")
   local buf_short_name = w.buffer_get_string(buffer, "short_name")
   local buf_number = w.buffer_get_integer(buffer, "number")

   list = w.infolist_new()

   local add_cb = function (url, msg)
      index = index + 1
      info.index = index
      info.url = url
      info.message = msg
      create_new_url_entry(list, info)
   end

   local get_info_from_current_line = function ()
      local info, tags = {}
      info.nick, tags = extract_nick_from_tags(w.infolist_string(buf_lines, "tags"))
      info.prefix = w.string_remove_color(w.infolist_string(buf_lines, "prefix"), "")
      if tags:match(",logger_backlog,") then
         info.prefix = "backlog: " .. info.prefix
      end
      info.highlighted = w.infolist_integer(buf_lines, "highlight")
      info.message = w.infolist_string(buf_lines, "message")
      info.time = convert_datetime_into_timestamp(w.infolist_time(buf_lines, "date"))
      info.buffer_full_name = buf_full_name
      info.buffer_name = buf_name
      info.buffer_short_name = buf_short_name
      return info
   end

   while w.infolist_next(buf_lines) == 1 do
      if w.infolist_integer(buf_lines, "displayed") == 1 then
         info = get_info_from_current_line()
         process_urls_in_message(info.message, add_cb)
      end
   end
   w.infolist_free(buf_lines)
   if index == 0 then
      w.infolist_free(list)
      list = nil
   else
      g.last_index = index
   end
   return list
end

function collect_urls_via_hdata(mixed_lines)
   local index, info = 0, {}
   local list = w.infolist_new()
   local line = w.hdata_pointer(w.hdata_get("lines"), mixed_lines, "first_line")
   local h_line = w.hdata_get("line")
   local h_line_data = w.hdata_get("line_data")
   local h_buf = w.hdata_get("buffer")

   local add_cb = function (url, msg)
      index = index + 1
      info.index = index
      info.url = url
      info.message = msg
      create_new_url_entry(list, info)
   end

   local get_info_from_current_line = function (data)
      local info = {}

      local buffer = w.hdata_pointer(h_line_data, data, "buffer")
      info.buffer_full_name = w.hdata_string(h_buf, buffer, "full_name")
      info.buffer_name = w.hdata_string(h_buf, buffer, "name")
      info.buffer_short_name = w.hdata_string(h_buf, buffer, "short_name")
      info.buffer_number = w.hdata_integer(h_buf, buffer, "number")

      info.highlighted = w.hdata_char(h_line_data, data, "highlighted")
      info.prefix = w.string_remove_color(w.hdata_string(h_line_data, data, "prefix"), "")
      info.message = w.hdata_string(h_line_data, data, "message")
      info.time = tonumber(w.hdata_time(h_line_data, data, "date") or 0)

      local tag_count = w.hdata_get_var_array_size(h_line_data, data, "tags_array")
      if tag_count > 0 then
         for i = 0, tag_count do
            local tag = w.hdata_string(h_line_data, data, i .. "|tags_array")
            if tag:sub(1, 5) == "nick_" then
               info.nick = tag:sub(6)
            elseif tag == "logger_backlog" then
               info.prefix = "backlog: " .. info.prefix
            end
         end
      end
      return info
   end

   while line and line ~= "" do
      local data = w.hdata_pointer(h_line, line, "data")
      if data and data ~= "" then
         local displayed = w.hdata_char(h_line_data, data, "displayed")
         if displayed == 1 then
            info = get_info_from_current_line(data)
            process_urls_in_message(info.message, add_cb)
         end
      end
      line = w.hdata_move(h_line, line, 1)
   end
   if index == 0 then
      w.infolist_free(list)
      list = nil
   else
      g.last_index = index
   end
   return list
end

function default_item_handler(name, color_key)
   if not g.list or g.list == "" then
      return ""
   else
      local func
      if name == "index" or name == "buffer_number" then
         func = w.infolist_integer
      else
         func = w.infolist_string
      end
      local s = func(g.list, name)
      if not color_key then
         color_key = name .. "_color"
      end
      if g.config[color_key] then
         s = w.color(g.config[color_key]) .. s
      end
      return s
   end
end

function item_buffer_number_cb()
   return default_item_handler("buffer_number")
end

function item_buffer_name_cb()
   local key
   if g.config.buffer_name == "full" then
      key = "buffer_full_name"
   elseif g.config.buffer_name == "short" then
      key = "buffer_short_name"
   else
      key = "buffer_name"
   end
   return default_item_handler(key, "buffer_name_color")
end

function item_message_cb()
   return default_item_handler("message")
end

function item_url_cb()
   return default_item_handler("url")
end

function item_time_cb()
   if not g.list or g.list == "" then
      return ""
   else
      local tm = w.infolist_integer(g.list, "time")
      return w.color(g.config.time_color) ..
             os.date(g.config.time_format, tm)
   end
end

function item_index_cb()
   return default_item_handler("index")
end

function item_nick_cb()
   if not g.list or g.list == "" then
      return ""
   else
      local color = g.config.nick_color
      local text = w.infolist_string(g.list, "nick")
      if w.infolist_integer(g.list, "highlighted") == 1 and
         g.config.highlight_color ~= "" then
         color = g.config.highlight_color
      elseif g.config.nick_color ~= "" then
         color = g.config.nick_color
      elseif text and text ~= "" then
         color = w.info_get("irc_nick_color_name", text)
      else
         color = "default"
      end
      if not text or text == "" then
         text = w.infolist_string(g.list, "prefix")
      end
      return w.color(color) .. text .. w.color("reset")
   end
end

function item_title_cb()
   return string.format(
      "%s%s: %s<F1>%s toggle help",
      w.color(g.config.title_color),
      g.script.name,
      w.color(g.config.key_color),
      w.color(g.config.title_color))
end

function item_help_cb()
   if not g.enable_help then
      return ""
   else
      local key_color = w.color(g.config.key_color)
      local help_color = w.color(g.config.help_color)

      local help_text = w.string_eval_expression([[
${kc}<ctrl-c>${hc} close
${kc}<up>${hc} prev
${kc}<down>${hc} next
${kc}<home>${hc} first
${kc}<end>${hc} last
${kc}<ctrl-p>${hc} prev highlight
${kc}<ctrl-n>${hc} next highlight
${kc}<ctrl-s>${hc} send hsignal
]],
   {}, { kc = key_color, hc = help_color }, {})

      local fmt = "%s<alt-%s>%s %s\n"
      for k = 0, 9 do
         local c = tostring(k)
         if g.custom_commands[c] then
            local cmd = g.custom_commands[c]
            local label = cmd.label or cmd.command
            help_text =
               help_text ..
               string.format(fmt, key_color, c, help_color, label)
         end
      end
      for k = string.byte('a'), string.byte('z') do
         local c = string.char(k)
         if g.custom_commands[c] then
            local cmd = g.custom_commands[c]
            local label = cmd.label or cmd.command
            help_text =
               help_text ..
               string.format(fmt, key_color, c, help_color, label)
         end
      end
      return help_text
   end
end

function set_status(message)
   g.current_status = message
   w.bar_item_update(g.script.name .. "_status")
end

function item_status_cb()
   if not g.current_status or g.current_status == "" then
      return ""
   else
      local s = " " .. g.current_status .. " "
      if g.config.status_color then
         s = w.color(g.config.status_color) .. s
      end
      if g.config.status_timeout and g.config.status_timeout > 0 then
         w.hook_timer(g.config.status_timeout, 0, 1, "set_status", "")
      end
      return s
   end
end

function update_list_items()
   for _, name in ipairs(g.bar_items.list) do
      w.bar_item_update(g.script.name .. "_" .. name)
   end
end

function config_cb(_, opt_name, opt_value)
   local prefix = "plugins.var.lua." .. g.script.name .. "."
   local name = opt_name:sub(#prefix + 1)

   if g.defaults[name] then
      local info = g.defaults[name]
      if info.type == "number" or info.type == "boolean" then
         opt_value = tonumber(opt_value)
         if info.type == "boolean" then
            opt_value = opt_value ~= 0
         end
      end
      g.config[name] = opt_value
   elseif name:sub(1, 4) == "cmd." then
      set_custom_command(name:sub(5), opt_value)
   elseif name:sub(1, 6) == "label." then
      set_custom_label(name:sub(7), opt_value)
   end
end

function setup_bar()
   for _, name in ipairs(g.bar_items.list) do
      w.bar_item_new(g.script.name .. "_" .. name, "item_" .. name .. "_cb", "")
   end

   for _, name in ipairs(g.bar_items.extra) do
      w.bar_item_new(g.script.name .. "_" .. name, "item_" .. name .. "_cb", "")
   end

   local settings = {
      main = {
         priority = 3000,
         filling_tb = "horizontal",
         max_size = 2,
         items = w.string_eval_expression(
            "[${s}_title],#${s}_index,[${s}_buffer_name],<${s}_nick>,${s}_message,${s}_status",
            {}, { s = g.script.name }, {})
      },
      help = {
         priority = 2999,
         filling_tb = "columns_horizontal",
         max_size = 6,
         items = g.script.name .. "_help"
      }
   }

   for key, info in pairs(g.bar) do
      local bar = w.bar_search(info.name)
      if not bar or bar == "" then
         bar = w.bar_new(
            info.name,                 -- name
            "on",                      -- hidden?
            settings[key].priority,    -- priority
            "window",                  -- type
            "active",                  -- condition
            "top",                     -- position
            settings[key].filling_tb,  -- filling top/bottom
            "vertical",                -- filling left/right
            0,                         -- size
            settings[key].max_size,    -- max size
            "default",                 -- text fg
            "cyan",                    -- delim fg
            "default",                 -- bar bg
            "on",                      -- separator
            settings[key].items)       -- items
      end
      g.bar[key].ptr = bar
   end
end

setup()

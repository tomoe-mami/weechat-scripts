local w = weechat
local g = {
   script = {
      name = "urlselect",
      version = "0.2",
      author = "tomoe-mami <https://github.com/tomoe-mami>",
      license = "WTFPL",
      description = "A bar for selecting URLs inside current buffer"
   },
   defaults = {
      status_timeout = {
         type = "number",
         value = 1300,
         description = "Timeout for displaying status notification (in milliseconds)"
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
   bar = "",
   bar_items = { 
      list = {"index", "nick", "url", "time", "message" },
      extra = { "title", "help", "status" }
   },
   custom_commands = {},
   hooks = {},
   current_status = "",
   enable_help = 0,
   last_index = 0
}

g.keys = {
   ["meta2-B"]       = "navigate next",
   ["meta2-A"]       = "navigate previous",
   ["meta2-1~"]      = "navigate last",
   ["meta2-4~"]      = "navigate first",
   ["ctrl-P"]        = "navigate previous-highlight",
   ["ctrl-N"]        = "navigate next-highlight",
   ["ctrl-C"]        = "deactivate",
   ["ctrl-I"]        = "help commands",
   ["?"]             = "help"
}

function setup()
   w.register(
      g.script.name,
      g.script.author,
      g.script.version,
      g.script.license,
      g.script.description,
      "", "")

   local first_run, total_cmd = init_config()
   setup_hooks()
   if total_cmd == 0 and first_run then
      print("No custom commands configured. Adding default custom command...")
      w.config_set_plugin("cmd.1", "/exec -bg -nosh xdg-open ${url}")
      w.config_set_plugin("cmd.2", "/input insert ${url}\\x20")
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
         value = info.value
         w.config_set_plugin(name, value)
         if info.description and info.description ~= "" then
            w.config_set_desc_plugin(name, info.description)
         end
      else
         first_run = false
         value = w.config_get_plugin(name)
      end
      if info.type == "number" then
         value = tonumber(value)
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
         if set_custom_command(key, opt_value, true) then
            total_cmd = total_cmd + 1
         end
      end
      w.infolist_free(cfg)
   end
   return first_run, total_cmd
end

function set_custom_command(key, cmd, silent)
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
      else
         g.keys[key_code] = "run " .. key
         g.custom_commands[key] = cmd

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
      "|| help [commands]",
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
          help: Show help text in URL selection bar. If argument "commands"
                specified, will also show list of available custom commands.
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
        Enter: Insert URL into buffer input.
 Alt-[0-9a-z]: Run custom command.

]],
      "activate || bind || unbind || list-commands || deactivate || run || " ..
      "navigate next|previous|first|last|previous-highlight|next-highlight || " ..
      "help commands",
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

function set_bar(flag)
   if g.bar and g.bar ~= "" then
      if not flag then
         w.bar_set(g.bar, "hidden", "on")
      else
         w.bar_set(g.bar, "hidden", "off")
      end
   end
end

function extract_nick_from_tags(tags)
   tags = "," .. tags .. ","
   local nick = tags:match(",nick_([^,]+),")
   return nick, tags
end

function new_line_cb(_, buffer, date, tags, displayed, highlighted, prefix, message)
   if displayed == "1" and g.list and g.list ~= "" then
      local data = {}
      data.nick = extract_nick_from_tags(tags)
      data.message = message
      data.time = os.date("%Y-%m-%d %H:%M:%S", date)
      data.highlighted = tonumber(highlighted)

      process_urls_in_message(data.message, function (url, msg)
         data.message = msg
         data.index = g.last_index + 1
         g.last_index = data.index
         data.url = url
         create_new_url_entry(g.list, data)
         set_status("New URL added at index " .. data.index)
      end)
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
            buffer,
            "", "://", 1,
            "new_line_cb", "")

         g.active = true
         set_bar(true)
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
      g.active = false
      set_bar(false)
      set_keys(buffer, false)
      g.last_index = 0
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

function eval_current_entry(text)
   local param = {
      url = w.infolist_string(g.list, "url"),
      nick = w.infolist_string(g.list, "nick"),
      time = w.infolist_string(g.list, "time"),
      message = w.infolist_string(g.list, "message"),
      index = w.infolist_integer(g.list, "index")
   }
   return w.string_eval_expression(text, {}, param, {})
end

function cmd_action_run(buffer, args)
   if g.list and g.list ~= "" then
      if g.custom_commands[args] then
         local cmd = eval_current_entry(g.custom_commands[args])
         set_status("Running cmd " .. args)
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
         print(string.format(fmt, c, g.custom_commands[c]), opt)
      end
   end
   for k = string.byte('a'), string.byte('z') do
      local c = string.char(k)
      if g.custom_commands[c] then
         print(string.format(fmt, c, g.custom_commands[c]), opt)
      end
   end
end

function buffer_deactivated_cb(buffer, _, _)
   cmd_action_deactivate(buffer)
   return w.WEECHAT_RC_OK
end

function cmd_action_help(buffer, args)
   if args == "commands" then
      g.enable_help = (g.enable_help == 2 and 1 or 2)
   else
      g.enable_help = (g.enable_help == 0 and 1 or 0)
   end
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
   w.infolist_new_var_string(item, "time", data.time or "")
   w.infolist_new_var_string(item, "url", data.url or "")
   w.infolist_new_var_integer(item, "index", data.index or 0)
   w.infolist_new_var_integer(item, "highlighted", data.highlighted or 0)
   return item
end

function get_data_from_buf_line(list_ptr)
   local data = {}
   data.nick = extract_nick_from_tags(w.infolist_string(list_ptr, "tags"))
   data.highlighted = w.infolist_integer(list_ptr, "highlight")
   data.message = w.infolist_string(list_ptr, "message")
   data.time = w.infolist_time(list_ptr, "date")

   return data
end

function collect_urls(buffer)
   local index, data, list = 0, {}
   local buf_lines = w.infolist_get("buffer_lines", buffer, "")
   if not buf_lines or buf_lines == "" then
      return
   end

   list = w.infolist_new()
   local add_cb = function (url, msg)
      index = index + 1
      data.index = index
      data.url = url
      data.message = msg
      create_new_url_entry(list, data)
   end

   while w.infolist_next(buf_lines) == 1 do
      if w.infolist_integer(buf_lines, "displayed") == 1 then
         data = get_data_from_buf_line(buf_lines)
         process_urls_in_message(data.message, add_cb)
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

function default_item_handler(name)
   if not g.list or g.list == "" then
      return ""
   else
      local func = name == "index" and w.infolist_integer or w.infolist_string
      local s = func(g.list, name)
      if g.config[name .. "_color"] then
         s = w.color(g.config[name .. "_color"]) .. s
      end
      return s
   end
end

function item_message_cb()
   return default_item_handler("message")
end

function item_url_cb()
   return default_item_handler("url")
end

function item_time_cb()
   return default_item_handler("time")
end

function item_index_cb()
   return default_item_handler("index")
end

function item_nick_cb()
   if not g.list or g.list == "" then
      return ""
   else
      local color
      local s = w.infolist_string(g.list, "nick")
      if not s or s == "" then
         s = "*"
         color = "default"
      else
         if g.config.nick_color and g.config.nick_color ~= "" then
            color = g.config.nick_color
         else
            color = w.info_get("irc_nick_color_name", s)
         end
      end
      return w.color(color) .. s
   end
end

function item_title_cb()
   return string.format(
      "%s%s: Press %s?%s for help",
      w.color(g.config.title_color),
      g.script.name,
      w.color(g.config.key_color),
      w.color(g.config.title_color))
end

function item_help_cb()
   if not g.enable_help or g.enable_help == 0 then
      return ""
   else
      local key_color = w.color(g.config.key_color)
      local help_color = w.color(g.config.help_color)

      local help_text = string.format(
         "\r%s%s<ctrl-c>%s close " ..
         "%s<up>%s prev " ..
         "%s<down>%s next " ..
         "%s<home>%s oldest " ..
         "%s<end>%s newest " ..
         "%s<ctrl-p>%s prev highlight " ..
         "%s<ctrl-n>%s next highlight " ..
         "%s<tab>%s show custom commands " ..
         "%s<alt-#>%s run custom command",
         help_color, key_color, help_color,
         key_color, help_color,
         key_color, help_color,
         key_color, help_color,
         key_color, help_color,
         key_color, help_color,
         key_color, help_color,
         key_color, help_color,
         key_color, help_color,
         key_color, help_color)

      if g.enable_help == 2 then
         local cmd, fmt = "", "\r%s%sAlt-%s%s => %s"
         for k = 0, 9 do
            local c = tostring(k)
            if g.custom_commands[c] then
               cmd = cmd ..
                     string.format(
                        fmt,
                        help_color,
                        key_color,
                        c,
                        help_color,
                        g.custom_commands[c])
            end
         end
         for k = string.byte('a'), string.byte('z') do
            local c = string.char(k)
            if g.custom_commands[c] then
               cmd = cmd ..
                     string.format(
                        fmt,
                        help_color,
                        key_color,
                        c,
                        help_color,
                        g.custom_commands[c])
            end
         end
         if cmd == "" then
            help_text = help_text .. "\r" ..
                        help_color ..
                        "[ No custom commands ]"
         else
            help_text = help_text .. "\r" ..
                        help_color ..
                        "[ Custom commands ]".. cmd
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
      if info.type == "number" then
         opt_value = tonumber(opt_value)
      end
      g.config[name] = opt_value
   elseif name:sub(1, 4) == "cmd." then
      set_custom_command(name:sub(5), opt_value)
   end
end

function setup_bar()
   for _, name in ipairs(g.bar_items.list) do
      w.bar_item_new(g.script.name .. "_" .. name, "item_" .. name .. "_cb", "")
   end

   for _, name in ipairs(g.bar_items.extra) do
      w.bar_item_new(g.script.name .. "_" .. name, "item_" .. name .. "_cb", "")
   end

   local bar = w.bar_search(g.script.name)
   if not bar or bar == "" then
      bar = w.bar_new(
         g.script.name,       -- name
         "on",                -- hidden?
         2000,                -- priority
         "window",            -- type
         "active",            -- condition
         "top",               -- position
         "horizontal",        -- vfilling
         "vertical",          -- hfilling
         0,                   -- size
         0,                   -- max size
         "default",           -- text fg
         "cyan",              -- delim fg
         "default",           -- bar bg
         "on",                -- separator
         "[urlselect_title] +#urlselect_index +<urlselect_nick> " ..
         "+urlselect_message,urlselect_status,urlselect_help") -- items
   end
   g.bar = bar
end

setup()

local w = weechat
local g = {
   script = {
      name = "urlselect",
      version = "0.2",
      author = "tomoe-mami <https://github.com/tomoe-mami>",
      license = "WTFPL",
      description = ""
   },
   config = {},
   active = false,
   list = "",
   bar = "",
   bar_items = { 
      list = {"index", "prefix", "url", "time", "message" },
      extra = { "title", "help" }
   },
   keys = {
      ["meta2-A"]  = "navigate previous",
      ["meta2-B"]  = "navigate next",
      ["meta2-1~"] = "navigate first",
      ["meta2-4~"] = "navigate last",
      ["ctrl-M"]   = "insert",
      ["ctrl-C"]   = "deactivate"
   },
   custom_commands = {},
   hooks = {}
}

function setup()
   w.register(
      g.script.name,
      g.script.author,
      g.script.version,
      g.script.license,
      g.script.description,
      "", "")

   init_config()
   setup_hooks()
   setup_bar()
end

function init_config()
   if w.config_is_set_plugin("url_color") == 0 then
      local color = ""
      local opt = w.config_get("weechat.color.emphasized")
      if opt and opt ~= "" then
         color = w.config_color(opt)
      end
      opt = w.config_get("weechat.color.emphasized_bg")
      if opt and opt ~= "" then
         color = color .. "," .. w.config_color(opt)
      end
      w.config_set_plugin("url_color", color)
      g.config.url_color = color
   else
      g.config.url_color = w.config_get_plugin("url_color")
   end

   if w.config_is_set_plugin("title") == 0 then
      g.config.title =
         "${color:${color_delim}}[${color:${color_fg}}" ..
         g.script.name ..
         ": ${total_urls} URL(s) found${color:${color_delim}}]"

      w.config_set_plugin("title", g.config.title)
      w.config_set_desc_plugin("title", "Bar title")
   else
      g.config.title = w.config_get_plugin("title")
   end

   local prefix = "plugins.var.lua." .. g.script.name .. ".cmd."
   local cfg = w.infolist_get("option", prefix .. "*", "")
   if cfg and cfg ~= "" then
      while w.infolist_next(cfg) == 1 do
         local opt_name = w.infolist_string(cfg, "full_name")
         local key = opt_name:sub(#prefix + 1)
         add_custom_command(key, w.infolist_string(cfg, "value"))
      end
      w.infolist_free(cfg)
   end
end

function add_custom_command(key, cmd, leave_option)
   if not key:match("^[0-9a-z]$") then
      if not leave_option then
         w.config_unset_plugin("cmd." .. key)
      end
      return false
   else
      g.keys[key] = "run " .. key
      g.custom_commands[key] = cmd
      return true
   end
end

function setup_hooks()
   w.hook_config("plugins.var.lua." .. g.script.name .. ".*", "config_cb", "")
   w.hook_command(
      g.script.name,
      "", -- decsription
      "", -- args
      "", -- args description
      "", -- args completion
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

function cmd_action_activate(buffer, args)
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

      g.active = true
      set_bar(true)
      cmd_action_navigate(buffer, "next")
      set_keys(buffer, true)
      w.bar_item_update(g.script.name .. "_title")
   end
   return w.WEECHAT_RC_OK
end

function cmd_action_deactivate(buffer)
   g.active = false
   set_bar(false)
   set_keys(buffer, false)
   if g.list and g.list ~= "" then
      w.infolist_free(g.list)
      g.list = nil
   end
   w.buffer_set(buffer, "localvar_del_total_urls", "")
   return w.WEECHAT_RC_OK
end

function cmd_action_navigate(buffer, args)
   if g.list and g.list ~= "" then
      local func
      if args == "next" or args == "first" then
         func = w.infolist_next
      elseif args == "previous" or args == "last" then
         func = w.infolist_prev
      end
      if args == "first" or args == "last" then
         w.infolist_reset_item_cursor(g.list)
      end
      local status = func(g.list)
      if status == 0 then
         w.infolist_reset_item_cursor(g.list)
         status = func(g.list)
      end
      update_list_items()
   end
   return w.WEECHAT_RC_OK
end

function cmd_action_bind(buffer, args)
   local key, command = args:match("^([0-9a-z])%s(.+)")
   if key and command then
      w.config_set_plugin("cmd." .. key, command)
   end
   return w.WEECHAT_RC_OK
end

function cmd_action_unbind(buffer, args)
   local key = args:match("^([0-9a-z])$")
   if key then
      w.config_unset_plugin("cmd." .. key)
      if g.keys[key] then g.keys[key] = nil end
      if g.custom_commands[key] then g.custom_commands[key] = nil end
   end
   return w.WEECHAT_RC_OK
end

function cmd_action_insert(buffer, args)
   if g.list and g.list ~= "" then
      local url = w.infolist_string(g.list, "url")
      w.command(buffer, "/input insert " .. url .. "\\x20")
   end
   return w.WEECHAT_RC_OK
end

function cmd_action_run(buffer, args)
   if g.list and g.list ~= "" then
      if g.custom_commands[args] then
         local param = {
            url = w.infolist_string(g.list, "url"),
            prefix = w.infolist_string(g.list, "prefix"),
            time = w.infolist_string(g.list, "time"),
            message = w.infolist_string(g.list, "message"),
            index = w.infolist_integer(g.list, "index")
         }

         param.prefix = w.string_remove_color(param.prefix, "")
         local cmd = w.string_eval_expression(
            g.custom_commands[args],
            {}, 
            param,
            {})
         w.command(buffer, cmd)
      end
   end
   return w.WEECHAT_RC_OK
end

function buffer_deactivated_cb(buffer, _, _)
   cmd_action_deactivate(buffer)
   return w.WEECHAT_RC_OK
end

function command_cb(_, buffer, param)
   local action, args = param:match("^([^%s]+)%s*(.*)$")
   local callbacks = {
      activate    = cmd_action_activate,
      deactivate  = cmd_action_deactivate,
      navigate    = cmd_action_navigate,
      bind        = cmd_action_bind,
      unbind      = cmd_action_unbind,
      run         = cmd_action_run,
      insert      = cmd_action_insert
   }

   if not action then
      action = "activate"
   end

   if not callbacks[action] then
      return w.WEECHAT_RC_OK
   else
      return callbacks[action](buffer, args)
   end
end

function collect_urls(buffer)
   local index, list = 0
   local function add(source, url, msg)
      if not list then
         list = w.infolist_new()
         if not list or list == "" then
            return false
         end
      end
      local prefix = w.infolist_string(source, "prefix")
      local time = w.infolist_string(source, "str_time")
      time = w.string_remove_color(time, "")
      index = index + 1

      local x1, x2 = msg:find(url, 1, true)
      local left, right = "", ""
      if x1 > 1 then
         left = msg:sub(1, x1 - 1)
      end
      if x2 < #msg then
         right = msg:sub(x2 + 1)
      end
      msg = left ..
            w.color(g.config.url_color) ..
            url ..
            w.color("reset") ..
            right

      local item = w.infolist_new_item(list)
      w.infolist_new_var_string(item, "message", msg)
      w.infolist_new_var_string(item, "prefix", prefix)
      w.infolist_new_var_string(item, "time", time)
      w.infolist_new_var_string(item, "url", url)
      w.infolist_new_var_integer(item, "index", index)
      return true
   end

   local function process(source)
      if w.infolist_integer(source, "displayed") == 1 then
         local pattern = "(%a[%w%+%.%-]+://[%w:!/#_~@&=,;%+%?%[%]%.%%%-]+)"
         local msg = w.infolist_string(source, "message")
         msg = w.string_remove_color(msg, "")
         for url in msg:gmatch(pattern) do
            if not add(source, url, msg) then
               return false
            end
         end
      end
      return true
   end

   local buf_lines = w.infolist_get("buffer_lines", buffer, "")
   if buf_lines and buf_lines ~= "" then
      while w.infolist_next(buf_lines) == 1 do
         if not process(buf_lines) then
            break
         end
      end
      w.buffer_set(buffer, "localvar_set_total_urls", index)
      w.infolist_free(buf_lines)
   end
   return list
end

function item_message_cb()
   if not g.list or g.list == "" then
      return ""
   else
      return w.infolist_string(g.list, "message")
   end
end

function item_url_cb()
   if not g.list or g.list == "" then
      return ""
   else
      return w.infolist_string(g.list, "url")
   end
end

function item_time_cb()
   if not g.list or g.list == "" then
      return ""
   else
      return w.infolist_string(g.list, "time")
   end
end

function item_prefix_cb()
   if not g.list or g.list == "" then
      return ""
   else
      return w.color("bar_bg") .. w.infolist_string(g.list, "prefix")
   end
end

function item_index_cb()
   if not g.list or g.list == "" then
      return ""
   else
      return w.infolist_integer(g.list, "index")
   end
end

function item_title_cb()
   local options = { 
      color_fg = "",
      color_bg = "",
      color_delim = ""
   }

   for k, v in pairs(options) do
      local name = string.format("weechat.bar.%s.%s", g.script.name, k)
      local opt = w.config_get(name)
      if opt and opt ~= "" then
         options[k] = w.config_color(opt)
      end
   end

   local text = w.string_eval_expression(g.config.title, {}, options, {})
   w.print("", g.config.title)
   w.print("", text)
   return text
end

function item_help_cb()
   return "halp!"
end

function update_list_items()
   for _, name in pairs(g.bar_items.list) do
      w.bar_item_update(g.script.name .. "_" .. name)
   end
end

function config_cb(_, opt_name, opt_value)
   local prefix = "plugins.var.lua." .. g.script.name .. "."
   local name = opt_name:sub(#prefix + 1)

   if name == "url_color" then
      g.config.url_color = opt_value
   elseif name:sub(1, 4) == "cmd." then
      if not add_custom_command(name:sub(5), opt_value) then
         w.print("", "You can only bind digits (0-9) and lowercase alphabets " ..
                 "(a-z) for custom command")
      end
   end
end

function setup_bar()
   for _, name in pairs(g.bar_items.list) do
      w.bar_item_new(g.script.name .. "_" .. name, "item_" .. name .. "_cb", "")
   end

   for _, name in pairs(g.bar_items.extra) do
      w.bar_item_new(g.script.name .. "_" .. name, "item_" .. name .. "_cb", "")
   end

   local bar = w.bar_search(g.script.name)
   if not bar or bar == "" then
      bar = w.bar_new(
         g.script.name,       -- name
         "on",                -- hidden?
         0,                   -- priority
         "window",            -- type
         "active",            -- condition
         "bottom",            -- position
         "vertical",          -- vfilling
         "vertical",          -- hfilling
         2,                   -- size
         3,                   -- max size
         "default",           -- text fg
         "default",           -- delim fg
         "default",           -- bar bg
         "no",                -- separator
         "urlselect_index,urlselect_url")
   end
   g.bar = bar
end

setup()

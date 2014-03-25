local w = weechat
local g = {
   script = {
      name = "msgcolor",
      author = "tomoe-mami <https://github.com/tomoe-mami",
      version = "0.1",
      license = "WTFPL",
      description = "Colorize lines from the same buffer."
   },
   defaults = {
      colors = {
         type = "list",
         description = "List of space separated colors that will be used to " ..
                       "colorize buffer lines",
         value = { 1, 2, 3, 4, 5, 6, 7 }
      }
   },
   config = {},
   pool = {}
}

function setup()
   w.register(
      g.script.name,
      g.script.author,
      g.script.version,
      g.script.license,
      g.script.description,
      "", "")

   math.randomseed(os.time())

   init_config()
   assign_colors_to_opened_buffers()
   setup_hooks()
end

function setup_hooks()
   w.hook_config("plugins.var.lua." .. g.script.name .. ".*", "config_cb", "")
   w.hook_signal("irc_channel_opened", "buffer_open_cb", "")
   w.hook_signal("irc_pv_opened", "buffer_open_cb", "")
   w.hook_signal("buffer_closing", "buffer_close_cb", "")
   w.hook_modifier("weechat_print", "print_cb", "")
   w.hook_command(
      g.script.name,
      "",
      "shuffle|set <color> [<buffers>]|unset [<buffers>]",
[[
   shuffle: Shuffle the colors assigned for opened channel/pv buffers.
       set: Set custom color. If no buffer specified, this will set color for
            current buffer.
     unset: Unset custom color for buffers (or just the current one if no
            buffers specified).

   <color>: Color code. See Plugin API documentation for weechat_color
            for the correct syntax.
 <buffers>: Space separated list of channel/pv buffers.

The list of default colors are stored in option plugins.var.lua.]] ..
      g.script.name .. ".colors",
      "shuffle || " ..
      "set %- %(buffers_names)|| " ..
      "unset %(buffers_names)",
      "command_cb",
      "")
end

function message()
   w.print("", g.script.name .. "\t" .. s)
end

function command_cb(_, current_buffer, param)
   if not param or param == "" then
      param = "shuffle"
   end

   local action, args = param:match("^([^%s]+)%s*(.*)")
   if not action then
      return w.WEECHAT_RC_OK
   elseif action == "shuffle" then
      return action_shuffle_colors()
   elseif action == "set" then
      return action_set_custom_color(args)
   elseif action == "unset" then
      return action_unset_custom_color(args)
   end
end

function action_shuffle_colors()
   refill_pool()
   assign_colors_to_opened_buffers(true)
   return w.WEECHAT_RC_OK
end

function action_set_custom_color(args)
   local color, buffer_list = args:match("^([^%s]+)%s*(.*)")
   if not color then
      message("Action `set` requires a color parameter")
      return w.WEECHAT_RC_ERROR
   end
   if not buffer_list or buffer_list == "" then
      buffer_list = w.buffer_get_string(w.current_buffer(), "name")
   end
   for name in buffer_list:gmatch("([^%s]+)") do
      w.config_set_plugin("custom." .. name, color)
      local buffer = w.buffer_search("irc", name)
      if buffer and buffer ~= "" then
         w.buffer_set(buffer, "localvar_set_color", color)
      end
   end
   return w.WEECHAT_RC_OK
end

function action_unset_custom_color(args)
   if not args or args == "" then
      args = w.buffer_get_string(w.current_buffer(), "name")
   end
   for name in args:gmatch("([^%s]+)") do
      local opt_name = "custom." .. name
      if w.config_is_set_plugin(opt_name) == 1 then
         w.config_unset_plugin(opt_name)
         local buffer = w.buffer_search("irc", name)
         if buffer and buffer ~= "" then
            w.buffer_set(buffer, "localvar_set_color", get_color())
         end
      end
   end
   return w.WEECHAT_RC_OK
end

function get_or_set_option(name, info, value)
   if not value then
      if w.config_is_set_plugin(name) ~= 1 then
         if info.type == "list" then
            value = table.concat(info.value, " ")
         else
            value = info.value
         end
         w.config_set_plugin(name, value)
         if info.description then
            w.config_set_desc_plugin(name, info.description)
         end
      else
         value = w.config_get_plugin(name)
      end
   end
   if info.type == "list" then
      local list = {}
      for item in value:gmatch("([^%s]+)") do
         table.insert(list, item)
      end
      value = list
   end
   return value
end

function init_config()
   for name, info in pairs(g.defaults) do
      g.config[name] = get_or_set_option(name, info)
   end
   if not g.config.colors or #g.config.colors == 0 then
      g.config.colors = g.defaults.colors.value
   end
end

function refill_pool()
   local pool = {}
   for _, v in ipairs(g.config.colors) do
      table.insert(pool, v)
   end
   g.pool = pool
end

function get_custom_buffer_color(buffer)
   local name = w.buffer_get_string(buffer, "name")
   local custom = w.config_get_plugin("custom." .. name)
   if custom and custom ~= "" then
      return custom
   end
end

function get_color(buffer)
   local custom = get_custom_buffer_color(buffer)
   if custom then
      return custom
   else
      if #g.pool == 0 then
         refill_pool()
      end
      local index = math.random(1, #g.pool)
      local color = g.pool[index]
      local temp = {}
      for _, v in ipairs(g.pool) do
         if v ~= color then
            table.insert(temp, v)
         end
      end
      g.pool = temp
      return color
   end
end

function assign_colors_to_opened_buffers(reassign)
   local buf_list = w.infolist_get("buffer", "", "")
   if buf_list and buf_list ~= "" then
      while w.infolist_next(buf_list) == 1 do
         local buffer = w.infolist_pointer(buf_list, "pointer")
         if buffer and buffer ~= "" then
            local p = w.buffer_get_string(buffer, "plugin")
            local t = w.buffer_get_string(buffer, "localvar_type")
            if p == "irc" and (t == "channel" or t == "private") then
               local c = w.buffer_get_string(buffer, "localvar_color")
               if not c or c == "" or reassign then
                  w.buffer_set(buffer, "localvar_set_color", get_color(buffer))
               end
            end
         end
      end
   end
end

function config_cb(_, option, value)
   local prefix = "plugins.var.lua." .. g.script.name .. "."
   local name = option:match("^plugins%.var%.lua%." .. g.script.name .. "%.(.+)$")
   if name and g.defaults[name] then
      g.config[name] = get_or_set_option(name, g.defaults[name], value)
      if name == "colors" then
         refill_pool()
         assign_colors_to_opened_buffers()
      end
   end
   return w.WEECHAT_RC_OK
end

function buffer_open_cb(_, signal, buffer)
   w.buffer_set(buffer, "localvar_set_color", get_color())
   return w.WEECHAT_RC_OK
end

function buffer_close_cb(_, signal, buffer)
   local color = w.buffer_get_string(buffer, "localvar_color")
   if not color or color == "" then
      return w.WEECHAT_RC_OK
   end
   for _, v in ipairs(g.pool) do
      if v == color then
         return w.WEECHAT_RC_OK
      end
   end
   for _, v in ipairs(g.config.colors) do
      if v == color then
         table.insert(g.pool, color)
         break
      end
   end
   return w.WEECHAT_RC_OK
end

function print_cb(_, modifier, data, text)
   local plugin_name, buffer_name, tags = data:match("([^;]+);([^;]+);(.+)")
   tags = "," .. (tags or "") .. ","
   if not plugin_name or not buffer_name then
      return text
   end

   local buffer = w.buffer_search(plugin_name, buffer_name)
   if not buffer or buffer == "" then
      return text
   end

   local color = w.buffer_get_string(buffer, "localvar_color")
   if not color or color == "" then
      return text
   else
      if text:sub(1,2) == "\t\t" then
         return text
      else
         local left, right = text:match("^([^\t]+\t)(.*)$")
         if not left or not right then
            return text
         else
            if tags:match(",irc_action,") then
               local nick, actual_message = right:match("^([^%s]+%s+)(.*)$")
               if nick and actual_message then
                  left = left .. nick
                  right = actual_message
               end
            end
            return left .. w.color(color) .. right
          end
      end
   end
end

setup()

local w = weechat
local g = {
   script = {
      name = "chatbuf_color",
      author = "tomoe-mami <https://github.com/tomoe-mami",
      version = "0.1",
      license = "WTFPL",
      description = "Colorize messages in chat buffer"
   },
   defaults = {
      colors = {
         type = "list",
         description = "List of space separated colors that will be used to " ..
                       "colorize messages",
         value = { 1, 2, 3, 4, 5, 6, 7 }
      },
      reshuffle_on_load = {
         type = "boolean",
         description = "Reshuffle all assigned colors when the script is loaded",
         value = true
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
   assign_colors_to_opened_buffers(g.config.reshuffle_on_load)
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
      g.script.description,

      "shuffle|set <color> [<buffers>]|unset [<buffers>]",

[[
   shuffle: Shuffle the colors assigned for opened chat buffers.
       set: Set custom color. If no buffer specified, this will set color for
            current buffer.
     unset: Unset custom color for buffers (or just the current one if no
            buffers specified).

   <color>: Color code. See Plugin API documentation for weechat_color
            for the correct syntax.
 <buffers>: Space separated list of chat buffers. The format of each entry
            is <server-name>.<channel-or-nickname>
]],

      "shuffle || " ..
      "set %- %(buffers_names)|%* || " ..
      "unset %(buffers_names)|%*",
      "command_cb",
      "")
end

function message(s)
   w.print("", g.script.name .. "\t" .. s)
end

function command_cb(_, buffer, param)
   local action, args = param:match("^([^%s]+)%s*(.*)")
   if not action or action == "" then
      action = "shuffle"
   end

   local callbacks = {
      shuffle = action_shuffle_colors,
      set = action_set_custom_color,
      unset = action_unset_custom_color
   }

   if callbacks[action] then
      return callbacks[action](buffer, args)
   else
      message("Unknown action: " .. action)
      return w.WEECHAT_RC_ERROR
   end
end

function all_lines(buffer)
   local source = w.hdata_pointer(w.hdata_get("buffer"), buffer, "own_lines")
   if not source or source == "" then
      return
   end
   local h_line = w.hdata_get("line")
   local first_run = true
   local line line = w.hdata_pointer(w.hdata_get("lines"), source, "first_line")
   if not line or line == "" then
      return
   end
   return function ()
      if first_run then
         first_run = false
      else
         line = w.hdata_move(h_line, line, 1)
         if not line or line == "" then
            return
         end
      end
      return w.hdata_pointer(h_line, line, "data")
   end
end

function get_tags_from_line_data(h, line_data)
   local tags = {}
   local tag_count = w.hdata_get_var_array_size(h, line_data, "tags_array")
   if tag_count > 0 then
      for i = 0, tag_count - 1 do
         local tag_name = w.hdata_string(h, line_data, i .. "|tags_array")
         tags[tag_name] = true
      end
   end
   return tags
end

function remove_initial_color(text)
   -- can't do /^(subpattern)+/ nor /(alt|option)/ in standard lua pattern.
   -- we have to do it the ugly way.
   local attr, count, n = "[%*!/_|]"
   local patterns = {
      "^\025%d%d",
      "^\025@%d%d%d%d%d",
      "^\025F" .. attr .. "?%d%d",
      "^\025F@" .. attr .. "?%d%d%d%d%d",
      "^\025B%d%d",
      "^\025B@" .. attr .. "?%d%d%d%d%d",
      "^\025%*" .. attr .. "?%d%d",
      "^\025%*@" .. attr .. "?%d%d%d%d%d",
      "^\025%*" .. attr .. "?%d%d,%d%d",
      "^\025%*" .. attr .. "?%d%d,@%d%d%d%d%d",
      "^\025%*@" .. attr .. "?%d%d%d%d%d,%d%d",
      "^\025%*@" .. attr .. "?%d%d%d%d%d,@%d%d%d%d%d",
      "^\025E",
      "^\025\028",
      "^[\025\027]" .. attr,
      "^\028"
   }
   repeat
      count, n = 0, 0
      for _, pattern in ipairs(patterns) do
         text, n = text:gsub(pattern, "")
         count = count + n
      end
   until count == 0
   return text
end

function colorize_all_lines(buffer, color)
   local h_line_data = w.hdata_get("line_data")
   for line in all_lines(buffer) do
      local tags = get_tags_from_line_data(h_line_data, line)
      if tags.log1 then
         local message = w.hdata_string(h_line_data, line, "message")
         message = w.color(color) .. remove_initial_color(message)
         w.hdata_update(h_line_data, line, { message = message })
      end
   end
end

function action_shuffle_colors()
   refill_pool()
   assign_colors_to_opened_buffers(true)
   return w.WEECHAT_RC_OK
end

function action_set_custom_color(buffer, args)
   local color, buffer_list = args:match("^([^%s]+)%s*(.*)")
   if not color then
      message("Action `set` requires a color parameter")
      return w.WEECHAT_RC_ERROR
   end
   if not buffer_list or buffer_list == "" then
      buffer_list = w.buffer_get_string(buffer, "name")
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

function action_unset_custom_color(buffer, args)
   if not args or args == "" then
      args = w.buffer_get_string(buffer, "name")
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
         elseif info.type == "boolean" then
            value = info.value and 1 or 0
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
   elseif info.type == "boolean" then
      value = tonumber(value)
      value = value and value ~= 0
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

function is_chat_buffer(buffer)
   if not buffer or buffer == "" then
      return false
   else
      local p = w.buffer_get_string(buffer, "plugin")
      local t = w.buffer_get_string(buffer, "localvar_type")
      return p == "irc" and (t == "channel" or t == "private")
   end
end

function all_buffers()
   local buf_list = w.infolist_get("buffer", "", "")
   if not buf_list or buf_list == "" then
      return
   end
   return function ()
      if w.infolist_next(buf_list) ~= 1 then
         w.infolist_free(buf_list)
      else
         return w.infolist_pointer(buf_list, "pointer")
      end
   end
end

function assign_colors_to_opened_buffers(reassign)
   for buffer in all_buffers() do
      if is_chat_buffer(buffer) then
         local color = w.buffer_get_string(buffer, "localvar_color")
         if not color or color == "" or reassign then
            color = get_color(buffer)
            w.buffer_set(buffer, "localvar_set_color", color)
         end
         colorize_all_lines(buffer, color)
      end
   end
end

function config_cb(_, option, value)
   local prefix = "plugins.var.lua." .. g.script.name .. "."
   local name = option:match("^plugins%.var%.lua%." .. g.script.name .. "%.(.+)$")
   if name and g.defaults[name] then
      g.config[name] = get_or_set_option(name, g.defaults[name], value)
      if name == "colors" then
         action_shuffle_colors()
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
   if not plugin_name or
      not buffer_name or
      not tags:match(",log1,") then
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
            return left .. w.color(color) .. remove_initial_color(right)
          end
      end
   end
end

setup()

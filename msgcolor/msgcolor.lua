local w = weechat
local g = {
   script = {
      name = "msgcolor",
      author = "tomoe-mami <https://github.com/tomoe-mami",
      version = "0.1",
      license = "WTFPL",
      description = "Colors"
   },
   config = {
      color_list = { 1, 2, 3, 4, 5, 6, 7 }
   },
   color_index = 1
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

   load_config()
   setup_already_opened_buffers()

   w.hook_config("plugins.var.lua." .. g.script.name .. ".*", "config_cb", "")
   w.hook_signal("irc_channel_opened", "buffer_cb", "")
   w.hook_signal("irc_pv_opened", "buffer_cb", "")
   w.hook_modifier("weechat_print", "print_cb", "")
end

function load_config()
   if w.config_is_set_plugin("colors") ~= 1 then
      w.config_set_plugin("colors", table.concat(g.color_list, ","))
      w.config_set_desc_plugin("colors", "Color list for marker")
   else
      local opt_value = w.config_get_plugin("colors")
      if opt_value and opt_value ~= "" then
         set_color_list(opt_value)
      end
   end
end

function set_color_list(colors)
   local list = {}
   for color in colors:gmatch("([^,]+)") do
      table.insert(list, color)
   end
   g.color_list = list
end

function next_color()
   local current = g.color_index
   if g.color_index == #g.color_list then
      g.color_index = 1
   else
      g.color_index = g.color_index + 1
   end
   return g.color_list[current]
end

function setup_already_opened_buffers()
   local buf_list = w.infolist_get("buffer", "", "")
   if buf_list and buf_list ~= "" then
      g.color_index = math.random(1, #g.color_list)
      while w.infolist_next(buf_list) == 1 do
         local buffer = w.infolist_pointer(buf_list, "pointer")
         if buffer and buffer ~= "" then
            local p = w.buffer_get_string(buffer, "plugin")
            local t = w.buffer_get_string(buffer, "localvar_type")
            if p == "irc" and (t == "channel" or t == "private") then
               w.buffer_set(buffer, "localvar_set_color", next_color())
            end
         end
      end
   end
end

function config_cb(_, option, value)
   local prefix = "plugins.var.lua." .. g.script.name .. "."
   local name = option:match("^plugins%.var%.lua%." .. g.script.name .. "%.(.+)$")
   if name then
      if name == "colors" then
         set_color_list(value)
         setup_already_opened_buffers()
      end
   end
   return w.WEECHAT_RC_OK
end

function buffer_cb(_, signal, buffer)
   w.buffer_set(buffer, "localvar_set_color", next_color())
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

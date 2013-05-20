SCRIPT_NAME    = "buffer_mark"
SCRIPT_AUTHOR  = "rumia <https://github.com/rumia>"
SCRIPT_VERSION = "0.1"
SCRIPT_LICENSE = "WTFPL"
SCRIPT_DESCR   = "Uh.... Colorful marker for buffers! Yay!!"

color_list = { 1, 2, 3, 4, 5, 6, 7 }
marker = "❚ "
color_index = 0
prefix_align = "right"
prefix_max_length = 0
unicode_support = false

function w(name)
   if type(weechat[name]) == "function" then
      return weechat[name]()
   else
      return weechat[name]
   end
end

function module_exists(name)
  if package.loaded[name] then
    return true
  else
    for _, searcher in ipairs(package.searchers or package.loaders) do
      local loader = searcher(name)
      if type(loader) == "function" then
        package.preload[name] = loader
        return true
      end
    end
    return false
  end
end

function regular_string_length(s)
   return (s and type(s) == "string") and #s or 0
end

function setup()
   weechat.register(
      SCRIPT_NAME,
      SCRIPT_AUTHOR,
      SCRIPT_VERSION,
      SCRIPT_LICENSE,
      SCRIPT_DESCR,
      "", "")

   math.randomseed(os.time())

   load_config()
   setup_already_opened_buffers()
   unicode_support = module_exists("unicode")

   if unicode_support then
      require "unicode"
   end

   setup_string_handler()

   weechat.hook_config("*", "config_cb", "")
   weechat.hook_signal("irc_channel_opened", "buffer_cb", "")
   weechat.hook_signal("irc_pv_opened", "buffer_cb", "")
   weechat.hook_modifier("weechat_print", "print_cb", "")
end

function load_config()
   if weechat.config_is_set_plugin("string") ~= 1 then
      weechat.config_set_plugin("string", marker)
      weechat.config_set_desc_plugin("string", "Marker string")
   else
      marker = weechat.config_get_plugin("marker")
   end

   if weechat.config_is_set_plugin("colors") ~= 1 then
      weechat.config_set_plugin("colors", table.concat(color_list, ","))
      weechat.config_set_desc_plugin("colors", "Color list for marker")
   else
      local opt_value = weechat.config_get_plugin("colors")
      if opt_value and opt_value ~= "" then
         set_color_list(opt_value)
      end
   end

   local opt = weechat.config_get("weechat.look.prefix_align")
   prefix_align = weechat.config_string(opt)

   local opt = weechat.config_get("weechat.look.prefix_align_max")
   prefix_max_length = weechat.config_integer(opt)
end

function set_color_list(colors)
   color_list = {}
   for color in colors:gmatch("([^,]+)") do
      table.insert(color_list, color)
   end
end

function setup_string_handler()
   if prefix_align == "right" and unicode_support then
      string_length = unicode.utf8.len
   else
      string_length = regular_string_length
   end
end

function next_color()
   local current = color_index
   if color_index == #color_list then
      color_index = 1
   else
      color_index = color_index + 1
   end
   return color_list[current]
end

function setup_already_opened_buffers()
   local buf_list = weechat.infolist_get("buffer", "", "")
   if buf_list and buf_list ~= "" then
      color_index = math.random(1, #color_list)
      while weechat.infolist_next(buf_list) == 1 do
         local buffer = weechat.infolist_pointer(buf_list, "pointer")
         if buffer and buffer ~= "" then
            local p = weechat.buffer_get_string(buffer, "plugin")
            local t = weechat.buffer_get_string(buffer, "localvar_type")
            if p == "irc" and (t == "channel" or t == "private") then
               weechat.buffer_set(buffer, "localvar_set_color", next_color())
            end
         end
      end
   end
end

function config_cb(_, opt_full_name, opt_value)
   if opt_full_name == "plugins.var.lua." .. SCRIPT_NAME .. ".colors" then
      set_color_list(opt_value)
      setup_already_opened_buffers()
   elseif opt_full_name == "plugins.var.lua." .. SCRIPT_NAME .. ".string" then
      marker = opt_value
   elseif opt_full_name == "weechat.look.prefix_align" then
      prefix_align = opt_value
      setup_string_handler()
   elseif opt_full_name == "weechat.look.prefix_align_max" then
      prefix_max_length = tonumber(opt_value)
   end

   return w("WEECHAT_RC_OK")
end

function buffer_cb(_, signal, buffer)
   weechat.buffer_set(buffer, "localvar_set_color", next_color())
   return w("WEECHAT_RC_OK")
end

function pad_prefix(current_prefix)
   local marker_length = string_length(marker)
   if prefix_align ~= "right" or prefix_max_length < marker_length then
      return current_prefix
   else
      local stripped = weechat.string_remove_color(current_prefix, "")
      local current_length = string_length(stripped)
      local new_prefix_length = current_length + marker_length

      if new_prefix_length < prefix_max_length then
         local pad_count = prefix_max_length - new_prefix_length
         return string.rep(" ", pad_count) .. current_prefix
      else
         return current_prefix
      end
   end
end

function print_cb(_, modifier, data, text)
   local plugin_name, buffer_name, tags = data:match("([^;]+);([^;]+);(.+)")
   if not plugin_name or not buffer_name then
      return text
   end

   local buffer = weechat.buffer_search(plugin_name, buffer_name)
   if not buffer or buffer == "" then
      return text
   end

   local color = weechat.buffer_get_string(buffer, "localvar_color")
   if not color or color == "" then
      return text
   else
      if text:sub(1,2) == "\t\t" then
         return text
      else
         local prefix, message = text:match("^([^\t]*)\t(.*)$")
         if not prefix or not message then
            return text
         else
            return weechat.color(color) ..
                   marker ..
                   weechat.color("reset") ..
                   pad_prefix(prefix) ..
                   "\t" ..
                   message
          end
      end
   end
end

setup()

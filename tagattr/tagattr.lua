attributes = {}
strip_colors = false

function setup()
   weechat.register(
      "tagattr", "rumia <https://github.com/rumia>", "0.1", "WTFPL",
      "Apply attributes to message based on its tags",
      "", "")

   load_config()

   weechat.hook_modifier("weechat_print", "print_cb", "")
   weechat.hook_config("plugins.var.lua.tagattr.*", "config_cb", "")
end

function get_last_segment(text)
   return text:match("([^%.]+)$")
end

function load_config()
   local opt_filter = "plugins.var.lua.tagattr.tag.*"
   local opt_list = weechat.infolist_get("option", "", opt_filter)
   while weechat.infolist_next(opt_list) == 1 do
      local opt_name = weechat.infolist_string(opt_list, "option_name")
      local tag = get_last_segment(opt_name)
      attributes[tag] = weechat.infolist_string(opt_list, "value")
   end
   weechat.infolist_free(opt_list)

   if weechat.config_is_set_plugin("strip_colors") ~= 1 then
      weechat.config_set_plugin("strip_colors", 0)
   else
      local value = weechat.config_get_plugin("strip_colors")
      strip_colors = value == "1"
   end
end

function config_cb(_, opt_name, opt_value)
   if opt_name == "plugins.var.lua.tagattr.strip_colors" then
      strip_colors = opt_value == "1"
   elseif opt_name:find("plugins.var.lua.tagattr.tag.") then
      local tag = get_last_segment(opt_name)
      attributes[tag] = opt_value ~= "" and opt_value or nil
   end
end

function print_cb(_, modifier, modifier_data, text)
   local _, _, tags = modifier_data:match("([^;]+);([^;]+);(.+)")
   local attr = ""
   local prefix, message = text:match("^([^\t]*\t)(.+)$")
   if not message then
      prefix, message = "", text
   end

   if tags and tags ~= "" then
      for tag in tags:gmatch("([^,]+)") do
         if attributes[tag] then
            attr = attr .. weechat.color(attributes[tag])
            if tag == "irc_action" then
               local nick, actual_message = message:match("^([^%s]+%s+)(.+)$")
               prefix = prefix .. nick
               message = actual_message
            end
         end
      end
   end

   if strip_colors then
      message = weechat.string_remove_color(message, "")
   end
   local result = prefix .. attr .. message
   return result
end

setup()

colors, prefixes, suffixes = {}, {}, {}
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

function parse_option(name, value)
   local kind, key = name:match("([^%.]+)%.([^%.]+)$")
   if kind and key then
      if kind == "misc" and key == "strip_colors" then
         strip_colors = (value == "1")
      elseif kind == "color" then
         colors[key] = value ~= "" and value or nil
      elseif kind == "prefix" or kind == "suffix" then
         if value == "" then
            value = nil
         else
            local text, color = value:match("^([^;]+);(.+)$")
            if not text or not color then
               text, color = value, "default"
            end
            value = { text, color }
         end

         if kind == "prefix" then
            prefixes[key] = value
         else
            suffixes[key] = value
         end
      end
   end
end

function load_config()
   local strip_colors_not_set = true
   local opt_filter = "plugins.var.lua.tagattr.*"
   local opt_list = weechat.infolist_get("option", "", opt_filter)

   while weechat.infolist_next(opt_list) == 1 do
      local opt_name = weechat.infolist_string(opt_list, "option_name")
      local opt_value = weechat.infolist_string(opt_list, "value")
      parse_option(opt_name, opt_value)
   end

   weechat.infolist_free(opt_list)
   if weechat.config_is_set_plugin("strip_colors") ~= 1 then
      weechat.config_set_plugin("strip_colors", 0)
   end
end

function config_cb(_, opt_name, opt_value)
   parse_option(opt_name, opt_value)
end

function print_cb(_, modifier, modifier_data, text)
   local _, _, tags = modifier_data:match("([^;]+);([^;]+);(.+)")
   local left, right = text:match("^([^\t]*\t)(.+)$")
   if not right then
      left, right = "", text
   end

   local msg_prefixes, msg_color, msg_suffixes = "", "", ""
   local is_action = false

   if tags and tags ~= "" then
      for tag in tags:gmatch("([^,]+)") do

         if tag == "irc_action" then
            is_action = true
         end

         if colors[tag] then
            msg_color = weechat.color(colors[tag])
         end

         if prefixes[tag] then
            msg_prefixes = msg_prefixes ..
                           weechat.color(prefixes[tag][2]) ..
                           prefixes[tag][1] .. " "
         end

         if suffixes[tag] then
            msg_suffixes = msg_suffixes .. " " ..
                           weechat.color(suffixes[tag][2]) ..
                           suffixes[tag][1]
         end

      end
      if #msg_prefixes > 0 then
         msg_prefixes = msg_prefixes .. weechat.color("reset")
      end
      if #msg_suffixes > 0 then
         msg_suffixes = msg_suffixes .. weechat.color("reset")
      end
   end

   if strip_colors then
      right = weechat.string_remove_color(right, "")
   end
   if is_action then
      local nick, actual_message = right:match("^([^%s]+%s+)(.*)$")
      return left .. msg_prefixes .. nick .. msg_color ..
             actual_message .. msg_suffixes
   else
      return left .. msg_prefixes .. msg_color .. right .. msg_suffixes
   end
end

setup()

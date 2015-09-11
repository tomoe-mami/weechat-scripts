w, script_name, table.unpack = weechat, "userlabel", table.unpack or unpack

g = {
   config = {}
}

function empty(v)
   return not v or v == ""
end

function print(...)
   w.print("", script_name.."\t"..string.format(...))
end

function wc_match_old(s, p)
   p = p:lower():gsub("([^a-z0-9_!@*])", "%%%1"):gsub("%*", ".*")
   return s:lower():match(p)
end

function wc_match_new(s, p)
   return w.string_match(s, p, 0) == 1
end

function completion_context_old(buffer)
   local input, base_word, prev_arg = w.buffer_get_string(buffer, "input")
   input = input:match("^%S+%s*(.*)$")
   local base_word = input:match("(%S+)$")
   if base_word then
      prev_arg = input:match("(%S+)%s+%S+$")
   else
      prev_arg = input:match("(%S+)%s*$")
   end
   return base_word, prev_arg
end

function completion_context_new(buffer, completion)
   local args, base_word, prev_arg = w.hook_completion_get_string(completion, "args")
   local base_word = w.hook_completion_get_string(completion, "base_word")
   if base_word == "" then
      base_word = nil
      prev_arg = args:match("(%S+)%s*$")
   else
      prev_arg = args:match("(%S+)%s+%S+$")
   end
   return base_word, prev_arg
end

function main()
   if w.register(script_name, "singalaut", "0.1", "WTFPL",
      "Append label to messages displayed on buffer", "unload_cb", "") then

      if not check_weechat_version() then
         return
      end

      g.config = config_init()
      if empty(g.config) or empty(g.config.file) then
         return
      end
      config_read()
      w.hook_completion("userlabel_masks", "List of masks", "completion_masks_cb", "")
      w.hook_completion("userlabel_value", "Current label for a mask", "completion_value_cb", "")
      w.hook_command(
         script_name,
         "Manage user labels. Without argument this command will display all user labels.",
         "list"..
         " || set <mask> <label>"..
         " || get <mask>"..
         " || del <mask>"..
         " || match <subject>",
[[
     list: List all user labels
      set: Set user label for a mask
      get: Get current label for a mask
      del: Remove a mask
    match: Find all labels for the specified subject
   <mask>: nick!user@host mask with wildcards ("*"). Each part can be omitted but
           !user and @host can not appear before nick and @host can not appear before
           !user. For example:

           nick            -- correct
           !user@host      -- correct
           *@host!user     -- incorrect
           !user           -- correct
           *!user@*        -- same as above
           @host           -- correct

<subject>: nick!user@host without wildcards. Syntax is the same with <mask>
  <label>: Value of the of user label. Content is evaluated (see `/help eval`).
]],

         "get|del %(userlabel_masks)|%* || set %(userlabel_masks) %(userlabel_value) || match|list %-",
         "command_cb", "")

      w.hook_signal("buffer_line_added", "new_line_cb", "")
   end
end

function check_weechat_version()
   local wee_ver = tonumber(w.info_get("version_number", "") or 0)
   if wee_ver < 0x00030700 then
      print("%sYour WeeChat is OUTDATED!!!", w.color("*red"))
      return
   end

   if wee_ver < 0x10000000 then
      -- weechat < 1.0: * in the middle of string isn't treated as wildcard
      wc_match = wc_match_old
   else
      wc_match = wc_match_new
   end

   if wee_ver < 0x1030000 then
      -- weechat < 1.3: weechat.hook_completion_get_string is documented but
      -- does not exist inside script
      completion_context = completion_context_old
   else
      completion_context = completion_context_new
   end
   return true
end

function config_init()
   local conf = {}

   conf.file = w.config_new(script_name, "config_reload_cb", "")
   if empty(conf.file) then
      return
   end

   local conf_struct = {
      -- we use option type "string" here because i hate option type "color"
      color = {
         text = {
            "string",
            "Color for text of label (See https://weechat.org/doc/api#_color)",
            "", 0, 0, "darkgray,default", "darkgray,default", 0,
            "", "", "", "", "", ""
         },
         prefix = {
            "string",
            "Color for label prefix (See https://weechat.org/doc/api#_color)",
            "", 0, 0, "darkgray,default", "darkgray,default", 0,
            "", "", "", "", "", ""
         },
         suffix = {
            "string",
            "Color for label suffix (See https://weechat.org/doc/api#_color)",
            "", 0, 0, "darkgray,default", "darkgray,default", 0,
            "", "", "", "", "", ""
         }
      },
      look = {
         conditions = {
            "string",
            "Conditions for applying label. Value is evaluated (see `/help eval`). "..
            "Extra variables for expression are: ${line_data} (data of current line), "..
            "${tags}, ${total_tags} and ${host}",
            "", 0, 0, 
            "${buffer.plugin.name} == irc && (${type} == channel || ${type} == private)",
            "${buffer.plugin.name} == irc && (${type} == channel || ${type} == private)",
            1,
            "", "", "", "", "", ""
         },
         position = {
            "integer", "Position of label",
            "prefix_start|prefix_end|message_start|message_end", 0, 3,
            "message_end", "message_end", 0,
            "", "", "", "", "", ""
         },
         prefix = {
            "string", "Text that will be displayed before every label",
            "", 0, 0, "[", "[", 1,
            "", "", "", "", "", ""
         },
         suffix = {
            "string", "Text that will be displayed after every label",
            "", 0, 0, "]", "]", 1,
            "", "", "", "", "", ""
         }
      }
   }

   conf.section, conf.option = {}, {}
   for section_name, options in pairs(conf_struct) do
      conf.section[section_name] = w.config_new_section(
         conf.file, section_name, 0, 0, "", "", "", "", "", "",
         "", "", "", "")

      if empty(conf.section[section_name]) then
         w.config_free(conf.file)
         return
      end

      conf.option[section_name] = {}
      for option_name, info in pairs(options) do
         conf.option[section_name][option_name] = w.config_new_option(
            conf.file,
            conf.section[section_name],
            option_name,
            table.unpack(info))
      end
   end

   conf.section.mask = w.config_new_section(
      conf.file, "mask", 1, 1, "", "", "", "", "", "",
      "config_new_mask_cb", "",
      "config_del_mask_cb", "")

   if empty(conf.section.mask) then
      w.config_free(conf.file)
      return
   end
   conf.option.mask = {}

   return conf
end

function config_new_mask_cb(_, file, section, option_name, value)
   local opt = w.config_search_option(file, section, option_name)
   if not empty(opt) then
      g.config.option.mask[option_name] = opt
      return w.config_option_set(opt, value, 1)
   else
      opt = w.config_new_option(
         file, section, option_name, "string", 
         "", "", 0, 0, "", value, 0,
         "", "", "", "", "", "")
      if empty(opt) then
         return w.WEECHAT_CONFIG_OPTION_SET_ERROR
      end
      g.config.option.mask[option_name] = opt
      return w.WEECHAT_CONFIG_OPTION_SET_OK_SAME_VALUE
   end
end

function config_del_mask_cb(_, file, section, option)
   local name = w.hdata_string(w.hdata_get("config_option"), option, "name")
   if not empty(name) then
      if g.config.option.mask[name] then
         g.config.option.mask[name] = nil
      end
      w.config_option_free(option)
      return w.WEECHAT_CONFIG_OPTION_UNSET_OK_REMOVED
   else
      return w.WEECHAT_CONFIG_OPTION_UNSET_ERROR
   end
end

function config_reload_cb(_, file)
   return w.config_reload(file)
end

function config_read()
   return w.config_read(g.config.file)
end

function config_write()
   return w.config_write(g.config_file)
end

function new_line_cb(_, _, line_ptr)
   local h_line, h_line_data = w.hdata_get("line"), w.hdata_get("line_data")
   local ptr, var = {}, {}

   ptr.line_data = w.hdata_pointer(h_line, line_ptr, "data")
   if empty(ptr.line_data) then
      return w.WEECHAT_RC_OK
   end
   ptr.buffer = w.hdata_pointer(h_line_data, ptr.line_data, "buffer")
   var.total_tags = w.hdata_integer(h_line_data, ptr.line_data, "tags_count")
   local tag_list, nick, userhost = {}
   for i = 0, var.total_tags - 1 do
      local tag = w.hdata_string(h_line_data, ptr.line_data, i.."|tags_array")
      local tag_prefix = tag:sub(1, 5)
      if tag_prefix == "nick_" then
         nick = tag:sub(6)
      elseif tag_prefix == "host_" then
         userhost = tag:sub(6)
      end
      table.insert(tag_list, tag)
   end
   var.tags = ","..table.concat(tag_list, ",")..","

   if not nick and not userhost then
      return w.WEECHAT_RC_OK
   end

   -- info_get_hashtable parses nick!user@host as "host" so we'll just call it that too :)
   var.host = string.format("%s!%s", nick or "", userhost or "")

   local options = g.config.option
   local conditions = w.config_string(options.look.conditions)
   if not empty(conditions) then
      local result = w.string_eval_expression(conditions, ptr, var, {type = "condition"})
      if result == "0" then
         return w.WEECHAT_RC_OK
      end
   end

   local labels = get_matching_labels(var.host, { eval = true, ptr = ptr, var = var })
   if #labels > 0 then
      local joined_labels = w.color("reset")..table.concat(labels)..w.color("reset") 
      w.hook_timer(500, 0, 1, "modify_message_cb", ptr.line_data..";"..joined_labels)
   end
   return w.WEECHAT_RC_OK
end

function parse_host(s)
   local t = {}
   t.nick = s:match("^([^!@]+)")
   if t.nick then
      s = s:sub(#t.nick + 1)
      if not s or s == "" then
         return t
      end
   end
   t.user = s:match("^!([^@]+)")
   if t.user then
      s = s:sub(#t.user + 2)
      if not s or s == "" then
         return t
      end
   end
   t.host = s:match("^@(.+)")
   return t
end

function get_matching_labels(host, o)
   local o = o or {}
   local labels, options, text_color, prefix, suffix = {}, g.config.option
   local p = parse_host(host)
   host = string.format("%s!%s@%s", p.nick or "", p.user or "", p.host or "")
   if o.eval then
      text_color = w.color(w.config_string(options.color.text))
      prefix = w.color(w.config_string(options.color.prefix))..
               w.config_string(options.look.prefix)
      suffix = w.color(w.config_string(options.color.suffix))..
               w.config_string(options.look.suffix)
   end
   for mask, opt in pairs(options.mask) do
      local mp = parse_host(mask)
      local new_mask = string.format("%s!%s@%s", mp.nick or "*", mp.user or "*", mp.host or "*")
      if wc_match(host, new_mask) then
         local value = w.config_string(opt)
         if o.eval then
            value = prefix..
                    text_color..
                    w.string_eval_expression(value, o.ptr or {}, o.var or {}, {})..
                    suffix
         end
         if o.include_mask then
            value = { mask, value }
         end
         table.insert(labels, value)
      end
   end
   return labels
end

function modify_message_cb(param)
   local ptr, labels = param:match("^([^;]+);(.*)")
   if not empty(ptr) then
      local pos = w.config_string(g.config.option.look.position)
      local t, h_line_data = {}, w.hdata_get("line_data")
      local message = w.hdata_string(h_line_data, ptr, "message")
      local prefix = w.hdata_string(h_line_data, ptr, "prefix")
      if pos == "prefix_end" then
         t.prefix = prefix.." "..labels
      elseif pos == "prefix_start" then
         t.prefix = labels.." "..prefix
      elseif pos == "message_start" then
         t.message = labels.." "..message
      else
         t.message = message.." "..labels
      end
      w.hdata_update(h_line_data, ptr, t)
   end
   return w.WEECHAT_RC_OK
end

commands = {}

function commands.set(buffer, param)
   local mask, label = param:match("^(%S+)%s+(.+)")
   if empty(label) then
      return commands.get(buffer, param)
      -- print("Missing label")
      -- return w.WEECHAT_RC_ERROR
   end
   w.command(buffer, string.format("/set %s.mask.%s %s", script_name, mask, label))
   return w.WEECHAT_RC_OK
end

function commands.get(buffer, param)
   local mask_list = g.config.option.mask
   for mask in param:gmatch("(%S+)") do
      if mask_list[mask] then
         print("mask  = %s\nlabel = %s", mask, w.config_string(mask_list[mask]))
      end
   end
   return w.WEECHAT_RC_OK
end

function commands.del(buffer, param)
   local mask_list = g.config.option.mask
   for mask in param:gmatch("(%S+)") do
      if mask_list[mask] then
         w.command(buffer, string.format("/unset %s.mask.%s", script_name, mask))
      end
   end
   return w.WEECHAT_RC_OK
end

function commands.list(buffer)
   local mask_list = g.config.option.mask
   print("All labels:")
   for mask, opt in pairs(mask_list) do
      print("   %s = %s\n", mask, w.config_string(opt))
   end
   return w.WEECHAT_RC_OK
end

function commands.match(buffer, param)
   local labels = get_matching_labels(param, { include_mask = true })
   if #labels == 0 then
      print("Nothing matched with %s", param)
   else
      print("Label(s) for %s:", param)
      for _, v in ipairs(labels) do
         print("  %s = %s", v[1], v[2])
      end
   end
   return w.WEECHAT_RC_OK
end

function command_cb(_, buffer, param)
   local cmd, args = param:match("^(%S+)%s*(.*)$")
   if empty(cmd) then
      cmd = "list"
   end
   if not commands[cmd] then
      print("Unknown command: %s", cmd)
      return w.WEECHAT_RC_ERROR
   else
      return commands[cmd](buffer, args)
   end
end

function completion_masks_cb(_, item, buffer, completion)
   local mask_list = g.config.option.mask
   local base_word = completion_context(buffer, completion)
   for mask, opt in pairs(mask_list) do
      if not base_word or mask:sub(1, #base_word) == base_word then
         w.hook_completion_list_add(completion, mask, 0, w.WEECHAT_LIST_POS_SORT)
      end
   end
   return w.WEECHAT_RC_OK
end

function completion_value_cb(_, item, buffer, completion)
   local base_word, mask = completion_context(buffer, completion)
   local mask_list = g.config.option.mask
   if not empty(mask) and mask_list[mask] then
      local current_value = w.config_string(mask_list[mask])
      if not base_word or current_value:sub(1, #base_word) == base_word then
         w.hook_completion_list_add(completion, current_value, 0, w.WEECHAT_LIST_POS_END)
      end
   end
   return w.WEECHAT_RC_OK
end

function unload_cb()
   if not empty(g.config.file) then
      config_write()
   end
   return w.WEECHAT_RC_OK
end

main()

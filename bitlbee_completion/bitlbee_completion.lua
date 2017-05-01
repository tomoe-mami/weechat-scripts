w, script_name = weechat, "bitlbee_completion"

g = {
   config_buffer = "",
   server = {},
   hooks = {},
   queue = {}
}

function main()
   local reg_ok = w.register(
      script_name, "singalaut <https://github.com/tomoe-mami>",
      "0.1", "WTFPL", "", "", "")
   if reg_ok then
      init_config()
      find_buffers()
      w.hook_completion("bitlbee", "", "completion_commands_cb", "")
      w.hook_signal("irc_channel_opened", "irc_new_buffer_cb", "")
      w.hook_signal("irc_pv_opened", "irc_new_buffer_cb", "")
      w.hook_signal("irc_server_connected", "irc_connected_cb", "")
      w.hook_signal("buffer_closing", "buffer_closing_cb", "")
   end
end

function init_config()
   local value = "irc.localhost.&bitlbee,irc.localhost.root"
   if w.config_is_set_plugin("buffer") == 1 then
      value = w.config_get_plugin("buffer")
   else
      w.config_set_plugin("buffer", value)
      w.config_set_desc_plugin("buffer", [[
Comma separated list of Bitlbee buffers that will have completion support.
Wildcard (*) is allowed. Name beginning with ! is excluded.]])
   end
   g.config_buffer = value
   w.hook_config("plugins.var.lua."..script_name..".buffer", "config_cb", "")

   local comp_template = w.config_string(w.config_get("weechat.completion.default_template"))
   if not comp_template:find("%(bitlbee)", 1, true) then
      w.print_date_tags(
         "", 0, "notify_highlight",
         string.format([[
%s[%s]: Please add %%(bitlbee) to Weechat's default completion template.
For example:

    /set weechat.completion.default_template "%s|%%(bitlbee)"

]], w.prefix("network"), script_name, comp_template))
   end
end

function config_cb(_, _, value)
   g.config_buffer = value
   find_buffers()
   return w.WEECHAT_RC_OK
end

function hook_mod(mod_name, server_name, callback)
   g.hooks[mod_name.."/"..server_name] = w.hook_modifier(mod_name, callback, server_name)
end

function unhook_mod(mod_name, server_name)
   local key = mod_name.."/"..server_name
   local ptr_hook = g.hooks[key]
   if ptr_hook and ptr_hook ~= "" then
      g.hooks[key] = nil
      w.unhook(ptr_hook)
   end
end

function find_buffers()
   local h_buffer = w.hdata_get("buffer")
   local mask = g.config_buffer
   local ptr_buffer = w.hdata_get_list(h_buffer, "gui_buffers")
   while ptr_buffer ~= "" do
      if w.buffer_get_string(ptr_buffer, "plugin") == "irc" and
         w.buffer_match_list(ptr_buffer, mask) == 1 then
         collect_completions(w.buffer_get_string(ptr_buffer, "localvar_server"))
      end
      ptr_buffer = w.hdata_pointer(h_buffer, ptr_buffer, "next_buffer")
   end
end

function collect_completions(server_name)
   if not server_name or server_name == "" or g.server[server_name] then
      return
   end
   g.server[server_name] = {}
   local ptr_server, is_connected, ptr_buffer = find_server(server_name)
   if not ptr_server then
      return
   end
   if not is_connected then
      g.queue[server_name] = true
   else
      g.queue[server_name] = nil
      hook_mod("irc_in_notice", server_name, "comp_notice_cb")
      hook_mod("irc_in_421", server_name, "err_unknown_cmd_cb")
      w.command(ptr_buffer, "/quote COMPLETIONS")
   end
end

function find_server(name)
   local h_server = w.hdata_get("irc_server")
   local ptr_server = w.hdata_search(
      h_server, w.hdata_get_list(h_server, "irc_servers"),
      "${irc_server.name} == "..name, 1)
   if ptr_server and ptr_server ~= "" then
      return ptr_server,
             w.hdata_integer(h_server, ptr_server, "is_connected") == 1,
             w.hdata_pointer(h_server, ptr_server, "buffer")
   end
end

function err_unknown_cmd_cb(req_server_name, _, server_name, irc_message)
   if req_server_name == server_name then
      unhook_mod("irc_in_421", server_name)
      unhook_mod("irc_in_notice", server_name)
      g.server[server_name] = nil
      return ""
   end
   return irc_message
end

function comp_notice_cb(req_server_name, _, server_name, irc_message)
   if req_server_name ~= server_name then
      return irc_message
   end
   local server = g.server[server_name]
   if not server or type(server) ~= "table" then
      return irc_message
   end
   local our_nick = w.info_get("irc_nick", server_name)
   local parsed = w.info_get_hashtable(
      "irc_message_parse",
      { server = server_name, message = irc_message })

   if not parsed or type(parsed) ~= "table" or
      not parsed.nick or parsed.nick == "" or
      not parsed.channel or parsed.channel ~= our_nick or
      not parsed.text or parsed.text == "" or
      parsed.text:sub(1, 12) ~= "COMPLETIONS " then
      return irc_message
   end

   unhook_mod("irc_in_421", server_name)
   local command = parsed.text:sub(13)
   if command == "OK" then
      server.bitlbot = parsed.nick
      server.commands = {}
   elseif command == "END" then
      unhook_mod("irc_in_notice", server_name)
   else
      comp_add_command(server.commands, command)
   end
   return ""
end

function comp_add_command(t, command)
   local left, right = command:match("^(%S+)%s*(.*)$")
   if not t[left] then
      t[left] = true
   end
   if right and right ~= "" then
      if type(t[left]) ~= "table" then
         t[left] = {}
      end
      comp_add_command(t[left], right)
   end
end

function completion_commands_cb(_, _, ptr_buffer, ptr_comp)
   if w.buffer_match_list(ptr_buffer, g.config_buffer) == 0 then
      return w.WEECHAT_RC_OK
   end
   local server_name = w.buffer_get_string(ptr_buffer, "localvar_server")
   local server = g.server[server_name]
   if not server or type(server) ~= "table" or not server.commands then
      return w.WEECHAT_RC_OK
   end
   local input = w.buffer_get_string(ptr_buffer, "input"):lower()
   local h_comp = w.hdata_get("completion")
   local base_word = w.hdata_string(h_comp, ptr_comp, "base_word"):lower()
   local base_word_pos = w.hdata_integer(h_comp, ptr_comp, "base_word_pos")
   input = input:sub(1, base_word_pos + #base_word)
   if input:sub(1, #server.bitlbot) == server.bitlbot:lower() then
      local next_pos = #server.bitlbot + 1
      local completer = input:sub(next_pos, next_pos)
      if completer == ":" or completer == "," then
         input = input:sub(next_pos + 1)
      end
   end
   input = input:gsub("^%s+", ""):gsub("%s+$", "")
   local list = server.commands
   if input ~= base_word then
      local before = input:sub(1, #input - #base_word)
      for seg in before:gmatch("(%S+)") do
         if not list or type(list) ~= "table" then
            break
         end
         list = list[seg]
      end
   end
   if list and type(list) == "table" then
      for word, _ in pairs(list) do
         if word:sub(1, #base_word) == base_word then
            w.hook_completion_list_add(ptr_comp, word, 0, w.WEECHAT_LIST_POS_SORT)
         end
      end
   end
   return w.WEECHAT_RC_OK
end

function irc_new_buffer_cb(_, _, ptr_buffer)
   if w.buffer_match_list(ptr_buffer, g.config_buffer) == 1 then
      collect_completions(w.buffer_get_string(ptr_buffer, "localvar_server"))
   end
   return w.WEECHAT_RC_OK
end

function irc_connected_cb(_, _, server_name)
   if g.queue[server_name] then
      collect_completions(server_name)
   end
   return w.WEECHAT_RC_OK
end

function buffer_closing_cb(_, _, ptr_buffer)
   if w.buffer_get_string(ptr_buffer, "plugin") == "irc" and
      w.buffer_get_string(ptr_buffer, "localvar_type") == "server" then
      local server_name = w.buffer_get_string(ptr_buffer, "server")
      if g.server[server_name] then
         g.server[server_name] = nil
      end
      g.queue[server_name] = nil
   end
   return w.WEECHAT_RC_OK
end

main()

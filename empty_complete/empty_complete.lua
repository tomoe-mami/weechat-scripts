w, script_name = weechat, "empty_complete"
g = {
   config = {},
   defaults = {
      ignore_offline_nicks = { "on", "Ignore nicks who already left the channel" },
      ncw_compat = { "on", "Enable compatibility with script nick_complete_wrapper.lua" }
   },
   buffers = {}
}

function main()
   local reg_ok = w.register(
      script_name,
      "singalaut <https://github.com/tomoe-mami>",
      "0.1",
      "WTFPL",
      "Tab complete empty input line with recently active nicks in a channel",
      "", "")

   if reg_ok then
      init_config()
      w.hook_command_run("/input complete*", "complete_cb", "")
      w.hook_modifier("history_add", "history_add_cb", "")
      w.hook_signal("buffer_closed", "buffer_closed_cb", "")
   end
end

function init_config()
   g.config.nick_completer = w.config_get("weechat.completion.nick_completer")
   g.config.nick_space = w.config_get("weechat.completion.nick_add_space")

   for name, info in pairs(g.defaults) do
      if w.config_is_set_plugin(name) == 1 then
         config_cb(nil, name, w.config_get_plugin(name))
      else
         w.config_set_plugin(name, info[1])
         w.config_set_desc_plugin(name, info[2])
         config_cb(nil, name, info[1])
      end
   end
   w.hook_config("plugins.var.lua."..script_name..".*", "config_cb", "")
end

function config_cb(_, opt_name, opt_value)
   opt_name = opt_name:gsub("^plugins%.var%.lua%."..script_name.."%.", "")
   if g.defaults[opt_name] then
      opt_value = w.config_string_to_boolean(opt_value) == 1
      g.config[opt_name] = opt_value
   end
   return w.WEECHAT_RC_OK
end

function find_server(server_name)
   local h_server = w.hdata_get("irc_server")
   local ptr_server = w.hdata_get_list(h_server, "irc_servers")
   if type(w.hdata_search) == "function" then
      return h_server,
             w.hdata_search(h_server, ptr_server,
                            "${irc_server.name} == "..server_name, 1)
   else
      while ptr_server and ptr_server ~= "" do
         if w.hdata_string(h_server, ptr_server, "name") == server_name then
            return h_server, ptr_server
         end
         ptr_server = w.hdata_pointer(h_server, ptr_server, "next_server")
      end
   end
end

function get_recent_speakers(server_name, channel_name)
   local h_server, server = find_server(server_name)
   if not server or server == "" then
      return
   end

   local h_channel = w.hdata_get("irc_channel")
   local channel, found = w.hdata_pointer(h_server, server, "channels"), false
   while channel and channel ~= "" do
      if w.hdata_string(h_channel, channel, "name") == channel_name then
         return w.hdata_pointer(h_channel, channel, "nicks_speaking")
      end
      channel = w.hdata_pointer(h_channel, channel, "next_channel")
   end
end

function complete_cb(_, ptr_buf, cmd)
   if w.buffer_get_string(ptr_buf, "plugin") ~= "irc" or
      w.buffer_get_string(ptr_buf, "localvar_type") ~= "channel" then
      return w.WEECHAT_RC_OK
   end
   local dir = cmd:match("^/input complete_(.+)$")
   if dir ~= "next" and dir ~= "previous" then
      return w.WEECHAT_RC_OK
   end
   local input_text = w.buffer_get_string(ptr_buf, "input")
   if w.string_is_command_char(input_text) == 1 then
      return w.WEECHAT_RC_OK
   end

   local input_length = w.buffer_get_integer(ptr_buf, "input_size")
   local server_name = w.buffer_get_string(ptr_buf, "localvar_server")
   local channel_name = w.buffer_get_string(ptr_buf, "localvar_channel")

   local buffer = g.buffers[ptr_buf]
   if not buffer then
      if input_length > 0 then
         return w.WEECHAT_RC_OK
      end
      buffer = { speakers = get_recent_speakers(server_name, channel_name) }
      if not buffer.speakers or buffer.speakers == "" then
         return w.WEECHAT_RC_OK
      end
      g.buffers[ptr_buf] = buffer
   elseif input_length == 0 then
      buffer.index = nil
   elseif input_text ~= buffer.last_nick then
      g.buffers[ptr_buf] = nil
      return w.WEECHAT_RC_OK
   end

   local nick = get_speaker(ptr_buf, buffer, dir)
   if nick and nick ~= "" then
      buffer.last_nick = nick..w.config_string(g.config.nick_completer)
      if g.config.ncw_compat then
         buffer.last_nick = w.buffer_get_string(ptr_buf, "localvar_ncw_prefix")..
                            buffer.last_nick..
                            w.buffer_get_string(ptr_buf, "localvar_ncw_suffix")
      end
      if w.config_boolean(g.config.nick_space) == 1 then
         buffer.last_nick = buffer.last_nick.." "
      end
      w.buffer_set(ptr_buf, "input", buffer.last_nick)
      w.command(ptr_buf, "/input move_end_of_line")
   end
   return w.WEECHAT_RC_OK
end

function get_speaker(ptr_buf, buffer, dir)
   local total = w.list_size(buffer.speakers)
   if total == 0 then
      return
   end

   local last = total - 1
   if not buffer.index then
      buffer.index = dir == "next" and last or 0
   else
      buffer.index = (buffer.index + (dir == "next" and -1 or 1)) % total
   end

   if not g.config.ignore_offline_nicks then
      return w.list_string(w.list_get(buffer.speakers, buffer.index))
   else
      local p
      if dir == "next" then
         p = {{ buffer.index, 0, -1 }, { 0, buffer.index - 1, 1 }}
      else
         p = {{ buffer.index, last , 1 }, { last, buffer.index + 1, -1 }}
      end

      for _, a in ipairs(p) do
         for i = a[1], a[2], a[3] do
            local val = w.list_string(w.list_get(buffer.speakers, i))
            if w.nicklist_search_nick(ptr_buf, "", val) ~= "" then
               buffer.index = i
               return val
            end
         end
      end
   end
end

function history_add_cb(_, _, ptr_buf, text)
   if g.buffers[ptr_buf] then
      g.buffers[ptr_buf].index = nil
      g.buffers[ptr_buf].last_nick = nil
   end
   return text
end

function buffer_closed_cb(_, _, ptr_buf)
   if g.buffers[ptr_buf] then
      g.buffers[ptr_buf] = nil
   end
   return w.WEECHAT_RC_OK
end

main()

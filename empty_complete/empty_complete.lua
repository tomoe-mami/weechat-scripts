w, script_name = weechat, "empty_complete"
g = {
   config = {
      nick_completer = ":",
      nick_space = " "
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
      g.config.nick_completer = w.config_string(w.config_get("weechat.completion.nick_completer"))
      local add_space = w.config_boolean(w.config_get("weechat.completion.nick_add_space"))
      g.config.nick_space = add_space and " " or ""

      w.hook_config("weechat.completion.nick_completer", "config_cb", "")
      w.hook_config("weechat.completion.nick_add_space", "config_cb", "")
      w.hook_command_run("/input complete*", "complete_cb", "")
      w.hook_modifier("history_add", "history_add_cb", "")
      w.hook_signal("buffer_closed", "buffer_closed_cb", "")
   end
end

function config_cb(_, opt_name, opt_value)
   if opt_name == "weechat.completion.nick_completer" then
      g.config.nick_completer = opt_value
   elseif opt_name == "weechat.completion.nick_add_space" then
      g.config.nick_space = w.config_string_to_boolean(opt_value) == 1 and " " or ""
   end
   return w.WEECHAT_RC_OK
end

function get_recent_speakers(server_name, channel_name)
   local h_server = w.hdata_get("irc_server")
   local server = w.hdata_search(
      h_server,
      w.hdata_get_list(h_server, "irc_servers"),
      "${irc_server.name} == "..server_name,
      1)

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
   elseif input_length == 0 then
      buffer.index = nil
   elseif input_text ~= buffer.last_nick then
      g.buffers[ptr_buf] = nil
      return w.WEECHAT_RC_OK
   end

   local total_speakers = w.list_size(buffer.speakers)
   if total_speakers == 0 then
      return w.WEECHAT_RC_OK
   end

   if not buffer.index then
      buffer.index = dir == "next" and (total_speakers - 1) or 0
   else
      buffer.index = (buffer.index + (dir == "next" and -1 or 1)) % total_speakers
   end
   buffer.last_nick = w.list_string(w.list_get(buffer.speakers, buffer.index))..
                      g.config.nick_completer..
                      g.config.nick_space

   w.buffer_set(ptr_buf, "input", buffer.last_nick)
   w.command(ptr_buf, "/input move_end_of_line")
   g.buffers[ptr_buf] = buffer

   return w.WEECHAT_RC_OK
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

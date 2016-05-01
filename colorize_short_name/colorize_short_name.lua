w, script_name = weechat, "colorize_short_name"

buffers = {}
nick_color_info = "irc_nick_color"
nick_color_opt_mask = "irc.look.nick_color*"

function main()
   local reg_ok = w.register(
      script_name,
      "singalaut <https://github.com/tomoe-mami>",
      "0.1",
      "WTFPL",
      "Colorize short_name of buffers",
      "", "")

   if reg_ok then
      w.hook_signal("buffer_opened", "change_short_name_cb", "open")
      w.hook_signal("buffer_renamed", "change_short_name_cb", "rename")
      w.hook_signal("irc_server_connected", "change_short_name_cb", "server")
      w.hook_signal("irc_channel_opened", "change_short_name_cb", "channel")
      w.hook_signal("irc_pv_opened", "change_short_name_cb", "channel")
      w.hook_config("weechat.color.chat_nick_colors", "config_cb", "")

      local wee_ver = tonumber(w.info_get("version_number", "") or 0)
      if wee_ver >= 0x01050000 then
         nick_color_info = "nick_color"
         nick_color_opt_mask = "weechat.look.nick_color*"
      end
      w.hook_config(nick_color_opt_mask, "config_cb", "")

      update_all_short_names()
   end
end

function change_short_name_cb(mode, _, buf_ptr)
   local orig_name
   if mode == "channel" then
      orig_name = w.buffer_get_string(buf_ptr, "localvar_channel")
   elseif mode == "server" then
      orig_name = buf_ptr
      buf_ptr = w.buffer_search("irc", "server."..orig_name)
   else
      orig_name = w.buffer_get_string(buf_ptr, "short_name")
   end
   if not buffers[buf_ptr] then
      buffers[buf_ptr] = true
      local stripped_name = w.string_remove_color(orig_name, "")
      local new_name = w.info_get(nick_color_info, stripped_name)..stripped_name
      if orig_name ~= new_name then
         w.buffer_set(buf_ptr, "short_name", new_name)
      end
      buffers[buf_ptr] = nil
   end
   return w.WEECHAT_RC_OK
end

function update_all_short_names()
   local hbuf = w.hdata_get("buffer")
   local buffer = w.hdata_get_list(hbuf, "gui_buffers")
   while buffer and buffer ~= "" do
      change_short_name_cb("rename", "", buffer)
      buffer = w.hdata_move(hbuf, buffer, 1)
   end
end

function config_cb()
   update_all_short_names()
   return w.WEECHAT_RC_OK
end

main()

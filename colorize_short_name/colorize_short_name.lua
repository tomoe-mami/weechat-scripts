w, script_name = weechat, "colorize_short_name"

buffers = {}

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
      w.hook_config("irc.look.nick_color*", "config_cb", "")

      update_all_short_names()
   end
end

function change_short_name_cb(mode, _, buf_ptr)
   if not buffers[buf_ptr] then
      buffers[buf_ptr] = true
      local orig_name
      if mode == "channel" then
         orig_name = w.buffer_get_string(buf_ptr, "localvar_channel")
      elseif mode == "server" then
         orig_name = buf_ptr
         buf_ptr = w.buffer_search("irc", "server."..orig_name)
      else
         orig_name = w.buffer_get_string(buf_ptr, "short_name")
      end
      local stripped_name = w.string_remove_color(orig_name, "")
      local new_name = w.info_get("irc_nick_color", stripped_name)..stripped_name
      if orig_name ~= new_name then
         w.buffer_set(buf_ptr, "short_name", new_name)
      end
   end
   buffers[buf_ptr] = nil
   return w.WEECHAT_RC_OK
end

function update_all_short_names()
   local list = w.infolist_get("buffer", "", "")
   if list ~= "" then
      while w.infolist_next(list) == 1 do
         local buf_ptr = w.infolist_pointer(list, "pointer")
         change_short_name_cb("rename", "", buf_ptr)
      end
      w.infolist_free(list)
   end
end

function config_cb()
   update_all_short_names()
   return w.WEECHAT_RC_OK
end

main()

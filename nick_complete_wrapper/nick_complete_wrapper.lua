w, script_name = weechat, "nick_complete_wrapper"
config, hooks = {}, {}

function main()
   assert(w.register(
      script_name, "singalaut", "0.1", "WTFPL",
      "Wraps nick completion with prefix and/or suffix",
      "", ""))

   for _, name in ipairs({"nick_add_space", "nick_completer"}) do
      config[name] = w.config_get("weechat.completion."..name)
   end
   w.hook_command_run("9000|/input complete_*", "complete_cb", "")
end

function get_completion(ptr_buffer)
   local t = {}
   local ptr_comp = w.hdata_pointer(w.hdata_get("buffer"), ptr_buffer, "completion")
   if ptr_comp and ptr_comp ~= "" then
      local h_comp = w.hdata_get("completion")
      t.start_pos = w.hdata_integer(h_comp, ptr_comp, "position_replace")
      t.word_found = w.hdata_string(h_comp, ptr_comp, "word_found")
      t.is_nick = w.hdata_integer(h_comp, ptr_comp, "word_found_is_nick") == 1
      t.is_command = w.hdata_string(h_comp, ptr_comp, "base_command") ~= ""
      return t
   end
end

function get_prefix_suffix(ptr_buffer)
   local t = {
      prefix = w.buffer_get_string(ptr_buffer, "localvar_ncw_prefix"),
      suffix = w.buffer_get_string(ptr_buffer, "localvar_ncw_suffix")
   }
   t.prefix_len = w.strlen_screen(t.prefix)
   t.suffix_len = w.strlen_screen(t.suffix)
   return t
end

function cleanup_previous_completion(ptr_buffer)
   local ps = get_prefix_suffix(ptr_buffer)
   if ps.prefix == "" and ps.suffix == "" then
      return w.WEECHAT_RC_OK
   end
   local comp = get_completion(ptr_buffer)
   if comp and comp.is_nick and not comp.is_command then
      local current_pos = w.buffer_get_integer(ptr_buffer, "input_pos")
      local add_space = w.config_boolean(config.nick_add_space)
      local word_length = ps.prefix_len +
                          w.strlen_screen(comp.word_found) +
                          ps.suffix_len +
                          add_space

      if comp.start_pos + word_length == current_pos then
         w.buffer_set(ptr_buffer, "completion_freeze", "1")
         if ps.suffix_len > 0 then
            if add_space then
               w.command(ptr_buffer, "/input move_previous_char")
            end
            for i = 1, ps.suffix_len do
               w.command(ptr_buffer, "/input delete_previous_char")
            end
         end
         if ps.prefix_len > 0 then
            w.buffer_set(ptr_buffer, "input_pos", comp.start_pos)
            for i = 1, ps.prefix_len do
               w.command(ptr_buffer, "/input delete_next_char")
            end
            w.buffer_set(ptr_buffer, "input_pos", current_pos - ps.prefix_len)
         end
         w.buffer_set(ptr_buffer, "completion_freeze", "0")
      end
   end
end

function complete_cb(_, ptr_buffer)
   cleanup_previous_completion(ptr_buffer)
   hooks[ptr_buffer] = w.hook_signal("input_text_changed", "input_changed_cb", ptr_buffer)
   return w.WEECHAT_RC_OK
end

function input_changed_cb(ptr_buffer)
   if not hooks[ptr_buffer] then
      return w.WEECHAT_RC_OK
   end
   w.unhook(hooks[ptr_buffer])
   hooks[ptr_buffer] = nil

   local ps = get_prefix_suffix(ptr_buffer)
   if ps.prefix == "" and ps.suffix == "" then
      return w.WEECHAT_RC_OK
   end

   local comp = get_completion(ptr_buffer)
   if not comp or comp.is_command or not comp.is_nick then
      return w.WEECHAT_RC_OK
   end
   local current_pos = w.buffer_get_integer(ptr_buffer, "input_pos")
   w.buffer_set(ptr_buffer, "completion_freeze", "1")
   if ps.suffix_len > 0 then
      if w.config_boolean(config.nick_add_space) == 1 then
         w.command(ptr_buffer, "/input move_previous_char")
      end
      w.command(ptr_buffer, "/input insert "..ps.suffix:gsub("\\", "\\\\"))
   end
   if ps.prefix_len > 0 then
      w.buffer_set(ptr_buffer, "input_pos", comp.start_pos)
      w.command(ptr_buffer, "/input insert "..ps.prefix:gsub("\\", "\\\\"))
      w.buffer_set(ptr_buffer, "input_pos", current_pos + ps.prefix_len + ps.suffix_len)
   end
   w.buffer_set(ptr_buffer, "completion_freeze", "0")

   return w.WEECHAT_RC_OK
end

main()

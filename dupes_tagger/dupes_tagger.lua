w, script_name = weechat, "dupes_tagger"
config = {}
defaults = {
   condition = { "${tags} =~ ,log1,", "Only check for lines that matched this condition. Content is evaluated (see /help eval)."},
   search_limit = { 1000, "Give up search after reaching this amount of lines but found no duplicate message." }
}

function main()
   local reg_ok = w.register(
      script_name, "singalaut <https://github.com/tomoe-mami>",
      "0.1", "WTFPL",
      "Add tag for duplicate message",
      "", "")

   if reg_ok then
      init_config()
      w.hook_signal("buffer_line_added", "line_added_cb", "")
   end
end

function init_config()
   for name, info in pairs(defaults) do
      local value
      if w.config_is_set_plugin(name) == 1 then
         config_cb(nil, name, w.config_get_plugin(name))
      else
         config[name] = info[1]
         w.config_set_plugin(name, info[1])
         w.config_set_desc_plugin(name, info[2])
      end
   end
   w.hook_config("plugins.var.lua." .. script_name .. ".*", "config_cb", "")
end

function config_cb(_, full_name, value)
   local name = full_name:gsub("^plugins%.var%.lua%." .. script_name .. "%.", "")
   if defaults[name] then
      if name == "search_limit" then
         value = tonumber(value)
         if not value or value < 1 then
            value = defaults[name][1]
         end
      end
      config[name] = value
   end
   return w.WEECHAT_RC_OK
end

function condition_matched(pointers, vars)
   return tonumber(w.string_eval_expression(config.condition, pointers, vars, { type = "condition" })) == 1
end

function get_data(h, ptr_line)
   local pointers = {
      line = ptr_line,
      line_data = w.hdata_pointer(h.line, ptr_line, "data")
   }
   pointers.buffer = w.hdata_pointer(h.line_data, pointers.line_data, "buffer")
   local tags_count = w.hdata_integer(h.line_data, pointers.line_data, "tags_count")
   local tags = {}
   if tags_count > 0 then
      for i = 0, tags_count do
         local tag = w.hdata_string(h.line_data, pointers.line_data, i .. "|tags_array")
         tags[#tags + 1] = tag
      end
   end
   local message = w.string_remove_color(w.hdata_string(h.line_data, pointers.line_data, "message"), "")
   local vars = {
      tags = "," .. table.concat(tags, ",") .. ",",
      message = message:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""),
   }
   return pointers, vars, tags
end

function line_added_cb(_, _, ptr_line)
   local h = {
      line = w.hdata_get("line"),
      lines = w.hdata_get("lines"),
      line_data = w.hdata_get("line_data"),
      buffer = w.hdata_get("buffer")
   }
   local pointers, vars, tags = get_data(h, ptr_line)
   if condition_matched(pointers, vars) then
      return process(h, pointers, vars, tags)
   end
   return w.WEECHAT_RC_OK
end

function process(h, new_ptrs, new_vars, new_tags)
   local count, search_limit = 0, config.search_limit
   local ptr_lines = w.hdata_pointer(h.buffer, new_ptrs.buffer, "lines")
   local ptr_line = w.hdata_pointer(h.lines, ptr_lines, "last_line")
   if ptr_line == "" then
      return w.WEECHAT_RC_OK
   end
   ptr_line = w.hdata_pointer(h.line, ptr_line, "prev_line")
   while ptr_line ~= "" do
      local pointers, vars = get_data(h, ptr_line)
      if condition_matched(pointers, vars) then
         if vars.message == new_vars.message then
            new_tags[#new_tags+1] = "duplicate"
            w.hdata_update(h.line_data, new_ptrs.line_data, { tags_array = table.concat(new_tags, ",") })
            break
         end
         count = count + 1
         if count > search_limit then
            break
         end
      end
      ptr_line = w.hdata_pointer(h.line, ptr_line, "prev_line")
   end
   return w.WEECHAT_RC_OK
end

main()

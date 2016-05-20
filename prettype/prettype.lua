local pcre = require "rex_pcre"
local utf8 = require "utf8"

local w = weechat
local g = {
   script = {
      name = "prettype",
      author = "tomoe-mami <https://github.com/tomoe-mami>",
      license = "WTFPL",
      version = "0.4",
      description = "Prettify text you typed with auto-capitalization and proper unicode symbols"
   },
   config = {},
   defaults = {
      buffers = {
         value = "irc.*,!irc.server.*,!*.nickserv,!*.chanserv,!*.memoserv",
         description =
            "A comma separated list of buffers where script will be active. " ..
            "Wildcard (*) is allowed. Prefix an entry with ! to exclude " ..
            "any buffer that matched with it."
      },
      escape_color = {
         value = "magenta",
         description = "Color for escaped text"
      }
   },
   diacritic_tags = {
      s = 0x0336,
      u = 0x0332,
   },
   utf8_flag = pcre.flags().UTF8
}

function u(...)
   local result = ""
   for _, c in ipairs(arg) do
      if type(c) == "number" then
         c = utf8.char(c)
      end
      result = result .. c
   end
   return result
end

ESC = u(0xfffa)
PHOLD_START = u(0xfff9)
PHOLD_END = u(0xfffb)
ESC_RE = "\\x{fffa}"
PHOLD_START_RE = "\\x{fff9}"
PHOLD_END_RE = "\\x{fffb}"

function combine(tag, text)
   if not g.diacritic_tags[tag] then
      return text
   end
   return pcre.gsub(
      text,
      "(.)",
      u("%1", g.diacritic_tags[tag]),
      nil,
      g.utf8_flag)
end

function title_case(s)
   return pcre.gsub(
      s,
      "(?<=^|[^\\pL\\pN])(\\pL)",
      function (char)
         return utf8.upper(char)
      end,
      nil,
      g.utf8_flag)
end

function replace_patterns(text)
   for _, p in ipairs(g.replacements) do
      text = pcre.gsub(text, p[1], p[2], nil, g.utf8_flag)
   end
   return text
end

function is_valid_buffer(buffer)
   return w.buffer_match_list(buffer, g.config.buffers) == 1
end

function protect_url(text)
   return pcre.gsub(
      text,
      "(^|\\s)([a-z][a-z0-9-]+://)([-a-zA-Z0-9+&@#/%?=~_|\\[\\]\\(\\)!:,\\.;]*[-a-zA-Z0-9+&@#/%=~_|\\[\\]])?($|\\W)",
      "%1" .. ESC .. "%2%3" ..ESC .. "%4",
      nil,
      g.utf8_flag)
end

function hash(text)
   local placeholders, index = {}, 0
   text = pcre.gsub(
      text,
      ESC_RE .. "([^" .. ESC_RE .. "]+)" .. ESC_RE,
      function (s)
         index = index + 1
         placeholders[index] = s
         return PHOLD_START .. index .. PHOLD_END
      end,
      nil,
      g.utf8_flag)
   return text, placeholders
end

function unhash(text, placeholders)
   text = pcre.gsub(
      text,
      PHOLD_START_RE .. "(\\d+)" .. PHOLD_END_RE,
      function (i)
         i = tonumber(i)
         if not placeholders[i] then
             return ""
          else
            return w.color(g.config.escape_color) ..
                   placeholders[i] ..
                   w.color("reset")
          end
      end,
      nil,
      g.utf8_flag)
   return text
end

function modify_input_dummy_cb(_, _, text)
   return text
end

function process(text)
   local placeholders
   g.last_fg, g.last_bg = nil, nil
   text = protect_url(text)
   text, placeholders = hash(text)
   text = replace_patterns(text)
   text = unhash(text, placeholders)

   return text
end

function input_return_cb(_, buffer, cmd)
   if is_valid_buffer(buffer) then
      local current_input = w.buffer_get_string(buffer, "input")
      if w.string_is_command_char(current_input) ~= 1 then
         local text = w.buffer_get_string(buffer, "localvar_" .. g.script.name)
         w.buffer_set(buffer, "input", w.string_remove_color(text, ""))
      end
   end
   return w.WEECHAT_RC_OK
end

function input_text_display_cb(_, modifier, buffer, text)
   local current_input = w.buffer_get_string(buffer, "input")
   if is_valid_buffer(buffer) and w.string_is_command_char(current_input) ~= 1 then
      text = w.hook_modifier_exec(g.script.name .. "_before", buffer, text)
      text = process(text)
      text = w.hook_modifier_exec(g.script.name .. "_after", buffer, text)
      w.buffer_set(buffer, "localvar_set_" .. g.script.name, text)
   end
   return text
end

function cmd_send_original(buffer)
   local input = w.buffer_get_string(buffer, "input")
   if input ~= "" then
      w.buffer_set(buffer, "localvar_set_prettype", input)
      w.command(buffer, "/input return")
   end
end

function cmd_print_original(buffer)
   local input = w.buffer_get_string(buffer, "input")
   if input ~= "" then
      w.print(buffer, g.script.name .. "\t" .. input)
   end
end

function cmd_insert_escape(buffer, args)
   w.command(buffer, "/input insert " .. ESC)
end

function command_cb(_, buffer, param)
   if is_valid_buffer(buffer) then
      local action, args = param:match("^(%S+)%s*(.*)")
      if action then
         local callbacks = {
            ["send-original"] = cmd_send_original,
            ["print-original"] = cmd_print_original,
            escape = cmd_insert_escape
         }

         if callbacks[action] then
            callbacks[action](buffer, args)
         end
      end
   end
   return w.WEECHAT_RC_OK
end

function is_unclosed_escape(s)
   return (pcre.count(s, ESC_RE, g.utf8_flag) % 2) == 1
end

function tab_cb(_, buffer, command)
   local pos = w.buffer_get_integer(buffer, "input_pos")
   local input = w.buffer_get_string(buffer, "input")

   if w.string_is_command_char(input) == 1 then
      return w.WEECHAT_RC_OK
   end

   if pos > 0 then
      local before_cursor = utf8.sub(input, 1, pos)
      if is_unclosed_escape(before_cursor) then
         return w.WEECHAT_RC_OK
      end
      local base_word = before_cursor:match("([^%s]+)%s*$")
      if utf8.sub(base_word, 1, 1) ~= u(ESC) then
         local length = utf8.len(base_word)
         w.buffer_set(buffer, "input_pos", pos - length)
         cmd_insert_escape(buffer)
         w.buffer_set(buffer, "input_pos", pos + length + 1)
      end
   end
   return w.WEECHAT_RC_OK
end

function completion_irc_nicks(buffer, completion)
   local buffer_type = w.buffer_get_string(buffer, "localvar_type")
   local current_server = w.buffer_get_string(buffer, "localvar_server")
   local current_channel = w.buffer_get_string(buffer, "localvar_channel")

   local h_server = w.hdata_get("irc_server")
   local servers = w.hdata_get_list(h_server, "irc_servers")
   local server = w.hdata_search(h_server, servers, "${irc_server.name} == "..current_server, 1)
   if not server or server == "" then
      return
   end

   local h_channel = w.hdata_get("irc_channel")
   local channel = w.hdata_pointer(h_server, server, "channels")
   while channel and channel ~= "" do
      if w.hdata_string(h_channel, channel, "name") == current_channel then
         local h_nick = w.hdata_get("irc_nick")
         local nick, valid_nicks = w.hdata_pointer(h_channel, channel, "nicks"), {}
         while nick and nick ~= "" do
            local name = w.hdata_string(h_nick, nick, "name")
            valid_nicks[name] = true
            w.hook_completion_list_add(
               completion,
               ESC..name..ESC,
               1,
               w.WEECHAT_LIST_POS_SORT)
            nick = w.hdata_pointer(h_nick, nick, "next_nick")
         end

         local h_speaker = w.hdata_get("irc_channel_speaking")
         local speaker = w.hdata_pointer(h_channel, channel, "last_nick_speaking_time")
         while speaker and speaker ~= "" do
            local name = w.hdata_string(h_speaker, speaker, "nick")
            if valid_nicks[name] then
               w.hook_completion_list_add(
                  completion,
                  ESC..name..ESC,
                  1,
                  w.WEECHAT_LIST_POS_BEGINNING)
            end
            speaker = w.hdata_pointer(h_speaker, speaker, "prev_nick")
         end

         if buffer_type == "private" then
            w.hook_completion_list_add(
               completion,
               ESC..current_channel..ESC,
               1,
               w.WEECHAT_LIST_POS_BEGINNING)
         end

         w.hook_completion_list_add(
            completion,
            ESC..w.hdata_string(h_server, server, "nick")..ESC,
            1,
            w.WEECHAT_LIST_POS_END)
         break
      end
      channel = w.hdata_pointer(h_channel, channel, "next_channel")
   end
end

function completion_nicks_cb(_, _, buffer, completion)
   if w.buffer_get_string(buffer, "plugin") == "irc" then
      completion_irc_nicks(buffer, completion)
   else
      local ptr_group = w.hdata_pointer(w.hdata_get("buffer"), buffer, "nicklist_root")
      if ptr_group and ptr_group ~= "" then
         local h_group, h_nick = w.hdata_get("nick_group"), w.hdata_get("nick")
         ptr_group = w.hdata_pointer(h_group, ptr_group, "children")
         while ptr_group and ptr_group ~= "" do
            local ptr_nick = w.hdata_pointer(h_group, ptr_group, "nicks")
            while ptr_nick and ptr_nick ~= "" do
               w.hook_completion_list_add(
                  completion,
                  ESC..w.hdata_string(h_nick, ptr_nick, "name")..ESC,
                  1,
                  w.WEECHAT_LIST_POS_END)
               ptr_nick = w.hdata_pointer(h_nick, ptr_nick, "next_nick")
            end
            ptr_group = w.hdata_pointer(h_group, ptr_group, "next_group")
         end
      end
   end

   return w.WEECHAT_RC_OK
end

function completion_channels_cb(_, _, buffer, completion)
   local buffer_type, current_server, current_channel
   if w.buffer_get_string(buffer, "plugin") == "irc" then
      buffer_type = w.buffer_get_string(buffer, "localvar_type")
      current_server = w.buffer_get_string(buffer, "localvar_server")
      current_channel = w.buffer_get_string(buffer, "localvar_channel")
   end
   local h_server, h_channel = w.hdata_get("irc_server"), w.hdata_get("irc_channel")
   local server = w.hdata_get_list(h_server, "irc_servers")
   local current_server_channels = w.list_new()

   while server and server ~= "" do
      if w.hdata_integer(h_server, server, "is_connected") == 1 then
         local server_name = w.hdata_string(h_server, server, "name")
         local channel = w.hdata_pointer(h_server, server, "channels")
         while channel and channel ~= "" do
            local channel_name = w.hdata_string(h_channel, channel, "name")
            if channel_name ~= current_channel then
               if server_name == current_server then
                  w.list_add(
                     current_server_channels,
                     ESC..channel_name..ESC,
                     w.WEECHAT_LIST_POS_SORT, "")
               else
                  w.hook_completion_list_add(
                     completion,
                     ESC..channel_name..ESC,
                     0,
                     w.WEECHAT_LIST_POS_SORT)
               end
            end
            channel = w.hdata_pointer(h_channel, channel, "next_channel")
         end
      end
      server = w.hdata_pointer(h_server, server, "next_server")
   end

   for i = w.list_size(current_server_channels) - 1, 0, -1 do
      w.hook_completion_list_add(
         completion,
         w.list_string(w.list_get(current_server_channels, i)),
         0,
         w.WEECHAT_LIST_POS_BEGINNING)

   end
   w.list_free(current_server_channels)

   if buffer_type == "channel" and current_channel then
      w.hook_completion_list_add(
         completion,
         ESC..current_channel..ESC,
         0,
         w.WEECHAT_LIST_POS_BEGINNING)
   end

   return w.WEECHAT_RC_OK
end

function config_cb(_, opt_name, opt_value)
   local name = opt_name:match("^plugins.var.lua." .. g.script.name .. ".(.+)$")
   if g.defaults[name] then
      g.config[name] = opt_value
   end
   return w.WEECHAT_RC_OK
end

function init_config()
   for name, info in pairs(g.defaults) do
      if w.config_is_set_plugin(name) ~= 1 then
         w.config_set_plugin(name, info.value)
         w.config_set_desc_plugin(name, info.description)
         g.config[name] = info.value
      else
         g.config[name] = w.config_get_plugin(name)
      end
   end
   w.hook_config("plugins.var.lua." .. g.script.name .. ".*", "config_cb", "")
end

function setup()
   assert(
      w.register(
         g.script.name,
         g.script.author,
         g.script.version,
         g.script.license,
         g.script.description,
         "", ""),
      "Unable to register script. Perhaps it has been loaded before?")

   init_config()

   w.hook_command_run("/input return", "input_return_cb", "")
   w.hook_modifier("9000|input_text_display_with_cursor", "input_text_display_cb", "")
   w.hook_completion("prettype_channels", "Channels on all IRC servers", "completion_channels_cb", "")
   w.hook_completion("prettype_nicks", "Nicks in nicklist", "completion_nicks_cb", "")
   w.hook_command_run("/input complete*", "tab_cb", "")
   w.hook_command(
      g.script.name,
      "Control " .. g.script.name .. " script.",
      "send-original || print-original || escape",
[[
   send-original: Send the original text instead of the modified version.
  print-original: Print the original text to current buffer.
          escape: Insert escape marker. To prevent script from modifying a portion of
                  text, you have to enclose it with this marker.
]],
      "send-original || print-original || escape",
      "command_cb",
      "")
end

g.replacements = {
   { "(^\\s+|\\s+$)", "" },
   { "\\.{3,}", u(0x2026) },
   { "-{3}", u(0x2014) },
   { "-{2}", u(0x2013) },
   { "<-", u(0x2190) },
   { "->", u(0x2192) },
   { "<<", u(0x00ab) },
   { ">>", u(0x00bb) },
   { "\\+-", u(0x00b1) },
   { "===", u(0x2261) },
   { "(!=|=/=)", u(0x2260) },
   { "<=", u(0x2264) },
   { ">=", u(0x2265) },
   { "(?i:\\(r\\))", u(0x00ae) },
   { "(?i:\\(c\\))", u(0x00a9) },
   { "(?i:\\(tm\\))", u(0x2122) },
   { "(\\d+)\\s*x\\s*(\\d+)", u("%1", 0x00d7, "%2") },
   { "[.?!][\\s\"]+\\p{Ll}", utf8.upper },
   { "^(?:" .. PHOLD_START_RE .. "\\d+" .. PHOLD_END_RE .. "\\s*|[\"])?\\p{Ll}", utf8.upper },
   { "(^(?:" .. PHOLD_START_RE .. "\\d+" .. PHOLD_END_RE .. "\\s*)?|[-\\x{2014}\\s(\[\"])'", u("%1", 0x2018) },
   { "'", u(0x2019) },
   { "(^(?:" .. PHOLD_START_RE .. "\\d+" .. PHOLD_END_RE .. "\\s*)?|[-\\x{2014/\\[(\\x{2018}\\s])\"", u("%1", 0x201c) },
   { "\"", u(0x201d) },
   { "\\bi\\b", utf8.upper },
   { "\\b(?i:dr|mr|mrs|prof)\\.", title_case },
   { "(\\d+)deg\\b", u("%1", 0x00b0) },
   { "\\x{00b0}\\s*[cf]\\b", utf8.upper },
   { "<([us])>(.+?)</\\1>", combine },
   { "\\s{2,}", " " },
   { "(?![^a-zA-Z0-9_.-])[a-zA-Z0-9_-]+\\.[a-zA-Z0-9_][a-zA-Z0-9_.-]*", utf8.lower },
   { ESC_RE, "\005" }
}

setup()

local w = weechat
local pcre = require "rex_pcre"
local unicode = require "unicode"

local g = {
   script = {
      name = "prettype",
      author = "tomoe-mami <https://github.com/tomoe-mami>",
      license = "WTFPL",
      version = "0.4",
      description = "Prettify text you typed with auto-capitalization and proper unicode symbols"
   },
   config = {
      nick_completer = ":"
   },
   defaults = {
      buffers = {
         value = "irc.*,!irc.server.*,!*.nickserv,!*.chanserv",
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
      u = 0x0332
   },
   utf8_flag = pcre.flags().UTF8
}

function u(...)
   local result = ""
   for _, c in ipairs(arg) do
      if type(c) == "number" then
         c = unicode.utf8.char(c)
      end
      result = result .. c
   end
   return result
end

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
         return unicode.utf8.upper(char)
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
      "%1\016\022%2%3\016\022%4",
      nil,
      g.utf8_flag)
end

function protect_nick_completion(text, buffer)
   if g.config.nick_completer and g.config.nick_completer ~= "" then
      text = text:gsub(
         "^([^%s]+)(%" .. g.config.nick_completer .. "%s*)",
         function (nick, suffix)
            local result = nick .. suffix
            local nick_ptr = w.nicklist_search_nick(buffer, "", nick)
            if nick_ptr ~= "" then
               return "\016\022" .. result .. "\016\022"
            else
               return result
            end
         end)
   end
   return text
end

function hash(text)
   local placeholders, index = {}, 0
   text = pcre.gsub(
      text,
      "\\x10\\x16([^\\x10]+|\\x10(?!\\x16))\\x10\\x16",
      function (s)
         index = index + 1
         placeholders[index] = s
         return "\016\023" .. index .. "\016\023"
      end,
      nil,
      g.utf8_flag)
   return text, placeholders
end

function unhash(text, placeholders)
   text = pcre.gsub(
      text,
      "\\x10\\x17(\\d+)\\x10\\x17",
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

function process(text, buffer)
   local placeholders
   text = protect_url(text)
   text = protect_nick_completion(text, buffer)
   text, placeholders = hash(text)
   text = replace_patterns(text)
   text = unhash(text, placeholders)

   return text
end

function remove_weechat_escapes(text)
   text = pcre.gsub(text, "(\\x19(b[FDBl_#-]|E|\\x1c|[FB*]?[*!/_|]?(\\d{2}|@\\d{5})(,(\\d{2}|@\\d{5}))?)|[\\x1A\\x1B].|\\x1C)", "")
   return text
end

function input_return_cb(_, buffer, cmd)
   if is_valid_buffer(buffer) then
      local current_input = w.buffer_get_string(buffer, "input")
      if w.string_is_command_char(current_input) ~= 1 then
         local text = w.buffer_get_string(buffer, "localvar_" .. g.script.name)
         text = remove_weechat_escapes(text)
         w.buffer_set(buffer, "input", text)
      end
   end
   return w.WEECHAT_RC_OK
end

function input_text_display_cb(_, modifier, buffer, text)
   if is_valid_buffer(buffer) and w.string_is_command_char(text) ~= 1 then
      text = process(text, buffer)
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
   w.command(buffer, "/input insert \\x10\\x16")
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

function config_cb(_, opt_name, opt_value)
   if opt_name == "weechat.completion.nick_completer" then
      g.config.nick_completer = opt_value
   else
      local name = opt_name:match("^plugins.var.lua." .. g.script.name .. ".(.+)$")
      if g.defaults[name] then
         g.config[name] = opt_value
      end
   end
   return w.WEECHAT_RC_OK
end

function init_config()
   local opt = w.config_get("weechat.completion.nick_completer")
   if opt and opt ~= "" then
      g.config.nick_completer = w.config_string(opt)
   end

   for name, info in pairs(g.defaults) do
      if w.config_is_set_plugin(name) ~= 1 then
         w.config_set_plugin(name, info.value)
         w.config_set_desc_plugin(name, info.description)
         g.config[name] = info.value
      else
         g.config[name] = w.config_get_plugin(name)
      end
   end
   w.hook_config("weechat.completion.nick_completer", "config_cb", "")
   w.hook_config("plugins.var.lua." .. g.script.name .. ".*", "config_cb", "")
end

function prepare_replacements()
   local pattern = "\\b(?i:(" .. table.concat(g.all_caps, "|") .. "))\\b"
   table.insert(g.replacements, { pattern, unicode.utf8.upper })
   g.all_caps = nil
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
   prepare_replacements()

   w.hook_command_run("/input return", "input_return_cb", "")
   w.hook_modifier("input_text_display_with_cursor", "input_text_display_cb", "")
   w.hook_command(
      g.script.name,
      "Control " .. g.script.name .. " script.",
      "send-original || print-original || mnemonic [<n-chars>] || codepoint || escape",
[[
   send-original: Send the original text instead of the modified version.
  print-original: Print the original text to current buffer.
          escape: Insert escape marker. To prevent script from modifying a portion of
                  text, you have to enclose it with this marker.
       <n-chars>: Numbers of character that will be interpreted as mnemonic. If not specified
                  or if it's out of range (less than 2 or larger than 6) it will fallback to
                  the default value (2).
]],
      "send-original || print-original || escape",
      "command_cb",
      "")
end

g.all_caps = {
   "afaik",
   "ama",
   "bsd",
   "btw",
   "cmiiw",
   "eli5",
   "ftp",
   "fyi",
   "gpl",
   "https?",
   "ii?rc",
   "lol",
   "mfw",
   "mrw",
   "nih",
   "pebkac",
   "rfc",
   "rofl",
   "sasl",
   "ss[lh]",
   "tl;d[rw]",
   "usa",
   "wtf",
   "wtfpl",
   "wth",
   "ymmv",
}

g.replacements = {
   { "(^\\s+|\\s+$)",                        "" },
   { "\\.{3,}",                              u(0x2026) },
   { "-{3}",                                 u(0x2014) },
   { "-{2}",                                 u(0x2013) },
   { "<-",                                   u(0x2190) },
   { "->",                                   u(0x2192) },
   { "<<",                                   u(0x00ab) },
   { ">>",                                   u(0x00bb) },
   { "\\+-",                                 u(0x00b1) },
   { "===",                                  u(0x2261) },
   { "(!=|=/=)",                             u(0x2260) },
   { "<=",                                   u(0x2264) },
   { ">=",                                   u(0x2265) },
   { "(?i:\\(r\\))",                         u(0x00ae) },
   { "(?i:\\(c\\))",                         u(0x00a9) },
   { "(?i:\\(tm\\))",                        u(0x2122) },
   { "(\\d+)\\s*x\\s*(\\d+)",                u("%1", 0x00d7, "%2") },
   { "[.?!][\\s\"]+\\p{Ll}",                 unicode.utf8.upper },
   {
      "^(?:\\x10\\x17\\d+\\x10\\x17\\s*|[\"])?\\p{Ll}",
      unicode.utf8.upper
   },
   {
      "(^(?:\\x10\\x17\\d+\\x10\\x17\\s*)?|[-\\x{2014}\\s(\[\"])'",
      u("%1", 0x2018)
   },
   { "'",                                    u(0x2019) },
   {
      "(^(?:\\x10\\x17\\d+\\x10\\x17\\s*)?|[-\\x{2014/\\[(\\x{2018}\\s])\"",
      u("%1", 0x201c)
   },
   { "\"",                                   u(0x201d) },
   { "\\bi\\b",                              unicode.utf8.upper },
   --{
      --"\\b(?i:(https?|ss[lh]|usa|rfc|ftp|ii?rc|fyi|cmiiw|afaik|btw|pebkac|wtf|wth|lol|rofl|ymmv|nih|ama|eli5|mfw|mrw|tl;d[rw]|sasl))\\b",
      --unicode.utf8.upper
   --},
   { "\\b(?i:dr|mr|mrs|prof)\\.",            title_case },
   { "(\\d+)deg\\b",                         u("%1", 0x00b0) },
   { "\\x{00b0}\\s*[cf]\\b",                 unicode.utf8.upper },
   { "<([us])>(.+?)</\\1>",                  combine },
   { "\\s{2,}",                              " " },
}

setup()

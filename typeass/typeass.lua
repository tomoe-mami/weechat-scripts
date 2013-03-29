--[[
   typeass

   Stupid type assistant. Does nothing other than changing regular quotes
   to &ldquo; and &rdquo; pair, capitalize letter that looks like the start
   of sentence, and few other stupid replacements.

   Author: rumia <https://github.com/rumia>
   License: WTFPL
   Requires: lrexlib-pcre and snlunicode
--]]

local pcre = require "rex_pcre"
local unicode = require "unicode"
local utf8_flag = pcre.flags().UTF8

local buffer_mask = "*,!*.nickserv,!*.chanserv"
local placeholders = {}
local nick_completion_char = ":"
local replacements = {
   { "\"([^\"]+)\"",          "\226\128\156%1\226\128\157" },
   { "\\.{3,}",               "\226\128\166" },
   { "-{3}",                  "\226\128\148" },
   { "-{2}",                  "\226\128\147" },
   { "<-",                    "\226\134\144" },
   { "->",                    "\226\134\146" },
   { "<<",                    "\194\171" },
   { ">>",                    "\194\187" },
   { "\\+-",                  "\194\177" },
   { "=/=",                   "\226\137\160" },
   { "<=",                    "\226\137\164" },
   { ">=",                    "\226\137\165" },
   { "(\\d+)\\s*x\\s*(\\d+)", "%1 \195\151 %2" },
   { "(?i:\\(r\\))",          "\194\174" },
   { "(?i:\\(c\\))",          "\194\169" },
   { "(?i:\\(tm\\))",         "\226\132\162" },
   { "([\\pL\\pN])$",         "%1." },
   { "^\\s*\\p{Ll}",          unicode.utf8.upper },
   { "[.?!]\\s+\\p{Ll}",      unicode.utf8.upper },
   { "\\s+i\\b",              unicode.utf8.upper },
   { "(\\d+)deg\\b",          "%1\194\176" }
}

function setup()
   weechat.register(
      "typeass",
      "rumia <https://github.com/rumia>",
      "0.1",
      "WTFPL",
      "Stupid Type Assistant",
      "",
      "")

   if weechat.config_is_set_plugin("buffers") == 1 then
      buffer_mask = weechat.config_get_plugin("buffers")
   else
      weechat.config_set_plugin("buffers", buffer_mask)
   end

   local opt = weechat.config_get("weechat.completion.nick_completer")
   nick_completion_char = weechat.config_string(opt)

   weechat.hook_command_run("/input return", "input_handler", "")
end

function mark_ticks(text)
   local index = 0
   -- mark url with ticks
   text = pcre.gsub(text, "([[:alnum:]-]+://\\S+)", "`%1`", nil, utf8_flag)

   -- mark s/pattern/replacement/ with ticks
   text = pcre.gsub(text, "^(s/.+?/.+?/)$", "`%1`", nil, utf8_flag)

   return pcre.gsub(text, "`([^`]+)`", function (match)
      index = index + 1
      placeholders[index] = match
      return "\027" .. index .. "\027"
   end)
end

function restore_ticks(text)
   return pcre.gsub(text, "\027(\\d+)\027", function (match)
      local index = tonumber(match)
      if placeholders[index] then
         return placeholders[index]
      else
         return ""
      end
   end)
end

function replace_patterns(text)
   for _, p in ipairs(replacements) do
      text = pcre.gsub(text, p[1], p[2], nil, utf8_flag)
   end
   return text
end

function input_handler(data, buffer, command)
   local is_matched = weechat.buffer_match_list(buffer, buffer_mask)
   if is_matched == 1 then
      local input = weechat.buffer_get_string(buffer, "input")
      local nick_completion_part = ""

      if not input:match("^/") or input:match("^/[Mm][Ee][ \t]+") then
         if nick_completion_char and #nick_completion_char > 0 then
            local part1, part2 = input:match(
               "^([^%" .. nick_completion_char .. "]+)" ..
               nick_completion_char .. "[ \t]*(.+)")

            if part1 and weechat.nicklist_search_nick(buffer, "", part1) ~= "" then
               nick_completion_part = part1 .. nick_completion_char .. " "
               input = part2
            end
         end

         placeholders = {}
         input = mark_ticks(input)
         input = replace_patterns(input)
         input = restore_ticks(input)
         placeholders = nil

         weechat.buffer_set(buffer, "input",  nick_completion_part .. input)
      end
   end
   return weechat.WEECHAT_RC_OK
end

setup()

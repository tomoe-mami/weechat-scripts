--[[
   xclipurl - Selects URL in a buffer and store it into XClipboard.

   This script will collect URL in a buffer and then present you with a prompt
   to select the URL (with Up/Down arrow key). Once you pressed Enter,
   the selected URL will be put into the clipboard. Pressing Ctrl-C will cancel
   the URL selection.

   To be able to see the prompt and the selected URL, you must first add item
   `xclipurl` into a bar. You might also want to bind a key for command `/xclipurl`.

   Options:

   - plugins.var.lua.xclipurl.selection (default: "primary")

      Default selection mode to use. Valid values are "primary", "secondary", and
      "clipboard".

   - plugins.var.lua.xclipurl.ignore_stored_url (default: "yes")

      If set to "yes", URL that has been stored into the clipboard will be
      ignored the next time you call `/xclipurl` again.

   - plugins.var.lua.xclipurl.noisy (default: "no")

      If set to "yes", the script will print the URL into the core buffer
      everytime you stored one into the clipboard (ah, you know... for science!)

   - plugins.var.lua.xclipurl.default_color (default: "gray")
   - plugins.var.lua.xclipurl.mode_color (default: "yellow")
   - plugins.var.lua.xclipurl.key_color (default: "yellow")
   - plugins.var.lua.xclipurl.index_color (default: "yellow")
   - plugins.var.lua.xclipurl.url_color (default: "lightblue")

   Author: rumia <https://github.com/rumia>
   License: WTFPL
   Requires: xclip
--]]

local active, noisy = false, true
local selection = "primary"
local ignore_stored_url, stored_urls = true, {}
local url_list, url_index = {}, 0

local valid_selections = { primary = 1, secondary = 2, clipboard = 3 }
local colors = {
   default  = "gray",
   key      = "yellow",
   index    = "yellow",
   url      = "lightblue",
   mode     = "yellow"
}

function setup()
   weechat.register(
      "xclipurl", "rumia <https://github.com/rumia>", "0.1", "WTFPL",
      "Puts URL into clipboard", "", "")

   local opt = weechat.config_get_plugin("selection")
   if not opt or opt == "" or not valid_selections[opt] then
      weechat.config_set_plugin("selection", "primary")
   else
      selection = opt
   end

   opt = weechat.config_get_plugin("ignore_stored_url")
   if not opt or opt == "" or (opt ~= "yes" and opt ~= "no") then
      weechat.config_set_plugin("ignore_stored_url", "yes")
   else
      ignore_stored_url = (opt == "yes")
   end

   opt = weechat.config_get_plugin("noisy")
   if not opt or opt == "" or (opt ~= "yes" and opt ~= "no") then
      weechat.config_set_plugin("noisy", "yes")
   else
      noisy = (opt == "yes")
   end

   for name, value in pairs(colors) do
      local opt_name = name .. "_color"
      local opt_value = weechat.config_get_plugin(opt_name)

      if not opt_value or opt_value == "" then
         weechat.config_set_plugin(opt_name, value)
      else
         colors[name] = opt_value
      end
   end

   weechat.bar_item_new("xclipurl", "bar_item_cb", "")
   weechat.hook_command(
      "xclipurl",
      "Select URL in a buffer and put it into X clipboard",

      "[all|prev|next|switch|store|cancel]",

      "all        : Include all URLs in selection\n" ..
      "prev       : Select previous URL\n" ..
      "next       : Select next URL\n" ..
      "switch     : Switch selection mode\n" ..
      "store      : Store currently selected URL\n" ..
      "cancel     : Cancel URL selection\n\n" ..
      "KEYS\n\n" ..
      "Up/Down    : Select previous/next URL\n" ..
      "Tab        : Switch selection mode\n" ..
      "Enter      : Store currently selected URL\n" ..
      "Ctrl-C     : Cancel URL selection\n\n",

      "all || prev || next || switch || store || cancel",

      "main_command_cb",
      "")
end

function main_command_cb(data, buffer, arg)
   if not active then
      start_url_selection(buffer, arg == "all")
   else
      local op, param = arg:match("^([^ \t]+)[ \t]*(.*)$")
      if op == "prev" then
         select_url(-1)
      elseif op == "next" then
         select_url(1)
      elseif op == "switch" then
         switch_mode(param)
      elseif op == "store" then
         local result = store_url(param)
         finish_url_selection(buffer)
         return result
      else
         finish_url_selection(buffer)
      end
   end
   return weechat.WEECHAT_RC_OK
end

function start_url_selection(buffer, show_all)
   active = true
   setup_key_bindings(buffer, false)
   collect_urls(buffer, show_all)
   if url_index > 0 then
      setup_key_bindings(buffer, true)
      weechat.bar_item_update("xclipurl")
   end
end

function finish_url_selection(buffer)
   setup_key_bindings(buffer, false)
   url_list, url_index, active = nil, nil, false
   weechat.bar_item_update("xclipurl")
end

function bar_item_cb(data, item, window)
   if url_list and url_index and url_index ~= 0 and url_list[url_index] then
      return string.format(
         "%sxclipurl: %s%s%s <%s↑%s> Prev <%s↓%s> Next <%sTab%s> Mode " ..
         "<%s^C%s> Cancel <%s↵%s> OK #%s%d%s: %s%s%s",
         weechat.color(colors.default),
         weechat.color(colors.mode),
         selection:sub(1, 3),
         weechat.color(colors.default),
         weechat.color(colors.key), weechat.color(colors.default),
         weechat.color(colors.key), weechat.color(colors.default),
         weechat.color(colors.key), weechat.color(colors.default),
         weechat.color(colors.key), weechat.color(colors.default),
         weechat.color(colors.key), weechat.color(colors.default),
         weechat.color(colors.index), url_index, weechat.color(colors.default),
         weechat.color(colors.url), url_list[url_index],
         weechat.color(colors.default))
   else
      return ""
   end
end

function switch_mode(param)
   if not param then param = "next" end

   if valid_selections[param] then
      selection = param
   else
      local modes = { "primary", "secondary", "clipboard" }
      local total = #modes
      local current_index = valid_selections[selection]

      local new_index = current_index + (param == "next" and 1 or -1)
      if new_index > total then
         new_index = 1
      elseif new_index < 1 then
         new_index = total
      end

      local new_mode = selection
      if modes[new_index] then
         new_mode = modes[new_index]
         if valid_selections[new_mode] then
            selection = new_mode
         end
      end
   end
   weechat.bar_item_update("xclipurl")
end

function setup_key_bindings(buffer, mode)
   local key_bindings = {
      ["meta2-A"] = "/xclipurl prev",           -- up
      ["meta2-B"] = "/xclipurl next",           -- down
      ["ctrl-I"]  = "/xclipurl switch next",    -- tab
      ["meta2-C"] = "/xclipurl switch next",    -- right
      ["meta2-Z"] = "/xclipurl switch prev",    -- shift-tab
      ["meta2-D"] = "/xclipurl switch prev",    -- left
      ["ctrl-M"]  = "/xclipurl store",          -- enter
      ["ctrl-C"]  = "/xclipurl cancel"          -- ctrl-c
   }

   local prefix = mode and "key_bind_" or "key_unbind_"
   for key, command in pairs(key_bindings) do
      weechat.buffer_set(buffer, prefix .. key, mode and command or "")
   end
end

function select_url(rel_pos)
   local total = #url_list
   if total > 0 then
      url_index = url_index + rel_pos
      if url_index < 1 then
         url_index = total
      elseif url_index > total then
         url_index = 1
      end
      weechat.bar_item_update("xclipurl")
   end
end

function collect_urls(buffer, show_all)
   local buf_lines = weechat.infolist_get("buffer_lines", buffer, "")
   local exists = {}

   url_list = {}
   local pattern = "(%a[%w%+%.%-]+://[%w:!/#_~@&=,;%+%?%[%]%.%%%-]+)([^%s]*)"
   while weechat.infolist_next(buf_lines) == 1 do
      local message = weechat.infolist_string(buf_lines, "message")
      local url, tail = message:match(pattern)
      if url then
         -- ugly workaround for wikimedia's "(stuff)" suffix on their URLs
         if tail and tail ~= "" then
            url = url .. (tail:match("^(%b())") or "")
         end
         local ignored = not show_all and ignore_stored_url and stored_urls[url]
         if not ignored and not exists[url] then
            table.insert(url_list, url)
            exists[url] = true
         end
      end
   end

   weechat.infolist_free(buf_lines)
   url_index = #url_list
end

function store_url(url)
   if not url or url == "" then
      if url_index and url_list and url_list[url_index] then
         url = url_list[url_index]
      end
   end

   if url and #url > 0 then
      local fp = io.popen("xclip -selection " .. selection, "w")
      if not fp then
         weechat.print("", "xclipurl\tUnable to run `xclip`")
         return weechat.WEECHAT_RC_ERROR
      end
      fp:write(url)
      fp:close()

      if ignore_stored_url then
         stored_urls[url] = true
      end
      if noisy then
         weechat.print("", string.format(
            "xclipurl\tStored into %s selection: %s",
            selection, url))
      end
      return weechat.WEECHAT_RC_OK
   else
      weechat.print("", "xclipurl\tEmpty URL")
      return weechat.WEECHAT_RC_ERROR
   end
end

setup()

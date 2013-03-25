--[[
   xclipurl - Selects URL in a buffer and store it into XClipboard.

   This script will collect URL in a buffer and then present you with a prompt
   to select the URL (with Up/Down arrow key). Once you pressed Enter,
   the selected URL will be put into the clipboard. Pressing Ctrl-C will cancel
   the URL selection.

   To be able to see the prompt and the selected URL, you must first add item
   `xclipurl` into a bar. You might also want to bind a key for command `/xclipurl`.

   Author: rumia <https://github.com/rumia>
   License: WTFPL
   Requires: xclip
--]]

local active = false
local selection = "primary"
local valid_selections = { primary = 1, secondary = 2, clipboard = 3 }
local url_list, url_index = {}, 0

function setup()
   weechat.register(
      "xclipurl", "rumia <https://github.com/rumia>", "0.1", "WTFPL",
      "Puts URL into clipboard", "", "")

   local select_opt = weechat.config_is_set_plugin("selection")

   if select_opt == 1 then
      selection = weechat.config_get_plugin("selection")
   end

   if select_opt == 0 or not valid_selections[selection] then
      weechat.config_set_plugin("selection", "primary")
   end

   weechat.bar_item_new("xclipurl", "bar_item_cb", "")
   weechat.hook_command(
      "xclipurl",
      "Select URL in a buffer and put it into XClipboard",

      "[prev|next|switch|store|cancel]",

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

      "prev || next || switch || store || cancel",

      "main_command_cb",
      "")
end

function main_command_cb(data, buffer, arg)
   if not active then
      start_url_selection(buffer)
   else
      local op, param = arg:match("^([^ \t]+)[ \t]*(.*)$")
      if op == "prev" then
         select_prev_url(buffer)
      elseif op == "next" then
         select_next_url(buffer)
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

function start_url_selection(buffer)
   active = true
   setup_key_bindings(buffer, false)
   collect_urls(buffer)
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
         "xclipurl %s: <Up> Previous, <Down> Next, " ..
         "<Ctrl-C> Cancel, <Enter> OK [%d]: %s",
         selection,
         url_index,
         url_list[url_index])
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
      ["meta2-Z"] = "/xclipurl switch prev",    -- shift-tab
      ["ctrl-M"]  = "/xclipurl store",          -- enter
      ["ctrl-C"]  = "/xclipurl cancel"          -- ctrl-c
   }

   local prefix = mode and "key_bind_" or "key_unbind_"
   for key, command in pairs(key_bindings) do
      weechat.buffer_set(buffer, prefix .. key, mode and command or "")
   end
end

function select_prev_url(buffer)
   url_index = url_index - 1
   if url_index < 1 then
      url_index = #url_list
   end
   weechat.bar_item_update("xclipurl")
end

function select_next_url(buffer)
   url_index = url_index + 1
   if url_index > #url_list then
      url_index = 1
   end
   weechat.bar_item_update("xclipurl")
end

function collect_urls(buffer)
   local buf_lines = weechat.infolist_get("buffer_lines", buffer, "")
   local exists = {}

   url_list = {}
   while weechat.infolist_next(buf_lines) == 1 do
      local message = weechat.infolist_string(buf_lines, "message")
      local url = message:match("([%w-]+://[^%s]+)")
      if url and not exists[url] then
         table.insert(url_list, url)
         exists[url] = true
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

      weechat.print("", string.format(
         "xclipurl\tStored into %s selection: %s",
         selection, url))

      return weechat.WEECHAT_RC_OK
   else
      weechat.print("", "xclipurl\tEmpty URL")
      return weechat.WEECHAT_RC_ERROR
   end
end

setup()

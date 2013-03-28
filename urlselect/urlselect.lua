--[[
   urlselect - Selects URL in a buffer and copy it into X clipboard or tmux buffer.

   This script will collect URL in a buffer and then present you with a prompt
   to select the URL (with Up/Down arrow key). Once you pressed Enter,
   the selected URL will be put into the clipboard. Pressing Ctrl-C will cancel
   the URL selection.

   To be able to see the prompt and the selected URL, you must first add item
   `urlselect` into a bar. You might also want to bind a key for command `/urlselect`.

   Options:

   - plugins.var.lua.urlselect.selection (default: "primary")

      Default selection mode to use. Valid values are "primary", "secondary", and
      "clipboard".

   - plugins.var.lua.urlselect.ignore_stored_url (default: "yes")

      If set to "yes", URL that has been stored into the clipboard will be
      ignored the next time you call `/urlselect` again.

   - plugins.var.lua.urlselect.noisy (default: "no")

      If set to "yes", the script will print the URL into the core buffer
      everytime you stored one into the clipboard (ah, you know... for science!)

   - plugins.var.lua.urlselect.default_color (default: "gray")
   - plugins.var.lua.urlselect.mode_color (default: "yellow")
   - plugins.var.lua.urlselect.key_color (default: "yellow")
   - plugins.var.lua.urlselect.index_color (default: "yellow")
   - plugins.var.lua.urlselect.url_color (default: "lightblue")

   Author: rumia <https://github.com/rumia>
   License: WTFPL
   Requires: xclip
--]]

local SCRIPT_NAME = "urlselect"
local w = weechat

local active_buffer, noisy = nil, true
local ignore_copied_url, copied_urls = true, {}
local url_list, url_index = {}, 0

local valid_modes, mode_order, current_mode = {}, {}, ""
local buf_switch_hook = ""

local colors = {
   default  = "gray",
   key      = "yellow",
   index    = "yellow",
   url      = "lightblue",
   mode     = "yellow"
}

function message(text)
   w.print("", SCRIPT_NAME .. "\t" .. text)
end

function setup()
   if os.execute("type xclip >/dev/null 2>&1") == 0 then
      mode_order = { "primary", "secondary", "clipboard" }
      for index, name in ipairs(mode_order) do
         valid_modes[name] = index
      end
   end

   local is_tmux = os.getenv("TMUX")
   if is_tmux and #is_tmux > 0 then
      table.insert(mode_order, "tmux")
      valid_modes.tmux = #mode_order
   end

   if #mode_order < 1 then
      error("You need xclip and/or tmux to use this script.")
   else
      w.register(
         SCRIPT_NAME, "rumia <https://github.com/rumia>", "0.1", "WTFPL",
         "Puts URL into clipboard", "unload", "")

      local opt = w.config_get_plugin("mode")
      if not opt or opt == "" or not valid_modes[opt] then
         w.config_set_plugin("mode", mode_order[1])
         current_mode = mode_order[1]
      else
         current_mode = opt
      end

      opt = w.config_get_plugin("ignore_copied_url")
      if not opt or opt == "" or (opt ~= "yes" and opt ~= "no") then
         w.config_set_plugin("ignore_copied_url", "yes")
      else
         ignore_copied_url = (opt == "yes")
      end

      opt = w.config_get_plugin("noisy")
      if not opt or opt == "" or (opt ~= "yes" and opt ~= "no") then
         w.config_set_plugin("noisy", "yes")
      else
         noisy = (opt == "yes")
      end

      for name, value in pairs(colors) do
         local opt_name = name .. "_color"
         local opt_value = w.config_get_plugin(opt_name)

         if not opt_value or opt_value == "" then
            w.config_set_plugin(opt_name, value)
         else
            colors[name] = opt_value
         end
      end

      w.bar_item_new(SCRIPT_NAME, "bar_item_cb", "")
      w.hook_command(
         SCRIPT_NAME,
         "Select URL in a buffer and copy it into X clipboard or Tmux buffer",

         "[all|prev|next|switch|copy|cancel]",

         "all        : Include all URLs in selection\n" ..
         "prev       : Select previous URL\n" ..
         "next       : Select next URL\n" ..
         "switch     : Switch selection mode\n" ..
         "copy       : Copy currently selected URL\n" ..
         "cancel     : Cancel URL selection\n\n" ..
         "KEYS\n\n" ..
         "Up/Down    : Select previous/next URL\n" ..
         "Tab        : Switch selection mode\n" ..
         "Enter      : Copy currently selected URL\n" ..
         "Ctrl-C     : Cancel URL selection\n\n",

         "all || prev || next || switch || copy || cancel",

         "main_command_cb",
         "")

      if noisy then
         local msg = string.format(
            "%sSetup complete. Ignore copied URL: %s%s%s. Noisy: %syes%s. " ..
            "Available modes:",
            w.color(colors.default),
            w.color(colors.key),
            (ignore_copied_url and "yes" or "no"),
            w.color(colors.default),
            w.color(colors.key),
            w.color(colors.default))

         for index, name in ipairs(mode_order) do
            local entry = string.format("%d.%s", index, name)
            if name == current_mode then
               entry = w.color(colors.key) ..
                       entry ..
                       w.color(colors.default)
            end
            msg = msg .. " " .. entry
         end
         message(msg)
      end
   end
end

function unload()
   if active_buffer then
      setup_key_bindings(false)
   end
   w.unhook_all()
end

function main_command_cb(data, buffer, arg)
   if not active_buffer then
      active_buffer = buffer
      start_url_selection(arg == "all")
   else
      local op, param = arg:match("^([^ \t]+)[ \t]*(.*)$")
      if op == "prev" then
         select_url(-1)
      elseif op == "next" then
         select_url(1)
      elseif op == "switch" then
         switch_mode(param)
      elseif op == "copy" then
         local result = copy_url(param)
         finish_url_selection()
         return result
      else
         finish_url_selection()
      end
   end
   return w.WEECHAT_RC_OK
end

function buffer_switch_cb(data, signal, buffer)
   if buffer ~= active_buffer then
      finish_url_selection()
   end
   return w.WEECHAT_RC_OK
end

function start_url_selection(show_all)
   collect_urls(active_buffer, show_all)
   if url_index > 0 then
      setup_key_bindings(true)
      w.bar_item_update(SCRIPT_NAME)
   end
   buf_switch_hook = w.hook_signal("buffer_switch", "buffer_switch_cb", "")
end

function finish_url_selection()
   if active_buffer then
      setup_key_bindings(false)
      url_list, url_index, active_buffer = nil, nil, nil
      w.bar_item_update(SCRIPT_NAME)
      if buf_switch_hook ~= "" then
         w.unhook(buf_switch_hook)
      end
   end
end

function bar_item_cb(data, item, window)
   local mode_label = {
      primary = "x sel primary",
      secondary = "x sel secondary",
      clipboard = "x sel clipboard",
      tmux = "tmux buffer"
   }

   if url_list and url_index and url_index ~= 0 and url_list[url_index] then
      return string.format(
         "%surlselect: %s%s%s <%s↑%s> prev <%s↓%s> next <%stab%s> mode " ..
         "<%s^c%s> cancel <%s↵%s> ok #%s%d%s: %s%s%s",
         w.color(colors.default),
         w.color(colors.mode),
         mode_label[current_mode],
         w.color(colors.default),
         w.color(colors.key), w.color(colors.default),
         w.color(colors.key), w.color(colors.default),
         w.color(colors.key), w.color(colors.default),
         w.color(colors.key), w.color(colors.default),
         w.color(colors.key), w.color(colors.default),
         w.color(colors.index), url_index, w.color(colors.default),
         w.color(colors.url), url_list[url_index],
         w.color(colors.default))
   else
      return ""
   end
end

function switch_mode(param)
   if not param then param = "next" end

   if valid_modes[param] then
      current_mode = param
   else
      local total = #mode_order
      local current_index = valid_modes[current_mode]

      local new_index = current_index + (param == "next" and 1 or -1)
      if new_index > total then
         new_index = 1
      elseif new_index < 1 then
         new_index = total
      end

      local new_mode = current_mode
      if mode_order[new_index] then
         new_mode = mode_order[new_index]
         if valid_modes[new_mode] then
            current_mode = new_mode
         end
      end
   end
   w.bar_item_update(SCRIPT_NAME)
end

function setup_key_bindings(mode)
   local key_bindings = {
      ["meta2-A"] = "/" .. SCRIPT_NAME .. " prev",           -- up
      ["meta2-B"] = "/" .. SCRIPT_NAME .. " next",           -- down
      ["ctrl-I"]  = "/" .. SCRIPT_NAME .. " switch next",    -- tab
      ["meta2-C"] = "/" .. SCRIPT_NAME .. " switch next",    -- right
      ["meta2-Z"] = "/" .. SCRIPT_NAME .. " switch prev",    -- shift-tab
      ["meta2-D"] = "/" .. SCRIPT_NAME .. " switch prev",    -- left
      ["ctrl-M"]  = "/" .. SCRIPT_NAME .. " copy",           -- enter
      ["ctrl-C"]  = "/" .. SCRIPT_NAME .. " cancel"          -- ctrl-c
   }

   local prefix = mode and "key_bind_" or "key_unbind_"
   for key, command in pairs(key_bindings) do
      w.buffer_set(active_buffer, prefix .. key, mode and command or "")
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
      w.bar_item_update(SCRIPT_NAME)
   end
end

function collect_urls(show_all)
   local buf_lines = w.infolist_get("buffer_lines", active_buffer, "")
   local exists = {}

   url_list = {}
   local pattern = "(%a[%w%+%.%-]+://[%w:!/#_~@&=,;%+%?%[%]%.%%%-]+)([^%s]*)"
   while w.infolist_next(buf_lines) == 1 do
      local message = w.infolist_string(buf_lines, "message")
      local url, tail = w.string_remove_color(message, ""):match(pattern)
      if url then
         -- ugly workaround for wikimedia's "(stuff)" suffix on their URLs
         if tail and tail ~= "" then
            url = url .. (tail:match("^(%b())") or "")
         end
         local ignored = not show_all and ignore_copied_url and copied_urls[url]
         if not ignored and not exists[url] then
            table.insert(url_list, url)
            exists[url] = true
         end
      end
   end

   w.infolist_free(buf_lines)
   url_index = #url_list
end

function copy_url(url)
   if not url or url == "" then
      if url_index and url_list and url_list[url_index] then
         url = url_list[url_index]
      end
   end

   if url and #url > 0 then
      local cb = (current_mode == "tmux" and copy_into_tmux or copy_into_xsel)
      if cb(url) then
         if ignore_copied_url then
            copied_urls[url] = true
         end
         return w.WEECHAT_RC_OK
      else
         return w.WEECHAT_RC_ERROR
      end
   else
      message("Empty URL")
      return w.WEECHAT_RC_ERROR
   end
end

function copy_into_xsel(url)
   local fp = io.popen("xclip -selection " .. current_mode, "w")
   if not fp then
      message("Unable to run `xclip`")
      return false
   end
   fp:write(url)
   fp:close()

   if noisy then
      message(string.format("Copied into %s selection: %s", current_mode, url))
   end
   return true
end

function copy_into_tmux(url)
   local escaped = url:gsub("([^%w])", "\\%1")
   if os.execute("tmux set-buffer " .. escaped) ~= 0 then
      return false
   else
      if noisy then
         message(string.format("Copied into tmux buffer: %s", url))
      end
      return true
   end
end

setup()

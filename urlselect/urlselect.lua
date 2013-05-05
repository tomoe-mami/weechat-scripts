--[[
   urlselect - Selects URL in a buffer and copy it into X clipboard or tmux buffer.

   This script will collect URL in a buffer and then present you with a prompt
   to select the URL (with Up/Down arrow key). Once you pressed Enter,
   the selected URL will be put into the clipboard. Pressing Ctrl-C will cancel
   the URL selection.

   To be able to see the prompt and the selected URL, you must first add item
   `urlselect` into a bar. You might also want to bind a key for command `/urlselect`.

   Author: rumia <https://github.com/rumia>
   URL: https://github.com/rumia/weechat-scripts
   License: WTFPL
   Requires: weechat >= 0.3.5, xclip or tmux
--]]

local SCRIPT_NAME = "urlselect"

local active_buffer = false
local url = { list = {}, copied = {}, index = 0 }
local mode = { valid = {}, order = {}, current = "" }
local config = {}
local external_commands = {}
local key_bindings = {
   ["meta2-A"]  = "prev",           -- up
   ["meta2-B"]  = "next",           -- down
   ["meta2-1~"] = "first",          -- home
   ["meta2-4~"] = "last",           -- end
   ["ctrl-I"]   = "switch next",    -- tab
   ["meta2-C"]  = "switch next",    -- right
   ["meta2-Z"]  = "switch prev",    -- shift-tab
   ["meta2-D"]  = "switch prev",    -- left
   ["?"]        = "keys",           -- ?
   ["ctrl-M"]   = "copy",           -- enter
   ["ctrl-C"]   = "cancel"          -- ctrl-c
}

function w(name)
   if type(weechat[name]) == "function" then
      return weechat[name]()
   else
      return weechat[name]
   end
end

function message(text)
   weechat.print_date_tags(
      "",
      0,
      "notify_none,no_highlight,no_log",
      SCRIPT_NAME .. "\t" .. text)
end

function setup()
   if os.execute("type xclip >/dev/null 2>&1") == 0 then
      mode.order = { "primary", "clipboard" }
      mode.valid = { primary = 1, clipboard = 2 }
   end

   local is_tmux = os.getenv("TMUX")
   if is_tmux and #is_tmux > 0 then
      table.insert(mode.order, "tmux")
      mode.valid.tmux = #mode.order
   end

   if #mode.order < 1 then
      error("You need xclip and/or tmux to use this script.")
   else
      weechat.register(
         SCRIPT_NAME, "rumia <https://github.com/rumia>", "0.1", "WTFPL",
         "Selects URL in a buffer and copy it into clipboard/tmux paste " ..
         "buffer or execute external command on it",
         "unload", "")

      local total_external_commands = load_config()
      weechat.bar_item_new(SCRIPT_NAME, "bar_item_cb", "")
      weechat.hook_command(
         SCRIPT_NAME,
         "Select URL in a buffer and copy it into X clipboard or Tmux buffer",

         "[all|bind|unbind]",

         "all        : Include all URLs in selection\n" ..
         "bind       : Bind an external command to a key (0-9)\n" ..
         "unbind     : Unbind a key\n\n" ..
         "KEYS\n\n" ..
         "Up/Down    : Select previous/next URL\n" ..
         "Tab        : Switch selection mode\n" ..
         "?          : Show keyboard shortcuts information\n" ..
         "Enter      : Copy currently selected URL\n" ..
         "0-9        : Call external command\n" ..
         "Ctrl-C     : Cancel URL selection\n\n",

         "all || bind || unbind",

         "main_command_cb",
         "")

      if config.exp_time > 0 then
         weechat.hook_timer(
            config.exp_time * 1000,
            60, 0,
            "cleanup_copied_urls", "")
      end

      if config.noisy then
         local msg = string.format(
            "%sSetup complete. Ignore copied URL: %s%s%s. Noisy: %syes%s. " ..
            "%s%d%s external commands. Available modes:",
            weechat.color(config.default_color),
            weechat.color(config.key_color),
            (config.ignore_copied_url and "yes" or "no"),
            weechat.color(config.default_color),
            weechat.color(config.key_color),
            weechat.color(config.default_color),
            weechat.color(config.key_color),
            total_external_commands,
            weechat.color(config.default_color))

         for index, name in ipairs(mode.order) do
            local entry = string.format("%d. %s", index, name)
            if name == mode.current then
               entry = weechat.color(config.key_color) ..
                       entry ..
                       weechat.color(config.default_color)
            end
            msg = msg .. " " .. entry
         end
         message(msg)
      end
   end
end

function load_config()
   local options = {
      ignore_copied_url = {
         default = true,
         description = "Ignore copied URL the next time /urlselect called"
      },
      noisy = {
         default = false,
         description = "Prints unnecessary information"
      },
      show_keys = {
         default = true,
         description = "Show keyboard shortcuts info when selecting URL"
      },
      show_nickname = {
         default = false,
         description = "Show nickname on selected URL"
      },
      enable_secondary_mode = {
         default = false,
         description = "Enable X selection's secondary mode"
      },
      default_color = {
         default = "gray",
         description = "Default text color"
      },
      key_color = {
         default = "yellow",
         description = "Color for shortcut keys"
      },
      index_color = {
         default = "yellow",
         description = "Color for URL index"
      },
      url_color = {
         default = "lightblue",
         description = "Color for selected URL"
      },
      mode_color = {
         default = "yellow",
         description = "Color for current mode"
      },
      nickname_color = {
         default = "",
         description = "Color for nickname (set to empty string to use " ..
                       "Weechat nick color)"
      },
      exp_time = {
         default = 2 * 60 * 60,
         description = "How long (in seconds) a URL should be kept in copied URL list"
      }
   }

   for name, info in pairs(options) do
      local opt_type = type(info.default)
      local value = weechat.config_get_plugin(name)
      if opt_type == "boolean" then
         if value ~= "yes" and value ~= "no" then
            config[name] = info.default
            weechat.config_set_plugin(name, info.default and "yes" or "no")
            weechat.config_set_desc_plugin(name, info.description)
         else
            config[name] = (value == "yes")
         end
      elseif opt_type == "number" then
         if not value or value == "" then
            config[name] = info.default
            weechat.config_set_plugin(name, info.default)
            weechat.config_set_desc_plugin(name, info.description)
         else
            config[name] = tonumber(value)
         end
      else
         if not value or value == "" then
            config[name] = info.default
            weechat.config_set_plugin(name, info.default)
            weechat.config_set_desc_plugin(name, info.description)
         else
            config[name] = value
         end
      end
   end

   if config.enable_secondary_mode and valid_modes.primary then
      table.insert(mode.order, "secondary")
      valid_modes.secondary = #mode.order
   end

   local value = weechat.config_get_plugin("mode")
   if not value or value == "" or not mode.valid[value] then
      weechat.config_set_plugin("mode", mode.order[1])
      weechat.config_set_desc_plugin(
         "mode",
         "Default mode to use. Valid values are: primary, clipboard, " ..
         "tmux, secondary")
      mode.current = mode.order[1]
   else
      mode.current = value
   end

   if weechat.config_is_set_plugin("ext_cmd_1") ~= 1 then
      weechat.config_set_plugin("ext_cmd_1", "xdg-open")
      weechat.config_set_desc_plugin(
         "ext_cmd_1",
         "External command that will be executed when " ..
         "key 1 pressed during URL selection")
   end

   local cmd_count = 0
   for index = 0, 9 do
      local opt_value = weechat.config_get_plugin("ext_cmd_" .. index)
      if opt_value and opt_value ~= "" then
         external_commands[index] = opt_value
         key_bindings[index] = "exec " .. index
         cmd_count = cmd_count + 1
      end
   end

   return cmd_count
end

function unload()
   weechat.config_set_plugin("mode", mode.current)
   weechat.config_set_plugin("show_keys", config.show_keys and "yes" or "no")

   if active_buffer then
      setup_key_bindings(false)
   end

   weechat.unhook_all()
end

function main_command_cb(data, buffer, arg)
   local op, param = arg:match("^([^ \t]+)[ \t]*(.*)$")
   if not active_buffer then
      if op == "bind" then
         bind_key(param, true)
      elseif op == "unbind" then
         bind_key(param, false)
      elseif op == "flush" then
         url.copied = {}
      elseif op == "copy" then
         return copy_url(param)
      else
         active_buffer = buffer
         start_url_selection(op == "all")
      end
   else
      if op == "prev" then
         select_url(1)
      elseif op == "next" then
         select_url(-1)
      elseif op == "first" or op == "last" then
         select_url(op)
      elseif op == "switch" then
         switch_mode(param)
      elseif op == "keys" then
         toggle_key_help()
      elseif op == "exec" then
         local result = run_external(tonumber(param))
         finish_url_selection()
         return result
      elseif op == "copy" then
         local result = copy_url(param)
         finish_url_selection()
         return result
      else
         finish_url_selection()
      end
   end
   return w("WEECHAT_RC_OK")
end

function buffer_switch_cb(data, signal, buffer)
   if buffer ~= active_buffer then
      finish_url_selection()
   end
   return w("WEECHAT_RC_OK")
end

function start_url_selection(show_all)
   collect_urls(show_all)
   if url.index > 0 then
      local cfg = weechat.config_get("weechat.bar.input.items")
      orig_bar_items = weechat.config_string(cfg)
      input_bar = weechat.bar_search("input")

      if input_bar and input_bar ~= "" then
         -- if i didn't include input_text, the cursor position will stay in
         -- current position.
         weechat.bar_set(input_bar, "items", "urlselect,input_text")
         setup_key_bindings(true)
         weechat.bar_item_update(SCRIPT_NAME)
         buf_switch_hook = weechat.hook_signal(
            "buffer_switch",
            "buffer_switch_cb",
            "")
      else
         finish_url_selection()
      end
   end
end

function finish_url_selection()
   if active_buffer then
      setup_key_bindings(false)
      url.list, url.index, active_buffer = nil, nil, nil
      weechat.bar_item_update(SCRIPT_NAME)

      if input_bar and input_bar ~= "" then
         weechat.bar_set(input_bar, "items", orig_bar_items)
         if buf_switch_hook ~= "" then
            weechat.unhook(buf_switch_hook)
         end
      end
   end
end

function bar_item_cb(data, item, window)
   if url.list and url.index and url.index ~= 0 and url.list[url.index] then
      local text = string.format("%s%s: %s%s",
         weechat.color(config.default_color),
         SCRIPT_NAME,
         weechat.color(config.mode_color),
         mode.current)

      if config.show_keys then
         text = text ..
                string.format(
                  " %s<%s?%s> hide keys <%sup%s> prev <%sdown%s> next " ..
                  "<%stab%s> mode <%sctrl-c%s> cancel <%senter%s> copy",
                  weechat.color(config.default_color),
                  weechat.color(config.key_color),
                  weechat.color(config.default_color),
                  weechat.color(config.key_color),
                  weechat.color(config.default_color),
                  weechat.color(config.key_color),
                  weechat.color(config.default_color),
                  weechat.color(config.key_color),
                  weechat.color(config.default_color),
                  weechat.color(config.key_color),
                  weechat.color(config.default_color),
                  weechat.color(config.key_color),
                  weechat.color(config.default_color))

         for index = 0, 9 do
            if external_commands[index] then
               text = text ..
                      string.format(
                        " %s<%s%d%s> %s",
                        weechat.color(config.default_color),
                        weechat.color(config.key_color),
                        index,
                        weechat.color(config.default_color),
                        external_commands[index])
            end
         end

      end
      text = text ..
             weechat.color(config.default_color) ..
             " #" ..
             weechat.color(config.index_color) ..
             url.index ..
             weechat.color(config.default_color) ..
             ": "

      if config.show_nickname then
         local color = config.nickname_color
         local nick = url.list[url.index][2]
         if color == "" then
            color = weechat.info_get("irc_nick_color_name", nick)
         end

         text = text ..
                weechat.color(color) ..
                nick ..
                weechat.color(config.default_color) ..
                ": "
      end

      text = text ..
             weechat.color(config.url_color) ..
             url.list[url.index][1]

      return text
   else
      return ""
   end
end

function toggle_key_help()
   config.show_keys = not config.show_keys
   weechat.bar_item_update(SCRIPT_NAME)
end

function bind_key(param, flag)
   if not param or param == "" then
      list_ext_commands()
      return w("WEECHAT_RC_OK")
   else
      local key, command = param:match("^(%d)[ \t]*(.*)")
      if not key then
         message("Please specify a key (0-9)")
         return w("WEECHAT_RC_ERROR")
      end

      key = tonumber(key)
      if flag then
         return set_ext_command(key, command)
      else
         return unset_ext_command(key)
      end
   end
end

function list_ext_commands()
   message("External Commands:")
   for index = 0, 9 do
      if external_commands[index] then
         message(string.format("%s%d%s: %s",
            weechat.color(config.key_color),
            index,
            weechat.color(config.default_color),
            external_commands[index]))
      end
   end
end

function set_ext_command(key, command)
   if not command or command == "" then
      message("You must specify a command")
      return w("WEECHAT_RC_ERROR")
   end

   local opt_name = "ext_cmd_" .. key
   weechat.config_set_plugin(opt_name, command)
   weechat.config_set_desc_plugin(
      opt_name,
      "External command that will be executed when " ..
      "key " .. key .. " pressed during URL selection")

   if not external_commands[key] then
      external_commands[key] = command
      key_bindings[key] = "/" .. SCRIPT_NAME .. " exec " .. key
   end
   if config.noisy then
      message(string.format("Key %d bound to `%s`", key, command))
   end
   return w("WEECHAT_RC_OK")
end

function unset_ext_command(key)
   if external_commands[key] then
      external_commands[key] = nil
      key_bindings[key] = nil
   end
   local opt_name = "ext_cmd_" .. key
   if weechat.config_is_set_plugin(opt_name) == 1 then
      if key == 1 then
         weechat.config_set_plugin(opt_name, "")
      else
         weechat.config_unset_plugin(opt_name)
      end
   end
   if config.noisy then
      message(string.format("Key %d unbound", key, command))
   end
   return w("WEECHAT_RC_OK")
end

function switch_mode(param)
   if not param then param = "next" end

   if mode.valid[param] then
      mode.current = param
   else
      local total = #mode.order
      local current_index = mode.valid[mode.current]

      local new_index = current_index + (param == "next" and 1 or -1)
      if new_index > total then
         new_index = 1
      elseif new_index < 1 then
         new_index = total
      end

      local new_mode = mode.current
      if mode.order[new_index] then
         new_mode = mode.order[new_index]
         if mode.valid[new_mode] then
            mode.current = new_mode
         end
      end
   end
   weechat.bar_item_update(SCRIPT_NAME)
end

function setup_key_bindings(flag)
   local prefix = flag and "key_bind_" or "key_unbind_"
   local command
   for key, param in pairs(key_bindings) do
      if flag then
         command = "/" .. SCRIPT_NAME .. " " .. param
      else
         command = ""
      end
      weechat.buffer_set(active_buffer, prefix .. key, command)
   end
end

function select_url(rel_pos)
   local total = #url.list
   if total > 0 then
      if rel_pos == "first" then
         url.index = 1
      elseif rel_pos== "last" then
         url.index = total
      else
         url.index = url.index + rel_pos
         if url.index < 1 then
            url.index = total
         elseif url.index > total then
            url.index = 1
         end
      end
      weechat.bar_item_update(SCRIPT_NAME)
   end
end

function get_tags_and_nickname(infolist)
   local tag_string = weechat.infolist_string(infolist, "tags")
   local tags, nickname = {}, "-"
   if tag_string and tag_string ~= "" then
      tag_string:gsub("([^,]+)", function (s)
         tags[s] = true
         if s:sub(1, 5) == "nick_" then
            nickname = s:sub(6)
         end
      end)
   end
   return tags, nickname
end

function cleanup_copied_urls()
   local limit = os.time() - config.exp_time
   local temp = {}
   local removed = 0
   for u, t in pairs(url.copied) do
      if t >= limit then
         temp[u] = t
      else
         removed = removed + 1
      end
   end
   url.copied = temp
   if config.noisy and removed > 0 then
      message(removed .. " URLs removed")
   end
end

function collect_urls(show_all)
   local buf_lines = weechat.infolist_get("buffer_lines", active_buffer, "")
   local exists = {}

   url.list = {}
   local pattern = "(%a[%w%+%.%-]+://[%w:!/#_~@&=,;%+%?%[%]%.%%%-]+)([^%s]*)"
   local store_url = function (u, nick)
      if not show_all and
         config.ignore_copied_url and
         url.copied[u] then
         return
      end
      if not exists[u] then
         table.insert(url.list, { u, nick })
         exists[u] = true
      end
   end

   local process_line = function ()
      local is_displayed = weechat.infolist_integer(buf_lines, "displayed")
      if is_displayed == 1 then
         local tags, nickname = get_tags_and_nickname(buf_lines)
         if tags.irc_privmsg or tags.irc_notice then
            local line = weechat.infolist_string(buf_lines, "message")
            line = weechat.string_remove_color(line, "")
            for found, tail in line:gmatch(pattern) do
               -- ugly workaround for wikimedia's "(stuff)" suffix on their URLs
               if tail and tail ~= "" then
                  found = found .. (tail:match("^(%b())") or "")
               end
               store_url(found, nickname)
            end
         end
      end
   end

   weechat.infolist_prev(buf_lines)
   process_line()
   while weechat.infolist_prev(buf_lines) == 1 do
      process_line()
   end

   weechat.infolist_free(buf_lines)
   url.index = url.list[1] and 1 or 0
end

function get_url(u)
   if not u or u == "" then
      if url.index and url.list and url.list[url.index] then
         u = url.list[url.index][1]
      end
   end
   return u
end

function mark_url_as_copied(u)
   url.copied[u] = os.time()
end

function copy_url(u)
   u = get_url(u)
   if u and u ~= "" then
      local cb = (mode.current == "tmux" and copy_into_tmux or copy_into_xsel)
      if cb(u) then
         if config.ignore_copied_url and not url.copied[u] then
            mark_url_as_copied(u)
         end
         return w("WEECHAT_RC_OK")
      else
         return w("WEECHAT_RC_ERROR")
      end
   else
      message("Empty URL")
      return w("WEECHAT_RC_ERROR")
   end
end

function copy_into_xsel(u)
   local fp = io.popen("xclip -selection " .. mode.current, "w")
   if not fp then
      message("Unable to run `xclip`")
      return false
   end
   fp:write(u)
   fp:close()

   if config.noisy then
      message(string.format("Copied into %s selection: %s", mode.current, u))
   end
   return true
end

function copy_into_tmux(u)
   local command = string.format("tmux set-buffer %q", u)
   weechat.hook_process(
      command, 0, "run_external_cb",
      "Copied into tmux buffer: " .. u)
   return true
end

function run_external(index)
   if external_commands[index] then
      local u = get_url()
      if u and u ~= "" then
         if config.ignore_copied_url and not url.copied[u] then
            mark_url_as_copied(u)
         end
         local command = string.format("%s %q", external_commands[index], u)
         weechat.hook_process(command, 0, "run_external_cb", "")
         return w("WEECHAT_RC_OK")
      end
   end
end

function run_external_cb(data, command, status, output, error)
   if status == w("WEECHAT_HOOK_PROCESS_ERROR") then
      message(string.format("Unable to run `%s`: %s", command, error))
      return w("WEECHAT_RC_ERROR")
   elseif status >= 0 then
      if noisy then
         if data and data ~= "" then
            message(string.format(data, output))
         else
            message(string.format("`%s` executed. Output: %s", command, output))
         end
      end
      return w("WEECHAT_RC_OK")
   end
end

setup()

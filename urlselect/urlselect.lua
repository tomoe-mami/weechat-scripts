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
   Requires: weechat >= 0.3.5
--]]

local g = {
   script = {
      name = "urlselect",
      author = "rumia <https://github.com/rumia>",
      license = "WTFPL",
      version = "0.1",
      description =
         "Selects URL in a buffer and copy it into clipboard/tmux paste " ..
         "buffer or execute external command on it"
   },
   active_buffer = false,
   url = {
      list = {},
      copied = {},
      index = 0,
      total = 0
   },
   mode = {
      valid = {},
      order = {},
      current = ""
   },
   config = {},
   command = {
      list = {},
      total = 0
   },
   key = {
      ["meta2-A"]  = "prev",           -- up
      ["meta2-B"]  = "next",           -- down
      ["meta2-5~"] = "10",             -- page up
      ["meta2-6~"] = "-10",            -- page down
      ["meta2-1~"] = "first",          -- home
      ["meta2-4~"] = "last",           -- end
      ["?"]        = "keys",           -- ?
      ["ctrl-M"]   = "copy",           -- enter
      ["ctrl-C"]   = "cancel"          -- ctrl-c
   },
   option_list = {
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
      },
      enable_info = {
         default = false,
         description = "Enable support for fetching information of selected URL"
      },
      info_timeout = {
         default = 60000,
         description = ""
      }
   }
}

function message(text)
   if not text then text = "(nil)" end
   weechat.print_date_tags(
      "",
      0,
      "no_highlight,no_log",
      g.script.name .. "\t" .. text)
end

function setup()
   if os.execute("type xclip >/dev/null 2>&1") == 0 then
      g.mode.order = { "primary", "clipboard" }
      g.mode.valid = { primary = 1, clipboard = 2 }
   end

   local is_tmux = os.getenv("TMUX")
   if is_tmux and #is_tmux > 0 then
      table.insert(g.mode.order, "tmux")
      g.mode.valid.tmux = #g.mode.order
   end

   weechat.register(
      g.script.name,
      g.script.author,
      g.script.version,
      g.script.license,
      g.script.description,
      "unload",
      "")

   fix_constants()
   load_config()
   setup_hooks()
   weechat.bar_item_new(g.script.name, "bar_item_cb", "")

   if g.mode.current ~= "" then
      g.key["ctrl-I"]  = "switch next" -- tab
      g.key["meta2-C"] = "switch next" -- right
      g.key["meta2-Z"] = "switch prev" -- shift-tab
      g.key["meta2-D"] = "switch prev" -- left
   end

   if g.config.enable_info then
      prepare_info_support()
   end

   if g.config.noisy then
      show_init_message()
   end
end

-- for weechat < 0.4.0, weechat.WEECHAT_* constants are actually function
function fix_constants()
   local names = {
      "WEECHAT_RC_OK",
      "WEECHAT_RC_ERROR",
      "WEECHAT_HOOK_PROCESS_ERROR",
      "WEECHAT_HOOK_PROCESS_RUNNING"
   }

   for _, name in ipairs(names) do
      if type(weechat[name]) == "function" then
         g[name] = weechat[name]()
      else
         g[name] = weechat[name]
      end
   end
end

function setup_hooks()
   weechat.hook_config("plugins.var.lua." .. g.script.name .. ".*", "config_cb", "")
   weechat.hook_command(
      g.script.name,
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

   if g.config.exp_time > 0 then
      weechat.hook_timer(
         g.config.exp_time * 1000,
         60, 0,
         "cleanup_copied_urls", "")
   end
end

function show_init_message()
   local default_color = weechat.color(g.config.default_color)
   local key_color = weechat.color(g.config.key_color)
   local msg = string.format(
      "%sSetup complete. Ignore copied URL: %s%s%s. Noisy: %syes%s. " ..
      "%s%d%s external commands. Available modes:",
      default_color,
      key_color,
      (g.config.ignore_copied_url and "yes" or "no"),
      default_color,
      key_color,
      default_color,
      key_color,
      g.command.total,
      default_color)

   for index, name in ipairs(g.mode.order) do
      local entry = string.format("%d. %s", index, name)
      if name == g.mode.current then
         entry = key_color .. entry .. default_color
      end
      msg = msg .. " " .. entry
   end
   message(msg)
end

function prepare_info_support()
   local has_module = function (name)
     if package.loaded[name] then
       return true
     else
       for _, searcher in ipairs(package.searchers or package.loaders) do
         local loader = searcher(name)
         if type(loader) == "function" then
           package.preload[name] = loader
           return true
         end
       end
       return false
     end
  end

  local required_modules = {
     "cjson",
     --"rex_pcre",
     "socket.url"
  }

  local missing_modules = {}

  for _, module_name in ipairs(required_modules) do
     if not has_module(module_name) then
        table.insert(missing_modules, module_name)
     end
  end

  local total_missing_modules = #missing_modules
  if total_missing_modules > 0 then
     g.config.enable_info = false;
     message(
        "You need " .. table.concat(missing_modules, ", ") .. 
        " module" .. total_missing_modules == 1 and " " or "s " ..
        "to enable fetching URL info")

     return false
  end

  json = require "cjson"
  url = require "socket.url"
  --pcre = require "rex_pcre"

  --PCRE_UTF8_FLAG = pcre.flags().UTF8

  g.key["i"] = "info"
  g.domain = {
     ["www.youtube.com"] = info_youtube,
     ["www.youtu.be"] = info_youtube,
     ["youtube.com"] = info_youtube,
     ["youtu.be"] = info_youtube,

     ["www.vimeo.com"] = info_vimeo,
     ["vimeo.com"] = info_vimeo,

     ["www.reddit.com"] = info_reddit,
     ["np.reddit.com"] = info_reddit,
     ["pay.reddit.com"] = info_reddit,
     ["reddit.com"] = info_reddit
  }

end

function load_config()
   for name, info in pairs(g.option_list) do
      local opt_type = type(info.default)
      local value = weechat.config_get_plugin(name)
      if opt_type == "boolean" then
         if value ~= "yes" and value ~= "no" then
            g.config[name] = info.default
            weechat.config_set_plugin(name, info.default and "yes" or "no")
            weechat.config_set_desc_plugin(name, info.description)
         else
            g.config[name] = (value == "yes")
         end
      elseif opt_type == "number" then
         if not value or value == "" then
            g.config[name] = info.default
            weechat.config_set_plugin(name, info.default)
            weechat.config_set_desc_plugin(name, info.description)
         else
            g.config[name] = tonumber(value)
         end
      else
         if not value or value == "" then
            g.config[name] = info.default
            weechat.config_set_plugin(name, info.default)
            weechat.config_set_desc_plugin(name, info.description)
         else
            g.config[name] = value
         end
      end
   end

   if g.config.enable_secondary_mode and g.mode.valid.primary then
      table.insert(g.mode.order, "secondary")
      g.mode.valid.secondary = #g.mode.order
   end

   local value = weechat.config_get_plugin("mode")
   if not value or value == "" or not g.mode.valid[value] then
      weechat.config_set_plugin("mode", g.mode.order[1])
      weechat.config_set_desc_plugin(
         "mode",
         "Default mode to use. Valid values are: primary, clipboard, " ..
         "tmux, secondary")
      g.mode.current = g.mode.order[1] or ""
   else
      g.mode.current = value
   end

   if weechat.config_is_set_plugin("ext_cmd_1") ~= 1 then
      weechat.config_set_plugin("ext_cmd_1", "xdg-open")
      weechat.config_set_desc_plugin(
         "ext_cmd_1",
         "External command that will be executed when " ..
         "key 1 pressed during URL selection")
   end

   for index = 0, 9 do
      local opt_value = weechat.config_get_plugin("ext_cmd_" .. index)
      if opt_value and opt_value ~= "" then
         g.command.list[index] = opt_value
         g.key[index] = "exec " .. index
         g.command.total = g.command.total + 1
      end
   end
end

function config_cb(_, option_full_name, option_value)
   local name = option_full_name:match("([^%.]+)$")
   if g.option_list[name] then
      local option_type = type(g.option_list[name].default)
      if option_type == "boolean" then
         g.config[name] = option_value == "yes"
      elseif option_type == "number" then
         g.config[name] = tonumber(option_value)
      else
         g.config[name] = option_value
      end
   end
   return g.WEECHAT_RC_OK
end

function unload()
   weechat.config_set_plugin("mode", g.mode.current)
   weechat.config_set_plugin("show_keys", g.config.show_keys and "yes" or "no")

   if g.active_buffer then
      setup_key_bindings(false)
   end

   weechat.unhook_all()
end

function main_command_cb(data, buffer, arg)
   local op, param = arg:match("^([^ \t]*)[ \t]*(.*)$")

   if not g.active_buffer then
      if op == "bind" then
         bind_key(param, true)
      elseif op == "unbind" then
         bind_key(param, false)
      elseif op == "flush" then
         g.url.copied = {}
      elseif op == "copy" then
         return copy_url(param)
      else
         g.active_buffer = buffer
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
      elseif op == "info" then
         show_url_info()
      elseif op:match("^[%-%+]?%d+$") then
         select_url(tonumber(op))
      else
         finish_url_selection()
      end
   end
   return g.WEECHAT_RC_OK
end

function buffer_switch_cb(data, signal, buffer)
   if buffer ~= g.active_buffer then
      finish_url_selection()
   end
   return g.WEECHAT_RC_OK
end

function start_url_selection(show_all)
   collect_urls(show_all)
   if g.url.index > 0 then
      local cfg = weechat.config_get("weechat.bar.input.items")
      g.orig_bar_items = weechat.config_string(cfg)
      g.input_bar = weechat.bar_search("input")

      if g.input_bar and g.input_bar ~= "" then
         -- if i didn't include input_text, the cursor position will stay in
         -- current position.
         weechat.bar_set(g.input_bar, "items", "urlselect,input_text")
         setup_key_bindings(true)
         weechat.bar_item_update(g.script.name)
         g.buf_switch_hook = weechat.hook_signal(
            "buffer_switch",
            "buffer_switch_cb",
            "")
      else
         finish_url_selection()
      end
   end
end

function finish_url_selection()
   if g.active_buffer then
      setup_key_bindings(false)
      g.url.list, g.url.index, g.active_buffer = nil, nil, nil
      weechat.bar_item_update(g.script.name)

      if g.input_bar and g.input_bar ~= "" then
         weechat.bar_set(g.input_bar, "items", g.orig_bar_items)
         if g.buf_switch_hook ~= "" then
            weechat.unhook(g.buf_switch_hook)
         end
      end
   end
end

function bar_item_cb(data, item, window)
   if g.url.list and
      g.url.index and
      g.url.index ~= 0 and
      g.url.list[g.url.index] then

      local entry = g.url.list[g.url.index]
      local default_color = weechat.color(g.config.default_color)
      local key_color = weechat.color(g.config.key_color)

      local text = weechat.color(g.config.default_color) .. g.script.name .. ":";
      if g.mode.current ~= "" then
         text = text .. " " ..
                weechat.color(g.config.mode_color) ..
                g.mode.current
      end

      if g.config.show_keys then
         text = text ..
                string.format(
                  " %s<%s?%s> hide keys <%sup%s> prev <%sdown%s> next " ..
                  "<%stab%s> mode <%sctrl-c%s> cancel <%senter%s> copy",
                  default_color,
                  key_color,
                  default_color,
                  key_color,
                  default_color,
                  key_color,
                  default_color,
                  key_color,
                  default_color,
                  key_color,
                  default_color,
                  key_color,
                  default_color)

         for index = 0, 9 do
            if g.command.list[index] then
               text = text ..
                      string.format(
                        " %s<%s%d%s> %s",
                        default_color,
                        key_color,
                        index,
                        default_color,
                        g.command.list[index])
            end
         end

      end
      text = text ..
             default_color ..
             " #" ..
             weechat.color(g.config.index_color) ..
             g.url.index ..
             default_color ..
             ": "

      if g.config.show_nickname then
         local color = g.config.nickname_color
         if color == "" then
            color = weechat.info_get("irc_nick_color_name", entry.nick)
         end

         text = text ..
                weechat.color(color) ..
                entry.nick ..
                default_color ..
                ": "
      end

      text = text ..
             weechat.color(g.config.url_color) ..
             entry.value

      if entry.info and entry.info ~= "" then
         text = text .. "\r" .. entry.info
      end

      return text
   else
      return ""
   end
end

function toggle_key_help()
   g.config.show_keys = not g.config.show_keys
   weechat.bar_item_update(g.script.name)
end

function bind_key(param, flag)
   if not param or param == "" then
      list_ext_commands()
      return g.WEECHAT_RC_OK
   else
      local key, command = param:match("^(%d)[ \t]*(.*)")
      if not key then
         message("Please specify a key (0-9)")
         return g.WEECHAT_RC_ERROR
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
   local key_color = weechat.color(g.config.key_color)
   local default_color = weechat.color(g.config.default_color)

   message("External Commands:")
   for index = 0, 9 do
      if g.command.list[index] then
         message(string.format("%s%d%s: %s",
            key_color,
            index,
            default_color,
            g.command.list[index]))
      end
   end
end

function set_ext_command(key, command)
   if not command or command == "" then
      message("You must specify a command")
      return g.WEECHAT_RC_ERROR
   end

   local opt_name = "ext_cmd_" .. key
   weechat.config_set_plugin(opt_name, command)
   weechat.config_set_desc_plugin(
      opt_name,
      "External command that will be executed when " ..
      "key " .. key .. " pressed during URL selection")

   if not g.command.list[key] then
      g.command.list[key] = command
      g.key[key] = "/" .. g.script.name .. " exec " .. key
   end
   if g.config.noisy then
      message(string.format("Key %d bound to `%s`", key, command))
   end
   return g.WEECHAT_RC_OK
end

function unset_ext_command(key)
   if g.command.list[key] then
      g.command.list[key], g.key[key] = nil, nil
   end
   local opt_name = "ext_cmd_" .. key
   if weechat.config_is_set_plugin(opt_name) == 1 then
      if key == 1 then
         weechat.config_set_plugin(opt_name, "")
      else
         weechat.config_unset_plugin(opt_name)
      end
   end
   if g.config.noisy then
      message(string.format("Key %d unbound", key, command))
   end
   return g.WEECHAT_RC_OK
end

function switch_mode(param)
   if g.mode.current == "" then
      return
   end

   if not param then param = "next" end

   if g.mode.valid[param] then
      g.mode.current = param
   else
      local total = #g.mode.order
      local current_index = g.mode.valid[g.mode.current]

      local new_index = current_index + (param == "next" and 1 or -1)
      if new_index > total then
         new_index = 1
      elseif new_index < 1 then
         new_index = total
      end

      local new_mode = g.mode.current
      if g.mode.order[new_index] then
         new_mode = g.mode.order[new_index]
         if g.mode.valid[new_mode] then
            g.mode.current = new_mode
         end
      end
   end
   weechat.bar_item_update(g.script.name)
end

function setup_key_bindings(flag)
   local prefix = flag and "key_bind_" or "key_unbind_"
   local command
   for key, param in pairs(g.key) do
      if flag then
         command = "/" .. g.script.name .. " " .. param
      else
         command = ""
      end
      weechat.buffer_set(g.active_buffer, prefix .. key, command)
   end
end

function select_url(rel_pos)
   local total = #g.url.list
   if total > 0 then
      if rel_pos == "first" then
         g.url.index = 1
      elseif rel_pos== "last" then
         g.url.index = total
      else
         g.url.index = g.url.index + rel_pos
         if g.url.index < 1 then
            g.url.index = total
         elseif g.url.index > total then
            g.url.index = 1
         end
      end
      weechat.bar_item_update(g.script.name)
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
   local limit = os.time() - g.config.exp_time
   local temp = {}
   local removed = 0
   for u, t in pairs(g.url.copied) do
      if t >= limit then
         temp[u] = t
      else
         removed = removed + 1
      end
   end
   g.url.copied = temp
   if g.config.noisy and removed > 0 then
      message(removed .. " URLs removed")
   end
end

function collect_urls(show_all)
   local buf_lines = weechat.infolist_get("buffer_lines", g.active_buffer, "")
   local exists = {}

   g.url.list = {}
   local pattern = "(%a[%w%+%.%-]+://[%w:!/#_~@&=,;%+%?%[%]%.%%%-]+)([^%s]*)"
   local store_url = function (u, n)
      if not show_all and
         g.config.ignore_copied_url and
         g.url.copied[u] then
         return
      end
      if not exists[u] then
         table.insert(g.url.list, { value = u, nick = n })
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
               found = found:gsub("[,%.]+$", "")
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
   g.url.index = g.url.list[1] and 1 or 0
   g.url.total = #g.url.list
end

function get_url(u)
   if not u or u == "" then
      if g.url.index and g.url.list and g.url.list[g.url.index] then
         u = g.url.list[g.url.index].value
      end
   end
   return u
end

function mark_url_as_copied(u)
   g.url.copied[u] = os.time()
end

function copy_url(u)
   u = get_url(u)
   if u and u ~= "" then
      local cb = (g.mode.current == "tmux" and copy_into_tmux or copy_into_xsel)
      if cb(u) then
         if g.config.ignore_copied_url and not g.url.copied[u] then
            mark_url_as_copied(u)
         end
         return g.WEECHAT_RC_OK
      else
         return g.WEECHAT_RC_ERROR
      end
   else
      message("Empty URL")
      return g.WEECHAT_RC_ERROR
   end
end

function copy_into_xsel(u)
   local fp = io.popen("xclip -selection " .. g.mode.current, "w")
   if not fp then
      message("Unable to run `xclip`")
      return false
   end
   fp:write(u)
   fp:close()

   if g.config.noisy then
      message(string.format("Copied into %s selection: %s", g.mode.current, u))
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
   if g.command.list[index] then
      local u = get_url()
      if u and u ~= "" then
         if g.config.ignore_copied_url and not g.url.copied[u] then
            mark_url_as_copied(u)
         end
         local cmd = g.command.list[index]
         if cmd:sub(1, 2) == "#/" then
            weechat.command(g.active_buffer or "", cmd:sub(2) .. " " .. u)
         else
            local command = string.format("%s %q", cmd, u)
            weechat.hook_process(command, 0, "run_external_cb", "")
         end
         return g.WEECHAT_RC_OK
      end
   end
end

function run_external_cb(data, command, status, output, error)
   if status == g.WEECHAT_HOOK_PROCESS_ERROR then
      message(string.format("Unable to run `%s`: %s", command, error))
      return g.WEECHAT_RC_ERROR
   elseif status >= 0 then
      if g.config.noisy then
         if data and data ~= "" then
            message(string.format(data, output))
         else
            message(string.format("`%s` executed. Output: %s", command, output))
         end
      end
      return g.WEECHAT_RC_OK
   end
end

function parse_query_string(q)
   local parsed = {}
   for seg in q:gmatch("([^&]+)") do
      local _, _, key, value = seg:find("^([^=]+)=(.*)$")
      if not key then
         parsed[seg] = ""
      else
         local _, _, name, index = key:find("^([^%]]+)%[(.*)%]$")
         if not name then
            parsed[key] = value
         else
            if not parsed[name] or type(parsed[name]) ~= "table" then
               parsed[name] = {}
            end
            if not index or index == "" then
               table.insert(parsed[name], value)
            else
               parsed[name][index] = value
            end
         end
      end
   end
   return parsed
end

function get_duration(n)
   if not n or type(n) ~= "number" then
      return "00:00:00"
   else
      return string.format(
         "%02d:%02d:%02d",
         math.floor(n / 3600) % 24,
         math.floor(n / 60) % 60,
         n % 60)
   end
end

function format_info(info)
   local result = {}
   local key_color = weechat.color(g.config.key_color)
   local default_color = weechat.color(g.config.default_color)

   for _, entry in ipairs(info) do
      local line = string.format(
            "%s%s%s: %s",
            key_color,
            entry[1] or "???",
            default_color,
            entry[2] or "???")

      if entry[3] and type(entry[3]) == "table" then
         line = line .. " "
         for _, label in ipairs(entry[3]) do
            line = line .. string.format(
               "%s[%s%s%s]",
               default_color,
               key_color,
               label,
               default_color)
         end
      end
      table.insert(result, line)
   end
   return table.concat(result, "\r")
end

function parse_json_response(i, response)
   if not response or response == "" then
      g.url.list[i].info = nil
      return false
   else
      local parsed = json.decode(response)
      if not parsed or type(parsed) ~= "table" then
         g.url.list[i].info = "Unable to retrieve information for this URL"
         return false
      else
         if parsed.error then
            g.url.list[i].info = "Error: " .. parsed.error
            return false
         else
            return parsed
         end
      end
   end
end

function reformat_markdown(text)
   local replacement = {
      gt = ">",
      lt = "<",
      amp = "&"
   }

   text = text:gsub("\n", " \r")
   text = text:gsub("&([^;]+);", replacement)

   return " \r" .. text
end


function send_request(request_url, cb, index)
   g.url.list[index].info = "Retrieving information..."
   weechat.bar_item_update(g.script.name)
   weechat.hook_process(
      request_url,
      g.config.info_timeout,
      "receive_response_cb",
      index .. ":" .. cb)
end

function receive_response_cb(param, request_url, status, response, err)
   local _, _, i, cb = param:find("^(%d+):(.+)$")
   i = tonumber(i)
   cb = _G[cb]

   if status >= 0 then
      g.url.list[i].fetching = nil
      if err and err ~= "" then
         message(err)
         cb(i)
         return g.WEECHAT_RC_ERROR
      else
         if g.url.list[i].buffer then
            response = g.url.list[i].buffer .. response
            g.url.list[i].buffer = nil
         end
         return cb(i, response)
      end
   elseif status == g.WEECHAT_HOOK_PROCESS_ERROR then
      message(err)
      cb(i)
      return g.WEECHAT_RC_ERROR
   elseif status == g.WEECHAT_HOOK_PROCESS_RUNNING then
      if not g.url.list[i].buffer then
         g.url.list[i].buffer = response
      else
         g.url.list[i].buffer = g.url.list[i].buffer .. response
      end
   end
end

function info_youtube(i, current_url, parsed_url)
   local query = parse_query_string(parsed_url.query)
   if query.v then
      local api_url = string.format(
         "url:http://gdata.youtube.com/feeds/api/videos/%s?v=2&alt=jsonc",
         query.v)

      send_request(api_url, "display_youtube_info_cb", i)
   end
end

function display_youtube_info_cb(i, response)
   local parsed = parse_json_response(i, response)
   local ok = false
   if parsed then
      local stats = {
         get_duration(parsed.data.duration),
         (parsed.data.likeCount or 0) .. " likes",
         (parsed.data.commentCount or 0) .. " comments",
         (parsed.data.viewCount or 0) .. " views"
      }

      local param = {
         { "Title", parsed.data.title, stats },
         { "Uploaded by", parsed.data.uploader }
      }
      if parsed.data.category then
         table.insert(param, { "Category", parsed.data.category })
      end
      g.url.list[i].info = format_info(param)
      ok = true
   end
   weechat.bar_item_update(g.script.name)
   return (ok and g.WEECHAT_RC_OK or g.WEECHAT_RC_ERROR)
end

function info_vimeo(i, current_url, parsed_url)
   local segments = url.parse_path(parsed_url.path)
   if segments and segments[1] then
      local api_url = string.format(
         "url:http://vimeo.com/api/v2/video/%s.json",
         segments[1])

      send_request(api_url, "display_vimeo_info_cb", i)
   end
end

function display_vimeo_info_cb(i, response)
   local parsed = parse_json_response(i, response)
   local ok = false
   if parsed then
      parsed = parsed[1]
      local stats = {
         get_duration(parsed.duration),
         (parsed.stats_number_of_likes or 0) .. " likes",
         (parsed.stats_number_of_comments or 0) .. " comments",
         (parsed.stats_number_of_plays or 0) .. " plays"
      }

      local param = {
         { "Title", parsed.title, stats },
         { "Uploaded by", parsed.user_name }
      }

      if parsed.tags then
         table.insert(param, { "Tags", parsed.tags })
      end
      g.url.list[i].info = format_info(param)
      ok = true
   end
   weechat.bar_item_update(g.script.name)
   return (ok and g.WEECHAT_RC_OK or g.WEECHAT_RC_ERROR)
end

function info_reddit(i, current_url, parsed_url)
   local segments = url.parse_path(parsed_url.path)
   if segments and segments[1] and segments[2] then
      local cb = ""
      local path = {}
      if segments[1] == "r" and segments[2] then
         table.insert(path, segments[1])
         table.insert(path, segments[2])

         if segments[4] then
            table.insert(path, "comments")
            table.insert(path, segments[4])

            if segments[6] then
               cb = "display_reddit_comment_info_cb"
               table.insert(path, "dummy")
               table.insert(path, segments[6])
            else
               cb = "display_reddit_submission_info_cb"
            end
            table.insert(path, ".json")
         else
            cb = "display_subreddit_info_cb"
            table.insert(path, "about.json")
         end
      elseif segments[1] == "u" or segments[1] == "user" then
         cb = "display_reddit_user_info_cb"
         table.insert(path, "user")
         table.insert(path, segments[2])
         table.insert(path, "about.json")
      else
         return false
      end

      if #path > 0 then
         local request_url = "url:http://www.reddit.com/" .. table.concat(path, "/")
         send_request(request_url, cb, i)
      end
   end
end

function display_reddit_comment_info_cb(i, response)
   local parsed = parse_json_response(i, response)
   local ok = false
   if parsed then
      local comment = parsed[2].data.children[1].data
      local stats = {
         comment.ups .. " ups",
         comment.downs .. "downs"
      }

      local param = {
         { "Comment by ", comment.author, stats },
         { "Text", reformat_markdown(comment.body) }
      }

      g.url.list[i].info = format_info(param)
      weechat.bar_item_update(g.script.name)
      ok = true
   end
   weechat.bar_item_update(g.script.name)
   return (ok and g.WEECHAT_RC_OK or g.WEECHAT_RC_ERROR)
end

function display_reddit_submission_info_cb(i, response)
   local parsed = parse_json_response(i, response)
   local ok = false
   if parsed then
      local submission = parsed[1].data.children[1].data
      local stats = {
         submission.ups .. " ups",
         submission.downs .. " downs",
         submission.num_comments .. " comments"
      }

      if submission.over_18 then
         table.insert(stats, "NSFW")
      end

      local param = {
         { "Title", submission.title, stats },
         { "Submitted by", submission.author }
      }

      if not submission.is_self then
         table.insert(param, { "Link", submission.url })
      else
         table.insert(param, { "Text", reformat_markdown(submission.selftext)})
      end

      g.url.list[i].info = format_info(param)
      ok = true
   end
   weechat.bar_item_update(g.script.name)
   return (ok and g.WEECHAT_RC_OK or WEECHAT_RC_ERROR)
end

function display_subreddit_info_cb(i, response)
   local parsed = parse_json_response(i, response)
   local ok = false
   if parsed then
      local stats = { parsed.data.subscribers .. " subscribers" }
      if parsed.data.over18 then
         table.insert(stats, "NSFW")
      end

      local param = {
         { "Title", parsed.data.title, stats },
         {
            "Created at",
            os.date("%e %B %Y %H:%M:%S", parsed.data.created)
         }
      }

      if parsed.data.header_title ~= json.null and parsed.data.header_title ~= "" then
         table.insert(param, { "Caption", parsed.data.header_title })
      end
      g.url.list[i].info = format_info(param)
      ok = true
   end
   weechat.bar_item_update(g.script.name)
   return (ok and g.WEECHAT_RC_OK or g.WEECHAT_RC_ERROR)
end

function display_reddit_user_info_cb(i, response)
   local parsed = parse_json_response(i, response)
   local ok = false
   if parsed then
      ok = true
   end
   weechat.bar_item_update(g.script.name)
   return (ok and g.WEECHAT_RC_OK or g.WEECHAT_RC_ERROR)
end

function info_generic(i, current_url, parsed_url)
   local request_url = "url:" .. current_url
   send_request(request_url, "display_generic_info_cb", i)
end

function display_generic_info_cb(i, response)
   if response then
      local _, _, title = response:find("<title>([^<]*)</title>")
      if title then
         g.url.list[i].info = format_info({
            { "Title", title }
         })
      end
   else
      g.url.list[i].info = nil
   end
   weechat.bar_item_update(g.script.name)
   return g.WEECHAT_RC_OK
end

function show_url_info()
   if not g.url.list[g.url.index].fetching then
      local current = g.url.list[g.url.index].value
      local parsed = url.parse(current)

      if parsed and parsed.host then
         local host = string.lower(parsed.host)
         local cb
         if g.domain[host] then
            cb = g.domain[host]
         else
            cb = info_generic
         end
         g.url.list[g.url.index].fetching = true
         cb(g.url.index, current, parsed)
      end
   end
end

setup()

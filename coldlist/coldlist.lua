--[[
-- coldlist
--
-- A script that provides a bar item that works similar to Weechat's hotlist
-- but only for messages from buffers hidden behind currently zoomed buffer.
--
-- See g.defaults for list of options.
--
-- This script only has 1 command for now: `/coldlist clear` for clearing all
-- buffers in coldlist.
--
--
-- Author: tomoe-mami <rumia.youkai.of.dusk@gmail.com>
-- License: WTFPL
-- Requires: Weechat 0.4.3+
-- URL: https://github.com/tomoe-mami/weechat-scripts
--
--]]

local w = weechat
local g = {
   script = {
      name = "coldlist",
      author = "tomoe-mami <https://github.com/tomoe-mami>",
      version = "0.1",
      license = "WTFPL",
      description =
         "A bar item that works similar to Weechat's hotlist but only for " ..
         "messages from buffers hidden behind active zoomed buffer."
   },
   config = {},
   defaults = {
      short_name = {
         value = true,
         type = "boolean",
         related = "weechat.look.hotlist_short_names",
         description = "Set to 1 to use short buffer name and 0 for normal name"
      },
      separator = {
         value = ", ",
         type = "string",
         related = "weechat.look.hotlist_buffer_separator",
         description = "Separator for list of buffers"
      },
      prefix = {
         value = "C: ",
         type = "string",
         description = "Text before the list of buffers"
      },
      suffix = {
         value = "",
         type = "string",
         description = "Text after the list of buffers"
      },
      count_min_msg = {
         value = 2,
         type = "integer",
         related = "weechat.look.hotlist_count_min_msg",
         description =
            "The minimum amount of new messages required to make the message " ..
            "counter appear on each buffer entry"
      },
      color_default = {
         value = "bar_fg",
         type = "color",
         description = "Default color for bar item"
      },
      color_count_highlight = {
         value = "magenta",
         type = "color",
         related = "weechat.color.status_count_highlight",
         description = "Color for highlight counter"
      },
      color_count_msg = {
         value = "brown",
         type = "color",
         related = "weechat.color.status_count_msg",
         description = "Color for normal message counter"
      },
      color_count_private = {
         value = "green",
         type = "color",
         related = "weechat.color.status_count_private",
         description = "Color for private message counter"
      },
      color_bufnumber_highlight = {
         value = "lightmagenta",
         type = "color",
         related = "weechat.color.status_data_highlight",
         description = "Color for buffer number when there's a highlight"
      },
      color_bufnumber_msg = {
         value = "yellow",
         type = "color",
         related = "weechat.color.status_data_msg",
         description = 
            "Color for buffer number when there's normal incoming message"
      },
      color_bufnumber_private = {
         value = "green",
         type = "color",
         related = "weechat.color.status_data_private",
         description = "Color for buffer number when there's new private message"
      }
   },
   buffers = {
      -- i hate lua table

      -- this is for list of buffers that are in the coldlist
      list = {},

      -- this is map of positions of buffers inside the previous table.
      -- this is needed because lua does not support ordered hashtable.
      positions = {},

      -- this is for list of buffer numbers that are in the coldlist.
      numbers = {}
   }
}

function init_option(name, info)
   if w.config_is_set_plugin(name) == 0 then
      local val = info.value
      if info.related then
         if not info.type then
            info.type = "string"
         end
         local opt = w.config_get(info.related)
         if opt ~= "" then
            local f = w["config_" .. info.type]
            if f and type(f) == "function" then
               val = f(opt)
            else
               info.type = "string"
               val = w.config_string(opt)
            end
         end
      end
      if info.type == "boolean" then
         g.config[name] = (val == 1)
      else
         g.config[name] = val
      end
      w.config_set_plugin(name, val)
      if info.description then
         w.config_set_desc_plugin(name, info.description)
      end
   else
      local val = w.config_get_plugin(name)
      if info.type == "integer" then
         val = tonumber(val)
      elseif info.type == "boolean" then
         val = (val == "1")
      end
      g.config[name] = val
   end
end

function load_config()
   for opt_name, info in pairs(g.defaults) do
      init_option(opt_name, info)
   end
end

function print_cb(_, buffer, _, _, displayed, highlighted)
   if displayed == "1" then
      local buf_active = w.buffer_get_integer(buffer, "active")
      local buf_num = w.buffer_get_integer(buffer, "number")

      local wbuf = w.window_get_pointer(w.current_window(), "buffer")
      local wbuf_active = w.buffer_get_integer(wbuf, "active")
      local wbuf_num = w.buffer_get_integer(wbuf, "number")

      if buf_active == 0 and wbuf_num == buf_num and wbuf_active == 2 then
         local b = g.buffers
         if not b.positions[buffer] then
            local pos = #b.list + 1
            b.list[pos] = {
                pointer = buffer,
                count = 1,
                highlight = tonumber(highlighted)
             }

            b.positions[buffer] = pos
            if not b.numbers[buf_num] then
               b.numbers[buf_num] = {}
            end
            table.insert(b.numbers[buf_num], buffer)
         else
            local pos = b.positions[buffer]
            b.list[pos].count = b.list[pos].count + 1
            if highlighted == "1" then
               b.list[pos].highlight = b.list[pos].highlight + 1
            end
         end
         g.buffers = b
         w.bar_item_update(g.script.name)
      end
   end
   return w.WEECHAT_RC_OK
end

function bar_item_cb()
   local list, cfg = {}, g.config
   for _, buf in ipairs(g.buffers.list) do
      local name, key
      if cfg.short_name then
         key = "short_name"
      else
         key = "name"
      end
      name = w.buffer_get_string(buf.pointer, key)
      local number = w.buffer_get_integer(buf.pointer, "number")
      local buf_type = w.buffer_get_string(buf.pointer, "localvar_type")

      local num_color, entry
      if buf.highlight > 0 then
         num_color = cfg.color_bufnumber_highlight
      elseif buf_type == "private" then
         num_color = cfg.color_bufnumber_private
      else
         num_color = cfg.color_bufnumber_msg
      end
      entry = w.color(num_color) ..
              number ..
              w.color(cfg.color_default) ..
              ":" ..
              name

      local counter = {}
      if cfg.count_min_msg > 0 and buf.count >= cfg.count_min_msg then
         local count_color
         if buf_type == "private" then
            count_color = cfg.color_count_private
         else
            count_color = cfg.color_count_msg
         end
         table.insert(counter, w.color(count_color) .. buf.count)
      end
      if buf.highlight > 0 then
         table.insert(
            counter,
            w.color(cfg.color_count_highlight) .. buf.highlight)
      end

      if #counter > 0 then
         entry = entry ..
                 "(" ..
                 table.concat(counter, w.color(cfg.color_default) .. ",") ..
                 w.color(cfg.color_default) ..
                 ")"
      end
      table.insert(list, entry)
   end
   local result = table.concat(list, cfg.separator)
   if result ~= "" then
      return w.color(cfg.color_default) ..
             cfg.prefix ..
             result ..
             cfg.suffix
    else
      return ""
    end
end

function update_positions(start_pos)
   local end_pos = #g.buffers.list
   if not start_pos then
      start_pos = 1
   end

   for i = start_pos, end_pos do
      if g.buffers.list[i] then
         local pointer = g.buffers.list[i].pointer
         g.buffers.positions[pointer] = i
      end
   end
end

function buffer_unzoom_cb(_, signal, buffer)
   local buffer_num = w.buffer_get_integer(buffer, "number")
   if g.buffers.numbers[buffer_num] then
      for _, pointer in ipairs(g.buffers.numbers[buffer_num]) do
         local pos = g.buffers.positions[pointer]
         g.buffers.positions[pointer] = nil
         table.remove(g.buffers.list, pos)
      end
      g.buffers.numbers[buffer_num] = nil
      update_positions()
      w.bar_item_update(g.script.name)
   end
   return w.WEECHAT_RC_OK
end

function buffer_switch_cb(_, signal, buffer)
   if g.buffers.positions[buffer] then
      local pos = g.buffers.positions[buffer]
      local pointer = g.buffers.list[pos].pointer
      local num = w.buffer_get_integer(pointer, "number")

      table.remove(g.buffers.list, pos)
      g.buffers.positions[buffer] = nil

      if g.buffers.numbers[num] then
         local copy = {}
         for _, v in pairs(g.buffers.numbers[num]) do
            if v ~= buffer then
               table.insert(copy, buffer)
            end
         end
         if #copy > 0 then
            g.buffers.numbers[num] = copy
         else
            g.buffers.numbers[num] = nil
         end
      end
      update_positions(pos)
      w.bar_item_update(g.script.name)
   end
   return w.WEECHAT_RC_OK
end

function config_cb(_, option_name, option_value)
   local name = option_name:match("([^%.]+)$")
   if g.defaults[name] then
      if g.defaults[name].type == "integer" then
         option_value = tonumber(option_value)
      elseif g.defaults[name].type == "boolean" then
         option_value = (option_value == "1")
      end
      g.config[name] = option_value
      w.bar_item_update(g.script.name)
   end
   return w.WEECHAT_RC_OK
end

function command_cb(_, buffer, arg)
   if arg == "clear" then
      g.buffers = {
         list = {},
         numbers = {},
         positions = {}
      }
      w.bar_item_update(g.script.name)
   end
   return w.WEECHAT_RC_OK
end

function setup()
   w.register(
      g.script.name,
      g.script.author,
      g.script.version,
      g.script.license,
      g.script.description,
      "", "")

   load_config()

   w.bar_item_new(g.script.name, "bar_item_cb", "")
   w.hook_signal("buffer_unzoomed", "buffer_unzoom_cb", "")
   w.hook_signal("buffer_switch", "buffer_switch_cb", "")
   w.hook_config("plugins.var.lua." .. g.script.name .. ".*", "config_cb", "")
   w.hook_print("", "irc_privmsg", "", 0, "print_cb", "")
   w.hook_command(
      g.script.name,
      "Manage coldlist. Currently it only supports clearing the coldlist.",
      "clear",
      "clear: Clear the coldlist",
      "clear",
      "command_cb",
      "")
end

setup()

local w = weechat
local g = {
   script = {
      name = "pastebuf",
      author = "tomoe-mami <https://github.com/tomoe-mami>",
      version = "0.1",
      license = "WTFPL",
      description = "View text from various pastebin sites inside a buffer."
   },
   config = {},
   defaults = {
      fetch_timeout = {
         value = 12000,
         type = "number",
         description = "Timeout for fetching URL (in milliseconds)"
      },
      highlighter_timeout = {
         value = 3000,
         type = "number",
         description = "Timeout for syntax highlighter (in milliseconds)"
      },
      show_line_number = {
         value = true,
         type = "boolean",
         description = "Show line number"
      },
      color_line_number = {
         value = "default,darkgray",
         type = "string",
         description = "Color for line number"
      },
      color_line = {
         value = "default,default",
         type = "string",
         description = "Color for line content"
      },
      syntax_highlighter = {
         value = "",
         type = "string",
         description =
            "External command that will be used as syntax highlighter. " ..
            "$lang will be replaced by the name of syntax language"
      },
      indent_width = {
         value = 4,
         type = "number",
         description = "Indentation width"
      }
   },
   sites = {
      ["bpaste.net"] = {
         pattern = "^http://bpaste%.net/show/(%w+)",
         raw = "http://bpaste.net/raw/%s/"
      },
      ["dpaste.com"] = {
         pattern = "^http://dpaste%.com/(%w+)",
         raw = "http://dpaste.com/%s/plain/"
      },
      ["dpaste.de"] = {
         pattern = "^https://dpaste%.de/(%w+)",
         raw = "https://dpaste.de/%s/raw"
      },
      ["fpaste.org"] = {
         pattern = "^http://fpaste%.org/(%w+/?%w*)",
         raw = "http://fpaste.org/%s/raw"
      },
      ["gist.github.com"] = {
         pattern = "^https://gist%.github%.com/([^/]+/[^/]+)",
         raw = "https://gist.github.com/%s/raw" -- default raw url for first file
                                                -- in a gist
      },
      ["ideone.com"] = {
         pattern = "^http://ideone%.com/(%w+)",
         raw = "http://ideone.com/plain/%s"
      },
      ["sprunge.us"] = {
         pattern = "^http://sprunge%.us/(%w+)",
         raw = "http://sprunge.us/%s"
      },
      ["paste.debian.net"] = {
         pattern = "^http://paste%.debian%.net/(%d+)",
         raw = "http://paste.debian.net/plain/%s"
      },
      ["pastebin.ca"] = {
         pattern = "^http://pastebin%.ca/(%w+)",
         raw = "http://pastebin.ca/raw/%s"
      },
      ["pastebin.com"] = {
         pattern = "^http://pastebin%.com/(%w+)",
         raw = "http://pastebin.com/raw.php?i=%s"
      },
      ["pastebin.osuosl.org"] = {
         pattern = "^http://pastebin%.osuosl%.org/(%w+)",
         raw = "http://pastebin.osuosl.org/%s/raw/"
      },
      ["pastie.org"] = {
         raw = "http://pastie.org/pastes/%s/download"
      }
   },
   keys = {
      ["meta2-A"]    = "/window scroll -1",           -- arrow up
      ["meta2-B"]    = "/window scroll 1",            -- arrow down
      ["meta2-C"]    = "/window scroll_horiz 1",      -- arrow right
      ["meta2-D"]    = "/window scroll_horiz -1",     -- arrow left
      ["meta-OA"]    = "/window scroll -10",          -- ctrl+arrow up
      ["meta-OB"]    = "/window scroll 10",           -- ctrl+arrow down
      ["meta-OC"]    = "/window scroll_horiz 10",     -- ctrl+arrow right
      ["meta-OD"]    = "/window scroll_horiz -10",    -- ctrl+arrow left
      ["meta2-1~"]   = "/window scroll_top",          -- home
      ["meta2-4~"]   = "/window scroll_bottom",       -- end
      ["meta-c"]     = "/buffer close"                -- alt+c
   },
   buffers = {},
   actions = {},
   sgr = {
      attributes = {
         [1] = "*", -- bold
         [3] = "/", -- italic
         [4] = "_", -- underline
         [7] = "!"  -- inverse
      },
      colors = {
         [ 0] = "black",
         [ 1] = "red",
         [ 2] = "green",
         [ 3] = "yellow",
         [ 4] = "blue",
         [ 5] = "magenta",
         [ 6] = "cyan",
         [ 7] = "gray",

         [ 8] = "darkgray",
         [ 9] = "lightred",
         [10] = "lightgreen",
         [11] = "brown",
         [12] = "lightblue",
         [13] = "lightmagenta",
         [14] = "lightcyan",
         [15] = "white"
      }
   }
}

function prepare_modules()
   local modules = {
      cjson = "json"
   }

   local module_exists = function (name)
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

   for name, alias in pairs(modules) do
      if module_exists(name) then
         _G[alias] = require(name)
      end
   end
end

function convert_plugin_option_value(opt_type, opt_value)
   if opt_type == "number" or opt_type == "boolean" then
      opt_value = tonumber(opt_value)
      if opt_type == "boolean" then
         opt_value = (opt_value ~= 0)
      end
   end
   return opt_value
end

function load_config()
   for opt_name, info in pairs(g.defaults) do
      if w.config_is_set_plugin(opt_name) == 0 then
         local val
         if info.type == "boolean" then
            val = info.value and 1 or 0
         elseif info.type == "number" then
            val = info.value or 0
         else
            val = info.value or ""
         end
         w.config_set_plugin(opt_name, val)
         w.config_set_desc_plugin(opt_name, info.description or "")
         g.config[opt_name] = val
      else
         local val = w.config_get_plugin(opt_name)
         g.config[opt_name] = convert_plugin_option_value(info.type, val)
      end
   end
end

function config_cb(_, opt_name, opt_value)
   local name = opt_name:match("^plugins%.var%.lua%." .. g.script.name .. "%.(.+)$")
   if name and g.defaults[name] then
      g.config[name] = convert_plugin_option_value(g.defaults[name].type, opt_value)
   end
end

function bind_keys(buffer, flag)
   local prefix = flag and "key_bind_" or "key_unbind_"
   for key, command in pairs(g.keys) do
      w.buffer_set(buffer, prefix .. key, flag and command or "")
   end
end

-- only expands tabs at the start of line
function expand_indent(s)
   return s:gsub("^(\t+)", function (t)
      return string.rep(" " , #t * g.config.indent_width)
   end)
end

-- crude converter from csi sgr colors to weechat color
function convert_csi_sgr(text)
   local fg, bg, attr = "", "", "|"

   local shift_param = function(s)
      if s then
         local p1, p2, chunk = s:find("^(%d+);?")
         if p1 then
            return chunk, s:sub(p2 + 1)
         end
      end
   end

   local convert_cb = function(code)
      local chunk, code = shift_param(code)
      while chunk do
         chunk = tonumber(chunk)
         if chunk == 0 then
            attr = ""
         elseif g.sgr.attributes[chunk] then
            attr = g.sgr.attributes[chunk]
         elseif chunk >= 30 and chunk <= 37 then
            fg = g.sgr.colors[ chunk - 30 ]
         elseif chunk == 38 then
            local c2, code = shift_param(code)
            fg, c2 = "default", tonumber(c2)
            if c2 == 5 then
               local c3, code = shift_param(code)
               if c3 then
                  fg = tonumber(c3)
               end
            end
         elseif chunk == 39 then
            fg = "default"
         elseif chunk >= 40 and chunk <= 47 then
            bg = g.sgr.colors[ chunk - 40 ]
         elseif chunk == 48 then
            local c2, code = shift_param(code)
            bg, c2 = "default", tonumber(c2)
            if c2 == 5 then
               local c3, code = shift_param(code)
               if c3 then
                  bg = tonumber(c3)
               end
            end
         elseif chunk == 49 then
            bg = "default"
         elseif chunk >= 90 and chunk <= 97 then
            fg = g.sgr.colors[ chunk - 82 ]
         elseif chunk >= 100 and chunk <= 107 then
            bg = g.sgr.colors[ chunk - 92 ]
         end
         chunk, code = shift_param(code)
      end
      local result
      if fg == "" and bg == "" and attr == "" then
         result = "reset"
      else
         result = attr .. fg
         if bg and bg ~= "" then
            result = result .. "," .. bg
         end
      end
      return w.color(result)
   end

   return text:gsub("\27%[([%d;]*)m", convert_cb)
end

function message(s)
   w.print("", g.script.name .. "\t" .. s)
end

function get_site_config(u)
   local host = u:match("^https?://([^/]+)")
   if host then
      if host:match("^www%.") then
         host = host:sub(5)
      end
      if g.sites[host] then
         local site = g.sites[host]
         if site.handler then
            site.url = u
            return site
         else
            local id = u:match(site.pattern)
            if id then
               site.host = host
               site.id = id
               site.url = u
               return site
            end
         end
      end
   end
end

function buffer_close_cb(_, buffer)
   local short_name = w.buffer_get_string(buffer, "short_name")
   if g.buffers[short_name] then
      local buffer = g.buffers[short_name]
      if buffer.hook and buffer.hook ~= "" then
         w.unhook(buffer.hook)
      end
      if buffer.file and io.type(buffer.file) == "file" then
         buffer.file:close()
      end
      if buffer.tmp_name then
         os.remove(buffer.tmp_name)
      end
      g.buffers[short_name] = nil
   end
end

function action_save(buffer, short_name, filename)
   if not filename or filename == "" then
      message("You need to specify destination filename after `save`")
   else
      filename = filename:gsub("^~/", os.getenv("HOME") .. "/")
      local output = open_file(filename, "w")
      if output then
         local input = open_file(buffer.tmp_name)
         if input then
            output:setvbuf("no")
            local chunk_size, written, chunk = 64 * 1024, 0
            chunk = input:read(chunk_size)
            while chunk do
               output:write(chunk)
               written = written + #chunk
               chunk = input:read(chunk_size)
            end
            input:close()
            message(string.format(
               "%d byte%s written to %s",
               written,
               (written == 1 and "" or "s"),
               filename))
         end
         output:close()
      end
   end
end

function action_change_language(buffer, short_name, new_lang)
   if not g.config.syntax_highlighter or g.config.syntax_highlighter == "" then
      return
   end

   new_lang = new_lang:match("^%s*(%S+)")
   if not new_lang then
      message("You need to specify the name of syntax language after `lang`")
   else
      local current_lang = w.buffer_get_string(buffer.pointer, "localvar_lang")
      new_lang = new_lang:lower()
      if current_lang ~= new_lang then
         local fp = open_file(buffer.tmp_name)
         if fp then
            buffer.file = fp
            w.buffer_set(buffer.pointer, "localvar_set_lang", new_lang)
            run_syntax_highlighter(short_name, fp)
            fp:close()
            buffer.file = nil
         end
      end
   end
end

function buffer_input_cb(_, pointer, input)
   local action, param = input:match("^%s*(%S+)%s*(.*)%s*$")
   if action then
      local short_name = w.buffer_get_string(pointer, "short_name")
      local buffer = g.buffers[short_name]
      if buffer then
         if buffer.hook or (buffer.file and io.type(buffer.file) == "file") then
            message("It's currently not possible to perform any action while the " ..
                    "paste is still being fetched or its content is still being processed")
            return w.WEECHAT_RC_OK
         end
         if g.actions[action] then
            local callback = g.actions[action]
            callback(buffer, short_name, param)
         else
            message(string.format("Unknown action: %s", action))
         end
      end
   end
   return w.WEECHAT_RC_OK
end

function create_buffer(site)
   local short_name = string.format("%s:%s", site.host, site.id)
   local name = string.format("%s:%s", g.script.name, short_name)
   local buffer = w.buffer_new(name, "buffer_input_cb", "", "buffer_close_cb", "")

   if buffer and buffer ~= "" then
      w.buffer_set(buffer, "type", "free")
      w.buffer_set(buffer, "short_name", short_name)
      w.buffer_set(buffer, "display", "1")
      bind_keys(buffer, true)

      g.buffers[short_name] = { pointer = buffer }
      return g.buffers[short_name], short_name
   end
end

function request_raw_paste(raw_url, short_name)
   local tmp_name = os.tmpname()
   local options = {
      useragent = g.useragent,
      file_out = tmp_name
   }

   g.buffers[short_name].tmp_name = tmp_name
   g.buffers[short_name].hook = w.hook_process_hashtable(
      "url:" .. raw_url,
      options,
      g.config.fetch_timeout,
      "receive_raw_paste_cb",
      short_name)
end

function receive_raw_paste_cb(short_name, request_url, status, response, err)
   if g.buffers[short_name] then
      local buffer = g.buffers[short_name]
      local is_complete = (status == 0)

      if status == 0 then
         if buffer.hook then
            buffer.hook = nil
         end
         display_paste(short_name)
         return w.WEECHAT_RC_OK
      elseif status >= 1 or status == w.WEECHAT_HOOK_PROCESS_ERROR then
         if not err or err == "" then
            err = "Unable to fetch raw paste"
         end
         message(string.format("Error %d: %s", status, err))
         w.buffer_close(buffer.pointer)
         return w.WEECHAT_RC_ERROR
      end
   end
end

function read_file(fp)
   local lines, n = {}, 0
   for line in fp:lines() do
      n = n + 1
      lines[n] = line
   end
   return lines, n
end

function display_plain(short_name, fp)
   local pointer = g.buffers[short_name].pointer
   local total_lines = 0
   if g.config.show_line_number then
      local lines
      lines, total_lines = read_file(fp)
      if lines then
         local num_col_width = #tostring(total_lines)
         local y = 0
         for _, line in ipairs(lines) do
            print_line(pointer, y, num_col_width, expand_indent(line))
            y = y + 1
         end
      end
   else
      for line in fp:lines() do
         print_line(pointer, total_lines, nil, expand_indent(line))
         total_lines = total_lines + 1
      end
   end
   w.buffer_set(pointer, "localvar_total_lines", total_lines)
end

function display_highlighted(short_name)
   local buffer = g.buffers[short_name]
   local total_lines = 0

   buffer.highlighted = convert_csi_sgr(buffer.highlighted)
   if g.config.show_line_number then
      local _
      _, total_lines = string.gsub(buffer.highlighted .. "\n", ".-\n[^\n]*", "")
      local num_col_width = #tostring(total_lines)
      local y = 0
      for line in buffer.highlighted:gmatch("(.-)\n") do
         print_line(buffer.pointer, y, num_col_width, line)
         y = y + 1
      end
   else
      for line in buffer.highlighted:gmatch("(.-)\n") do
         print_line(buffer.pointer, total_lines, nil, line)
         total_lines = total_lines + 1
      end
   end
   buffer.highlighted = nil
   w.buffer_set(pointer, "localvar_total_lines", total_lines)
end

function syntax_highlight_cb(short_name, cmd, status, output, err)
   local is_complete = (status == 0)
   if is_complete or status == w.WEECHAT_HOOK_PROCESS_RUNNING then
      local buffer = g.buffers[short_name]
      buffer.highlighted = buffer.highlighted .. output
      if is_complete then
         display_highlighted(short_name)
         return w.WEECHAT_RC_OK
      end
   elseif status >= 1 or status == w.WEECHAT_HOOK_PROCESS_ERROR then
      if not err or err == "" then
         err = "Unable to run syntax highlighter"
      end
      message(string.format("Error %d: %s", status, err))
      return w.WEECHAT_RC_ERROR
   end
end

function run_syntax_highlighter(short_name, fp)
   local buffer = g.buffers[short_name]
   local cmd = w.buffer_string_replace_local_var(buffer.pointer, g.config.syntax_highlighter)
   buffer.highlighted = ""

   local hook = w.hook_process_hashtable(
      cmd,
      { stdin = "1" },
      g.config.highlighter_timeout,
      "syntax_highlight_cb",
      short_name)

   if hook and hook ~= "" then
      for line in fp:lines() do
         w.hook_set(hook, "stdin", expand_indent(line) .. "\n")
      end
      w.hook_set(hook, "stdin_close", "")
   end
end

function open_file(filename, mode)
   local fp = io.open(filename, mode or "r")
   if not fp then
      message(string.format("Unable to open file %s", filename))
   else
      return fp
   end
end

function display_paste(short_name)
   local buffer = g.buffers[short_name]
   local fp = open_file(buffer.tmp_name)
   if fp then
      buffer.file = fp
      local func
      local lang = w.buffer_get_string(buffer.pointer, "localvar_lang")

      if g.config.syntax_highlighter
         and g.config.syntax_highlighter ~= ""
         and lang and lang ~= "" then
         func = run_syntax_highlighter
      else
         func = display_plain
      end

      func(short_name, fp)
      fp:close()
      buffer.file = nil

      w.buffer_set(
         buffer.pointer,
         "title",
         string.format(
            "%s: %s",
            g.script.name,
            w.buffer_get_string(buffer.pointer, "localvar_url")))
   end
end

function print_line(buffer, y, num_width, content)
   local line = w.color(g.config.color_line) .. " " .. content
   if num_width then
      line = string.format(
         "%s %" .. num_width .. "d %s",
         w.color(g.config.color_line_number),
         y + 1,
         line)
   end
   w.print_y(buffer, y, line)
end

function gist_display_file(main_id, main_url, entry)
   local param = {
      host = "gist.github.com",
      id = string.format("%s/%s", main_id, entry.filename)
   }

   local buffer, short_name = create_buffer(param)
   if buffer then
      local use_highlighter = false
      if entry.language and entry.language ~= json.null then
         w.buffer_set(buffer.pointer, "localvar_set_lang", entry.language:lower())
         if g.config.syntax_highlighter and g.config.syntax_highlighter ~= "" then
            use_highlighter = true
         end
      end

      buffer.tmp_name = os.tmpname()
      local fp = io.open(buffer.tmp_name, "w+")
      if fp then
         buffer.file = fp
         fp:setvbuf("no")
         fp:write(entry.content)
         fp:seek("set")

         if use_highlighter then
            run_syntax_highlighter(short_name, fp)
         else
            display_plain(short_name, fp)
         end
         fp:close()
         buffer.file = nil

         w.buffer_set(
            buffer.pointer,
            "title",
            string.format("%s: %s#%s", g.script.name, main_url, entry.filename))
      end
   end
end

function gist_process_info(buffer, short_name)
   if not buffer.temp or buffer.temp == "" then
      message("Gist error: No response received")
   end
   local info = json.decode(buffer.temp)
   if info and type(info) == "table" then
      if info.message then
         message(string.format("Gist error: %s", info.message))
      else
         if info.files and type(info.files) == "table" then
            for _, entry in pairs(info.files) do
               gist_display_file(info.id, info.html_url, entry)
            end
         end
      end
   else
      message("Gist error: Unable to parse response")
   end
end

function gist_info_cb(short_name, url, status, response, err)
   local buffer = g.buffers[short_name]
   if buffer then
      if status == 0 or status == w.WEECHAT_HOOK_PROCESS_RUNNING then
         buffer.temp = buffer.temp .. response
         if status == 0 then
            gist_process_info(buffer, short_name)
         end
      elseif status >= 1 or status == w.WEECHAT_HOOK_PROCESS_ERROR then
         if not err or err == "" then
            err = "Unable to get info from " .. url
         end
         message(string.format("Error %d: %s", status, err))
      end
   end
end

function handler_gist(site, url)
   local first, second = url:match("^https://gist%.github%.com/([^/]+)/?([^/]*)")
   local gist_id
   if second and second ~= "" then
      gist_id = second
   else
      gist_id = first
   end

   local short_name = "gist.github.com:" .. gist_id
   if not g.buffers[short_name] then
      local api_url = string.format("https://api.github.com/gists/%s", gist_id)
      g.buffers[short_name] = { temp = "" }
      g.buffers[short_name].hook = w.hook_process_hashtable(
         "url:" .. api_url,
         { useragent = g.useragent },
         g.config.fetch_timeout,
         "gist_info_cb",
         short_name)
   end
end

function handler_pastie(site, url, lang)
   local first, second = url:match("^http://pastie%.org/(%w+)/?(%w*)")
   local pastie_id
   if first == "pastes" and second and second ~= "" then
      pastie_id = second
   else
      pastie_id = first
   end

   site = {
      url = url,
      raw = site.raw,
      host = "pastie.org",
      id = pastie_id
   }

   handler_normal(site, url, lang)
end

function handler_normal(site, url, lang)
   local short_name = string.format("%s:%s", site.host, site.id)
   if g.buffers[short_name] then
      local pointer = g.buffers[short_name].pointer
      if pointer then
         w.buffer_set(pointer, "display", "1")
      end
   else
      local buffer, short_name = create_buffer(site)
      if not buffer.hook then
         local raw_url = string.format(site.raw, site.id)
         local title = string.format("%s: Fetching %s", g.script.name, site.url)

         w.buffer_set(buffer.pointer, "title", title)
         w.buffer_set(buffer.pointer, "localvar_set_url", url)
         w.buffer_set(buffer.pointer, "localvar_set_host", site.host)
         w.buffer_set(buffer.pointer, "localvar_set_id", site.id)

         if lang and lang ~= "" then
            w.buffer_set(buffer.pointer, "localvar_set_lang", lang:lower())
         end
         request_raw_paste(raw_url, short_name)
      end
   end
end

function open_paste(url, lang)
   local site = get_site_config(url)
   if not site then
      message("Unsupported site: " .. url)
      return w.WEECHAT_RC_OK
   end

   if site.handler and type(site.handler) == "function" then
      site.handler(site, url, lang)
   else
      handler_normal(site, url, lang)
   end
   return w.WEECHAT_RC_OK
end

function command_cb(_, current_buffer, param)
   local url, lang = param:match("^%s*(%S+)%s*(%S*)")
   if not url then
      message(string.format("Usage: /%s <pastebin-url> [syntax-language]", g.script.name))
   else
      open_paste(url, lang)
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

   prepare_modules()
   if json then
      g.sites["gist.github.com"].handler = handler_gist
   end
   g.sites["pastie.org"].handler = handler_pastie

   load_config()
   w.hook_config("plugins.var.lua." .. g.script.name .. ".*", "config_cb", "")
   g.useragent = string.format("%s v%s", g.script.name, g.script.version)

   g.actions = {
      lang = action_change_language,
      save = action_save
   }

   local sites = {}
   for name,_ in pairs(g.sites) do
      table.insert(sites, name)
   end

   local supported_sites = ""
   if #sites > 0 then
      supported_sites = "\nSupported sites: " .. table.concat(sites, ", ")
   end

   w.hook_command(
      g.script.name,
      "Open a buffer and view the content of a paste" .. supported_sites,
      "paste-url [syntax-language]",

      "paste-url:       URL of the paste\n" ..
      "syntax-language: Optional language for syntax highlighting\n",
      "",
      "command_cb",
      "")
end

setup()

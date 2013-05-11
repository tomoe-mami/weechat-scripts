w = weechat
urlselect = {
   script = {
      name = "urlselect",
      author = "rumia <https://github.com/rumia>",
      version = "0.1",
      license = "WTFPL",
      description =
         "Selects URL in a buffer and copy it into clipboard/tmux paste " ..
         "buffer or execute external command on it"
   },
   active_buffer = false,
   url = {
      list = {},
      copied = {},
      index = 0
   },
   mode = {
      valid = {},
      order = {},
      current = ""
   },
   config = {},
   external_commands = {},
   key_bindings = {
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
}

local function urlselect.message(text)
   w.print("", SCRIPT_NAME .. "\t" .. text)
end

function urlselect.setup()
   if os.execute("type xclip >/dev/null 2>&1") == 0 then
      self.mode.order = { "primary", "clipboard" }
      self.mode.valid = { primary = 1, clipboard = 2 }
   end

   local is_tmux = os.getenv("TMUX")
   if is_tmux and #is_tmux > 0 then
      table.insert(self.mode.order, "tmux")
      self.mode.valid.tmux = #self.mode.order
   end

   if #self.mode.order < 1 then
      error("You need xclip and/or tmux to use this script.")
   else
      w.register(
         self.script.name,
         self.script.author,
         self.script.version,
         self.script.license,
         self.script.description,
         "urlselect_cb_unload", "")

      local total_external_commands = self.load_config()
      w.bar_item_new(self.script.name, "urlselect_cb_bar_item", "")
      w.hook_command(
         self.script.name, 
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

         "urlselect_cb_main_command", "")

      if self.config.noisy then
         local msg = string.format(
            "%sSetup complete. Ignore copied URL: %s%s%s. Noisy: %syes%s. " ..
            "%s%d%s external commands. Available modes:",
            w.color(self.config.default_color),
            w.color(self.config.key_color),
            (self.config.ignore_copied_url and "yes" or "no"),
            w.color(self.config.default_color),
            w.color(self.config.key_color),
            w.color(self.config.default_color),
            w.color(self.config.key_color),
            total_external_commands,
            w.color(self.config.default_color))

         for index, name in ipairs(self.mode.order) do
            local entry = string.format("%d. %s", index, name)
            if name == mode.current then
               entry = w.color(config.key_color) ..
                       entry ..
                       w.color(config.default_color)
            end
            msg = msg .. " " .. entry
         end
         self.message(msg)
      end
   end
end

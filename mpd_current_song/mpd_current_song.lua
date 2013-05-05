SCRIPT_NAME    = "mpd_current_song"
SCRIPT_AUTHOR  = "rumia <https://github.com/rumia>"
SCRIPT_VERSION = "0.1"
SCRIPT_LICENSE = "WTFPL"
SCRIPT_DESCR   = "Bar item for showing currently playing song on MPD"

client_command = "mpc"
song_format    = "MPD: [[%artist% - ]%title%[ (%album%)]]|[%file%]"
default_text   = "MPD: (not playing)"
timer_interval = 10
timer_hook     = false
current_song   = ""

function setup()
   weechat.register(
      SCRIPT_NAME,
      SCRIPT_AUTHOR,
      SCRIPT_VERSION,
      SCRIPT_LICENSE,
      SCRIPT_DESCR,
      "", "")

   load_config()

   weechat.bar_item_new(SCRIPT_NAME, "bar_item_cb", "")
   weechat.hook_config("plugins.var.lua." .. SCRIPT_NAME .. ".*", "config_cb", "")

   setup_timer()
end

function w(name)
   if type(weechat[name]) == "function" then
      return weechat[name]()
   else
      return weechat[name]
   end
end

function load_config()
   if weechat.config_is_set_plugin("client") ~= 1 then
      weechat.config_set_plugin("client", client_command)
      weechat.config_set_desc_plugin(
         "client",
         "File name or full path of MPD client (default: mpc)")
   else
      client_command = weechat.config_get_plugin("client")
   end

   if weechat.config_is_set_plugin("format") ~= 1 then
      weechat.config_set_plugin("format", song_format)
      weechat.config_set_desc_plugin(
         "format",
         "Format of song. See explanation of -f option in mpc man page " ..
         "to see a list of valid formats")
   else
      song_format = weechat.config_get_plugin("format")
   end

   if weechat.config_is_set_plugin("default") ~= 1 then
      weechat.config_set_plugin("default", default_text)
      weechat.config_set_desc_plugin(
         "default",
         "Default text to be displayed if current song is empty")
   else
      default_text = weechat.config_get_plugin("default")
   end

   if weechat.config_is_set_plugin("interval") ~= 1 then
      weechat.config_set_plugin("interval", timer_interval)
      weechat.config_set_desc_plugin(
         "interval",
         "Update interval (in seconds)")
   else
      timer_interval = tonumber(weechat.config_get_plugin("interval"))
   end
end

function bar_item_cb()
   return current_song == "" and default_text or current_song
end

function config_cb(_, opt_name, opt_value)
   if opt_name == "plugins.var.lua." .. SCRIPT_NAME .. ".format" then
      song_format = opt_value
   elseif opt_name == "plugins.var.lua." .. SCRIPT_NAME .. ".default" then
      default_text = opt_value
   elseif opt_name == "plugins.var.lua." .. SCRIPT_NAME .. ".client" then
      client_command = opt_value
   elseif opt_name == "plugins.var.lua." .. SCRIPT_NAME .. ".interval" then
      timer_interval = tonumber(opt_value)
      setup_timer()
   end
   return w("WEECHAT_RC_OK")
end

function timer_cb()
   local timeout = (timer_interval * 1000) - 500
   if timeout < 0 then
      timout = 0
   end
   local args = { arg1 = "current", arg2 = "--format", arg3 = song_format }
   weechat.hook_process_hashtable(client_command, args, timeout, "exec_cb", "")
   return w("WEECHAT_RC_OK")
end

function exec_cb(_, command, status, output, error)
   if status == w("WEECHAT_HOOK_PROCESS_ERROR") or status > 0 then
      weechat.print_date_tags(
         "", 0, "no_highlight,no_log",
         string.format("%s\tUnable to get currently playing song: %s",
            SCRIPT_NAME, error))

      current_song = ""
      weechat.bar_item_update(SCRIPT_NAME)
      return w("WEECHAT_RC_ERROR")
   elseif status == 0 then
      current_song = output:gsub("%s*$", "")
      weechat.bar_item_update(SCRIPT_NAME)
      return w("WEECHAT_RC_OK")
   end
end

function setup_timer()
   if timer_hook then
      weechat.unhook(timer_hook)
   end
   if timer_interval < 1 then
      timer_interval = 10
   end
   timer_hook = weechat.hook_timer(timer_interval * 1000, 0, 0, "timer_cb", "")
end

setup()

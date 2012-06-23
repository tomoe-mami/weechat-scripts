---   mpdbitl
--
--    Script that automatically change bitlbee status message into current MPD
--    track.
--
--    TODO:
--    - better pattern replacement method
--    - better config handling
--    - add command to toggle script (eg: `/mpdbitl off`)

require("socket")

mpdbitl_config =
{
   enable         = true,
   color          = "yellow,red",
   hostname       = "localhost",
   port           = 6600,
   password       = nil,
   timeout        = 1,
   network        = "localhost",
   bitlbot        = "root",
   account_id     = 0,
   color          = "yellow,red",
   format_playing = "",
   format_paused  = "",
   format_stopped = ""
}

mpdbitl_sock               = nil
mpdbitl_song_id            = nil
mpdbitl_error              = {}
mpdbitl_config_file        = nil
mpdbitl_config_file_name   = "mpdbitl"
mpdbitl_status_command     = "/msg %s account %d set status '%s'"

function mpdbitl_config_init()

   mpdbitl_config_file = 
      weechat.config_new(mpdbitl_config_file_name, "mpdbitl_config_reload", "")

   if mpdbitl_config_file == "" then return end

   local general_section =
      weechat.config_new_section(
         mpdbitl_config_file, "general",
         0, 0,
         "", "", "", "", "", "", "", "", "", "")

   if general_section == "" then
      weechat.config_free(mpdbitl_config_file)
      return
   end

   local enable_mpdbitl =
      weechat.config_new_option(
         mpdbitl_config_file, general_section,
         "enable", "boolean",
         "Enable mpdbitl",
         "", 0, 0,
         "on", "on",
         0, "", "", "", "", "", "")

   local color =
      weechat.config_new_option(
         mpdbitl_config_file, general_section,
         "notification_color", "color",
         "Color for error notification",
         "", 0, 0,
         "yellow,red", "yellow,red",
         0, "", "", "", "", "", "")

   local section_mpd =
      weechat.config_new_section(
         mpdbitl_config_file, "mpd",
         0, 0,
         "", "", "", "", "", "", "", "", "", "")

   if section_mpd == "" then
      weechat.config_free(mpdbitl_config_file)
      return
   end

   local mpd_hostname =
      weechat.config_new_option(
         mpdbitl_config_file, section_mpd,
         "hostname", "string",
         "Hostname of MPD server",
         "", 0, 0,
         "localhost", "localhost",
         0, "", "", "", "", "", "")

   local mpd_port =
      weechat.config_new_option(
         mpdbitl_config_file, section_mpd,
         "port", "integer", "Port used by MPD server",
         "", 1, 65535,
         6600, 6600, 0,
         "", "", "", "", "", "")

   local mpd_password =
      weechat.config_new_option(
         mpdbitl_config_file, section_mpd,
         "password", "string",
         "Password used to authenticate to mpd server",
         "", 0, 0,
         "", "", 1,
         "", "", "", "", "", "")

   local mpd_timeout =
      weechat.config_new_option(
         mpdbitl_config_file, section_mpd,
         "timeout", "integer", "Connection timeout (in seconds)",
         "", 1, 65535,
         1, 1, 0,
         "", "", "", "", "", "")

   local section_bitlbee =
      weechat.config_new_section(
         mpdbitl_config_file,
         "bitlbee",
         0, 0, "", "", "", "", "", "", "", "", "", "")

   if section_bitlbee == "" then
      weechat.config_free(mpdbitl_config_file)
      return
   end

   local bitlbee_network =
      weechat.config_new_option(
         mpdbitl_config_file, section_bitlbee,
         "network", "string", "Network id for bitlbee server",
         "", 0, 0,
         "localhost", "localhost", 0,
         "", "", "", "", "", "")

   local bitlbee_account =
      weechat.config_new_option(
         mpdbitl_config_file, section_bitlbee,
         "account", "integer", "Bitlbee account id",
         "", 0, 65535,
         0, 0, 0,
         "", "", "", "", "", "")

   local bitlbee_bot =
      weechat.config_new_option(
         mpdbitl_config_file, section_bitlbee,
         "bitlbot", "string", "Bitlbee bot handle name",
         "", 0, 0,
         "root", "root", 0,
         "", "", "", "", "", "")

   local format_playing =
      weechat.config_new_option(
         mpdbitl_config_file, section_bitlbee,
         "format_playing", "string", "Status format when mpd is playing a song",
         "", 0, 0,
         "mpdbitl: {{artist}} - {{title}}",
         "mpdbitl: {{artist}} - {{title}}",
         0,
         "", "", "", "", "", "")

   local format_paused =
      weechat.config_new_option(
         mpdbitl_config_file, section_bitlbee,
         "format_paused", "string", "Status format when mpd is paused",
         "", 0, 0,
         "mpdbitl (paused): {{artist}} - {{title}}",
         "mpdbitl (paused): {{artist}} - {{title}}",
         0,
         "", "", "", "", "", "")

   local format_stopped =
      weechat.config_new_option(
         mpdbitl_config_file, section_bitlbee,
         "format_stopped", "string", "status format when mpd is stopped",
         "", 0, 0,
         "mpdbitl (not playing)",
         "mpdbitl (not playing)",
         0,
         "", "", "", "", "", "")

   mpdbitl_config.enable         = weechat.config_boolean(enable_mpdbitl)
   mpdbitl_config.color          = weechat.color(weechat.config_color(color))
   mpdbitl_config.hostname       = weechat.config_string(mpd_hostname)
   mpdbitl_config.port           = weechat.config_integer(mpd_port)
   mpdbitl_config.password       = weechat.config_string(mpd_password)
   mpdbitl_config.timeout        = weechat.config_integer(mpd_timeout)
   mpdbitl_config.network        = weechat.config_string(bitlbee_network)
   mpdbitl_config.account_id     = weechat.config_integer(bitlbee_account)
   mpdbitl_config.bitlbot        = weechat.config_string(bitlbee_bot)
   mpdbitl_config.format_playing = weechat.config_string(format_playing)
   mpdbitl_config.format_stopped = weechat.config_string(format_stopped)
   mpdbitl_config.format_paused  = weechat.config_string(format_paused)

   weechat.print("", mpdbitl_config.network)
end

function mpdbitl_config_reload_cb(data, config_file)
   return weechat.config_reload(config_file)
end

function mpdbitl_config_read()
   return weechat.config_read(mpdbitl_config_file)
end

function mpdbitl_config_write()
   return weechat.config_write(mpdbitl_config_file)
end

function mpdbitl_connect()

   mpdbitl_sock = socket.tcp()
   mpdbitl_sock:settimeout(mpdbitl_config.timeout, "t")

   if not sock:connect(mpdbitl_config.hostname, mpdbitl_config.port) then
      weechat.print(
         "",
         string.format(
            "mpdbitl\t%sCould not connect to %s:%d",
            mpdbitl_config.color,
            mpdbitl_config.hostname,
            mpdbitl_config.port)
      )
      return false
   end

   local line = mpdbitl_sock:receive("*l")
   if not line:match("^OK MPD") then
      weechat.print(
         "",
         string.format(
            "mpdbitl\t%sUnknown welcome message: %s",
            mpdbitl_config.color,
            line)
      )
      return false
   else
      if mpdbitl_config.password and #mpdbitl_config.password > 0 then

         local command = "password " .. mpdbitl_escape_arg(mpdbitl_config.password)

         if mpdbitl_send_command(command) then
            local response = mpdbitl_fetch_all_responses()
            if mpdbitl_error.message then
               weechat.print(
                  "",
                  string.format(
                     "mpdbitl\t%sMPD error: %s",
                     mpdbitl_config.color,
                     mpdbitl_error.message)
               )
               return false
            end
         end

      end
      return true
   end
end

function mpdbitl_escape_arg(arg)
   if type(arg) == "number" then
      return arg
   elseif type(arg) == "string" then
      arg = arg:gsub('"', '\\"')
      arg = arg:gsub('\\', '\\\\')
      return '"' .. arg .. '"'
   else
      return ""
   end
end

function mpdbitl_disconnect()
   send_mpd_command("close")
   mpdbitl_sock:close()
end

function mpdbitl_send_command(line)
   line = line .. "\n"
   local sent = mpdbitl_sock:send(line)
   if sent ~= #line then
      return false
   else
      return true
   end
end

function mpdbitl_receive_single_response()
   local complete, key, value, _
   local error = {}

   local line = mpdbitl_sock:receive("*l")

   if line then
      if line:match("^OK$") then
         complete = true
      elseif line:match("^ACK") then
         error.code,
         error.index,
         error.command,
         error.message =
            line:find("^ACK %[(%d+)@(%d+)%] {([^}]+)\} (.+)")

         complete = true
      else
         _, _, key, value = line:find("^([^:]+):%s(.+)")
         if key then
            key = string.gsub(key:lower(), "-", "_")
         end
      end
   end

   return key, value, complete, error
end

function mpdbitl_fetch_all_responses()
   local result = {}
   local complete, key, value
   repeat
      key, value, complete, mpdbitl_error = mpdbitl_receive_single_response()
      if key then result[key] = value end
   until complete

   if mpdbitl_error.message then
      weechat.print(
         "",
         string.format(
            "mpdbitl\t%sMPD Error %s (%s @ %u): %s",
            mpdbitl_config.color,
            mpdbitl_error.code,
            mpdbitl_error.command,
            mpdbitl_error.index,
            mpdbitl_error.message)
      )
   end

   return result
end

function mpdbitl_get_server_status()
   if mpdbitl_send_command("status") then
      return mpdbitl_fetch_all_responses()
   else
      return false
   end
end

function mpdbitl_get_current_song()
   if mpdbitl_send_command("currentsong") then
      return mpdbitl_fetch_all_responses()
   else
      return false
   end
end

function mpdbitl_format_status_text(format, data)
   local result = format

   if not result or not data or #result < 1 or type(data) ~= "table" then
      return ""
   end

   for key,value in pairs(data) do
      local token = "{{" .. key .. "}}"
      result = result:gsub(token, value)
   end

   result = result:gsub("'", "\\'")
   return result
end

function mpdbitl_change_bitlbee_status(data, remaining_calls)

   if not mpdbitl_config.enable then return weechat.WEECHAT_RC_OK end

   local win_buffer  = weechat.info_get("irc_buffer", mpdbitl_config.network)
   weechat.print("", mpdbitl_config.network)

   if win_buffer == "" then return weechat.WEECHAT_RC_OK end

   if mpdbitl_connect() then

      local server_status  = mpdbitl_get_server_status()
      local irc_command    = nil

      if server_status.state == "stop" and mpdbitl_song_id then

         mpdbitl_song_id = nil
         irc_command = string.format(
                        mpdbitl_status_command,
                        mpdbitl_config.bitlbot,
                        mpdbitl_config.account_id,
                        mpdbitl_config.format_stopped)

      elseif server_status.songid ~= mpdbitl_song_id then

         mpdbitl_song_id = server_status.songid
         local format = ""

         if server_status.state == "play" then
            format = mpdbitl_config.format_playing
         else
            format = mpdbitl_config.format_paused
         end

         local song        = mpdbitl_get_current_song()
         local status_text = mpdbitl_format_status_text(format, song)

         irc_command = string.format(
                        mpdbitl_status_command,
                        mpdbitl_config.bitlbot,
                        mpdbitl_config.account_id,
                        status_text)

      end

      mpdbitl_disconnect()

      if irc_command and #irc_command > 0 then
         weechat.print(win_buffer, irc_command)
      end

      return weechat.WEECHAT_RC_OK
   else
      return weechat.WEECHAT_RC_ERROR
   end
end

function mpdbitl_unload()
   mpdbitl_config_write()
   return weechat.WEECHAT_RC_OK
end

function mpdbitl_initialize()
   weechat.register(
      "mpdbitl",
      "rumia/gergaji <https://github.com/rumia>",
      "0.1",
      "WTFPL",
      "Automatically change bitlbee status message into current MPD track",
      "mpdbitl_unload",
      ""
   )

   mpdbitl_config_init()
   mpdbitl_config_read()

   weechat.hook_command(
      "mpdbitl",
      "Change bitlbee status message into current MPD track",
      "", "", "",
      "mpdbitl_change_bitlbee_status",
      ""
   )

   -- weechat.hook_timer(60 * 1000, 60, 0, "mpdbitl_change_bitlbee_status", "")
end

mpdbitl_initialize()

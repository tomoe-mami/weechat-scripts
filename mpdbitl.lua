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
   hostname       = "localhost",
   port           = 6600,
   password       = nil,
   timeout        = 1,
   network        = "localhost",
   channel        = "&bitlbee",
   bitlbot        = "root",
   account_id     = 0,
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

   if mpdbitl_config_file == "" then
      return
   end

   local general_section =
      weechat.config_new_section(
         mpdbitl_config_file, "general",
         0, 0,
         "", "", "", "", "", "", "", "", "", "")

   if general_section == "" then
      weechat.config_free(mpdbitl_config_file)
      return
   end

   mpdbitl_config.enable =
      weechat.config_new_option(
         mpdbitl_config_file, general_section,
         "enable", "boolean",
         "Enable mpdbitl",
         "", 0, 0,
         "on", "on",
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

   mpdbitl_config.hostname =
      weechat.config_new_option(
         mpdbitl_config_file, section_mpd,
         "hostname", "string",
         "Hostname of MPD server",
         "", 0, 0,
         "localhost", "localhost",
         0, "", "", "", "", "", "")

   mpdbitl_config.port =
      weechat.config_new_option(
         mpdbitl_config_file, section_mpd,
         "port", "integer", "Port used by MPD server",
         "", 1, 65535,
         6600, 6600, 0,
         "", "", "", "", "", "")

   mpdbitl_config.password =
      weechat.config_new_option(
         mpdbitl_config_file, section_mpd,
         "password", "string",
         "Password used to authenticate to MPD server",
         "", 0, 0,
         "", "", 1,
         "", "", "", "", "", "")

   mpdbitl_config.timeout =
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

   mpdbitl_config.network =
      weechat.config_new_option(
         mpdbitl_config_file, section_bitlbee,
         "network", "string", "Network id for bitlbee server",
         "", 0, 0,
         "localhost", "localhost", 0,
         "", "", "", "", "", "")

   mpdbitl_config.channel =
      weechat.config_new_option(
         mpdbitl_config_file, section_bitlbee,
         "channel", "string", "Bitlbee main channel",
         "", 0, 0,
         "&bitlbee", "&bitlbee", 0,
         "", "", "", "", "", "")

   mpdbitl_config.account_id =
      weechat.config_new_option(
         mpdbitl_config_file, section_bitlbee,
         "account", "integer", "Bitlbee account id",
         "", 0, 65535,
         0, 0, 0,
         "", "", "", "", "", "")

   mpdbitl_config.bitlbot =
      weechat.config_new_option(
         mpdbitl_config_file, section_bitlbee,
         "bitlbot", "string", "Bitlbee bot handle name",
         "", 0, 0,
         "root", "root", 0,
         "", "", "", "", "", "")

   mpdbitl_config.format_playing =
      weechat.config_new_option(
         mpdbitl_config_file, section_bitlbee,
         "format_playing", "string", "Status format when MPD is playing a song",
         "", 0, 0,
         "mpdbitl: {{artist}} - {{title}}",
         "mpdbitl: {{artist}} - {{title}}",
         0,
         "", "", "", "", "", "")

   mpdbitl_config.format_paused =
      weechat.config_new_option(
         mpdbitl_config_file, section_bitlbee,
         "format_paused", "string", "Status format when MPD is paused",
         "", 0, 0,
         "mpdbitl (paused): {{artist}} - {{title}}",
         "mpdbitl (paused): {{artist}} - {{title}}",
         0,
         "", "", "", "", "", "")

   mpdbitl_config.format_stopped =
      weechat.config_new_option(
         mpdbitl_config_file, section_bitlbee,
         "format_stopped", "string", "Status format when MPD is stopped",
         "", 0, 0,
         "mpdbitl (not playing)",
         "mpdbitl (not playing)",
         0,
         "", "", "", "", "", "")
end

function mpdbitl_config_reload(data, config_file)
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
   mpdbitl_sock:settimeout(weechat.config_integer(mpdbitl_config.timeout), "t")

   local hostname = weechat.config_string(mpdbitl_config.hostname)
   local port     = weechat.config_integer(mpdbitl_config.port)

   if not mpdbitl_sock:connect(hostname, port) then
      weechat.print(
         "",
         string.format("mpdbitl\tCould not connect to %s:%d", hostname, port)
      )
      return false
   end

   local line = mpdbitl_sock:receive("*l")
   if not line:match("^OK MPD") then
      weechat.print(
         "",
         string.format("mpdbitl\tUnknown welcome message: %s", line)
      )
      return false
   else
      local password = weechat.config_string(mpdbitl_config.password)
      if password and #password > 0 then

         local command = "password " .. mpdbitl_escape_arg(password)

         if mpdbitl_send_command(command) then
            local response = mpdbitl_fetch_all_responses()
            if mpdbitl_error.message then
               weechat.print(
                  "",
                  string.format("mpdbitl\tMPD error: %s", mpdbitl_error.message)
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
   mpdbitl_send_command("close")
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
      if key then
         result[key] = value
      end
   until complete

   if mpdbitl_error.message then
      weechat.print(
         "",
         string.format(
            "mpdbitl\tMPD Error %s (%s @ %u): %s",
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
      local song = mpdbitl_fetch_all_responses()
      if song.time then
         local duration = tonumber(song.time)
         local hours    = math.floor(duration / 3600) % 24
         local minutes  = math.floor(duration / 60) % 60
         local seconds  = duration % 60

         song.time = string.format("%02d:%02d", minutes, seconds)
         if hours > 0 then
            song.time = string.format("%02d:%s", hours, song.time)
         end
      end

      return song
   else
      return false
   end
end

function mpdbitl_format_status_text(text, replacement)
   if not text or not replacement or #text < 1 or type(replacement) ~= "table" then
      return ""
   end

   text = text:gsub("{{([^}]+)}}", replacement)
   text = text:gsub("'", "\\'")

   return text
end

function mpdbitl_change_bitlbee_status(data, remaining_calls)

   local enabled = weechat.config_boolean(mpdbitl_config.enable)
   if not enabled then
      return weechat.WEECHAT_RC_OK
   end

   local network  = weechat.config_string(mpdbitl_config.network)
   local channel  = weechat.config_string(mpdbitl_config.channel)
   local buf_id   = network .. "." .. channel
   local buffer   = weechat.buffer_search("irc", buf_id)

   if buffer == "" then
      weechat.print(
         "",
         string.format("mpdbitl\tNo buffer for %s", buf_id)
      )

      return weechat.WEECHAT_RC_OK
   end

   local bitlbot = weechat.config_string(mpdbitl_config.bitlbot)
   if weechat.info_get("irc_is_nick", bitlbot) ~= "1" then
      weechat.print(
         "",
         string.format("mpdbitl\tInvalid bitlbot handler: %s", bitlbot)
      )

      return weechat.WEECHAT_RC_OK
   end

   if mpdbitl_connect() then

      local server_status  = mpdbitl_get_server_status()
      local irc_command    = nil
      local account_id     = weechat.config_integer(mpdbitl_config.account_id)

      if server_status.state == "stop" and mpdbitl_song_id then

         mpdbitl_song_id = nil
         irc_command = string.format(
                        mpdbitl_status_command,
                        bitlbot,
                        account_id,
                        weechat.config_string(mpdbitl_config.format_stopped))

      elseif server_status.songid ~= mpdbitl_song_id then

         mpdbitl_song_id = server_status.songid
         local format = ""

         if server_status.state == "play" then
            format = mpdbitl_config.format_playing
         else
            format = mpdbitl_config.format_paused
         end

         local status_text = mpdbitl_format_status_text(
                              weechat.config_string(format),
                              mpdbitl_get_current_song())

         irc_command = string.format(
                        mpdbitl_status_command,
                        bitlbot,
                        account_id,
                        status_text)

      end

      mpdbitl_disconnect()

      if irc_command and #irc_command > 0 then
         weechat.command(buffer, irc_command)
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

   weechat.hook_timer(60 * 1000, 60, 0, "mpdbitl_change_bitlbee_status", "")
end

mpdbitl_initialize()

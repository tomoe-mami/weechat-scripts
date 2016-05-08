require "socket"

w, script_name = weechat, "mpd_events"
g = {
   config = {
      hostname = "localhost",
      port = 6600
   },
   sock = "",
   last_info = {},
   idling = false
}

function string:eval(vars)
   return w.string_eval_expression(self, {}, vars or {}, {})
end

function print(format, vars)
   w.print("", script_name.."\t"..format:eval(vars))
end

function seconds_to_duration(s)
   if not s then
      return
   end
   local secs, msecs = s:match("^([^.]+)(%.?.*)")
   secs = tonumber(secs) or 0
   local hh = math.floor(secs / 3600)
   local mm = math.floor(secs / 60) % 60
   local ss = secs % 60
   local duration = string.format("%02d:%02d%s", mm, ss, msecs)
   if hh > 0 then
      duration = string.format("%02d:%s", hh, duration)
   end
   return duration
end

function mpd_connect()
   local sock, conf = socket.tcp(), g.config
   sock:settimeout(conf.timeout, "t")
   if not sock:connect(conf.hostname, conf.port) then
      return false, string.format("Could not connect to %s:%d", conf.hostname, conf.port)
   end
   local line = sock:receive("*l")
   if not line then
      return false, "No response from MPD server"
   end
   local version = line:match("^OK MPD (.+)")
   if not version then
      return false, "Unknown welcome message: "..line
   end
   g.sock, g.version = sock, version
   if conf.password and conf.password ~= "" then
      if mpd_login(conf.password) then
      end
   end
   return true
end

function mpd_escape_arg(s)
   local t = type(s)
   if t == "number" then
      return s
   elseif t == "boolean" then
      return s and 1 or 0
   elseif t == "string" then
   else
      return '""'
   end
end

function mpd_command(command, ...)
   local parts = { command }
   for _, v in ipairs({...}) do
      table.insert(parts, mpd_escape_arg(v))
   end
   local line = table.concat(parts, " ").."\n"
   local sent = g.sock:send(line)
   return sent == #line
end

function mpd_read_response()
   local line = g.sock:receive("*l")
   local done, e, k, v = true, {}
   if not line then
      e.code = -1
      e.message = "No response"
   elseif line:sub(1, 4) == "ACK " then
      e.code, e.index, e.command, e.message =
         line:match("^ACK %[(%d+)@(%d+)%] {([^}]*)} (.*)")
   elseif line ~= "OK" then
      done = false
      k, v = line:match("^([^:]+): (.*)")
      if k then
         k = k:lower():gsub("-", "_")
      end
   end
   return done, e, k, v
end

function mpd_result_table(options)
   options = options or {}
   if options.snake_case == nil then
      options.snake_case = true
   end
   local t, done, e, k, v = {}
   while not done do
      done, e, k, v = mpd_read_response()
      if k and v then
         if options.flip then
            k, v = v, k
         end
         if options.list then
            table.insert(t, v)
         else
            if options.snake_case then
               k = k:lower():gsub("-", "_")
            end
            t[k] = v
         end
      end
   end
   return t, e
end

function mpd_login(password)
   mpd_command("password", password)
   local _, e = mpd_read_response()
   if e.code then
      print("Error ${code}: ${message}", e)
      return false
   end
   return true
end

function mpd_idle()
   mpd_command("idle")
   local result, err = mpd_result_table({ list = true })
   if err.code then
      return err.code..":"..err.message
   else
      return "ok:"..table.concat(result, ",")
   end
end

function mpd_get_info()
   mpd_command("status")
   local t1 = mpd_result_table()
   t1.playlistlength = tonumber(t1.playlistlength) or 0
   t1.elapsed = seconds_to_duration(t1.elapsed)

   mpd_command("currentsong")
   local t2 = mpd_result_table()
   t2.time = seconds_to_duration(t2.time)

   mpd_command("stats")
   local t3 = mpd_result_table()

   return t1, t2, t3
end

function collect_hsignal_data(subsystems)
   subsystems = ","..(subsystems or "")..","

   local send_signal = true
   local status, song, stat = mpd_get_info()
   local events, last_info = {}, g.last_info
   if subsystems:match(",database,") then
      table.insert(events, status.updating_db and "db_updating" or "db_updated")
   end
   if subsystems:match(",playlist,") then
      local ev = "playlist_song_moved"
      if status.playlistlength > last_info["status.playlistlength"] then
         ev = "playlist_song_added"
      elseif status.playlistlength < last_info["status.playlistlength"] then
         ev = "playlist_song_removed"
      end
      table.insert(events, ev)
   end
   if subsystems:match(",options,") then
      for _, k in ipairs({"random", "repeat", "single", "consume"}) do
         if status[k] ~= last_info["status."..k] then
            table.insert(events, k.."_mode_"..(status[k] == "1" and "enabled" or "disabled"))
         end
      end
   end

   if song.id and song.id ~= last_info["song.id"] then
      table.insert(events, "song_changed")
   end
   if status.state ~= last_info["status.state"] then
      table.insert(events, "state_"..status.state)
   end
   -- there's a weird behavior that when you send `idle`, wait for a song to
   -- finish, received `changed: player; OK` response, and then send `idle`
   -- again, mpd will send another `changed: player; OK` immediately.
   -- the only thing different between them is the value of status.elapsed.
   -- this doesn't happen if you change song manually.
   --
   -- this is annoying. we'll just ignore `player` changes other than
   -- playback state and current song.
   if #events == 0 and subsystems == ",player," then
      send_signal = false
   end

   local info = {}
   for p, t in pairs({ status = status, song = song, stat = stat}) do
      for k, v in pairs(t) do
         info[p.."."..k] = v
      end
   end
   info.events = ","..table.concat(events, ",")..","
   info.idle_subsystems = subsystems
   g.last_info = info

   return info, send_signal
end

function send_events(result)
   local ret, sub = result:match("^([^:]+):(.*)")
   if ret ~= "ok" then
      print("Error ${code}: ${message}", { code = ret, message = sub })
   else
      local info, send_signal = collect_hsignal_data(sub)
      if send_signal then
         w.hook_hsignal_send(script_name, info)
      end
   end
   start_idle_process()
end

function idle_process_cb(_, cmd, ret, out, err)
   if ret > 0 or ret == w.WEECHAT_HOOK_PROCESS_ERROR then
      if err and err ~= "" then
         print("${color:chat_delimiters}[${color:reset}error"..
               "${color:chat_delimiters}]${color:reset} ${msg}", { msg = err })
      end
   elseif ret == 0 or ret == w.WEECHAT_HOOK_PROCESS_RUNNING then
      g.process_output = g.process_output..out
      if ret == 0 then
         g.idling = false
         send_events(g.process_output)
      end
   end
   return w.WEECHAT_RC_OK
end

function start_idle_process()
   if not g.idling then
      g.idling = true
      g.process_output = ""
      w.hook_process("func:mpd_idle", 0, "idle_process_cb", "")
   end
end

function unload_cb()
   if g.idling then
      mpd_command("noidle")
   end
   mpd_command("close")
   g.sock:close()
end

function main()
   local reg_ok = w.register(
      script_name, "singalaut", "0.1", "WTFPL",
      "Sends hsignal on MPD events", "unload_cb", "")

   if reg_ok then
      local wee_ver = tonumber(w.info_get("version_number", "") or 0)
      if wee_ver < 0x01050000 then
         w.print("", w.prefix("error").."This script requires Weechat >= 1.5")
      else
         mpd_connect()
         collect_hsignal_data()
         start_idle_process()
      end
   end
end

main()

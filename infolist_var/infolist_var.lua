local w = weechat
local g = {
   script = {
      name = "infolist_var",
      author = "tomoe-mami/singalaut <https://github.com/tomoe-mami",
      version = "0.1",
      license = "WTFPL",
      description = ""
   },
   var_types = {
      i = "integer",
      p = "pointer",
      s = "string",
      t = "time"
   }
}

function get_infolist_var(name, ptr, param, index, variable)
   local infolist = w.infolist_get(name, ptr, param)
   if not infolist or infolist == "" then
      return ""
   end
   local step, func = 1, w.infolist_next
   if index < 0 then
      step = -1
      func = w.infolist_prev
   end
   for i = 0, index, step do
      func(infolist)
   end

   local fields = w.infolist_fields(infolist)
   local value = ""
   if not variable or variable == "" then
      value = fields:gsub(",", "\n")
   else
      fields = "," .. fields .. ","
      local pos = fields:find(":" .. variable .. ",", 3, true)
      if pos and pos >= 3 then
         local x = pos - 1
         local t = fields:sub(x, x)
         if not g.var_types[t] then
            t = "s"
         end
         local func_name = "infolist_" .. g.var_types[t]
         value = w[func_name](infolist, variable)
      end
   end
   w.infolist_free(infolist)
   return value
end

function info_cb(_, name, arg_string)
   local name, ptr, param, index, variable = arg_string:match("^([^;]+);([^;]-);([^;]-);([%-%+]?%d-);(.*)$")
   if not name or name == "" then
      return ""
   end
   index = math.floor(tonumber(index) or 0)
   return get_infolist_var(name, ptr, param, index, variable)
end

function buf_info_cb(_, name, arg_string)
   local ptr, variable = arg_string:match("^([^;]-);(.*)$")
   return get_infolist_var("buffer", ptr, "", 0, variable)
end

function main()
   assert(
      w.register(
         g.script.name,
         g.script.author,
         g.script.version,
         g.script.license,
         g.script.description,
         "", ""),
      "Unable to register script. Perhaps it has been loaded before?")

   w.hook_info(
      "list",
      "Gets variable from an infolist",
      "Format of argument is: <infolist-name>;<pointer>;<param>;<index>;<var-name>",
      "info_cb",
      "")

   w.hook_info(
      "buf",
      "Shorthand for info:list,buffer;<ptr>;;0;<var-name>",
      "",
      "buf_info_cb",
      "")
end

main()

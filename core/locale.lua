-- Copyright 2007-2017 Mitchell mitchell.att.foicica.com. See LICENSE.

local M = {}

--[[ This comment is for LuaDoc.
---
-- Map of all messages used by Textadept to their localized form.
-- If the table does not contain the localized version of a given message, it
-- returns a string that starts with "No Localization:" via a metamethod.
module('_L')]]

local f = io.open(_USERHOME..'/locale.conf', 'rb')
if not f then
  local lang = (os.getenv('LANG') or ''):match('^[^_.@]+') -- TODO: LC_MESSAGES?
  if lang then f = io.open(_HOME..'/core/locales/locale.'..lang..'.conf') end
  if not f then 
  	lang = (os.getenv('LANG') or ''):match('^[^.@]+')
  	f = io.open(_HOME..'/core/locales/locale.'..lang..'.conf')
  end
end
if not f then f = io.open(_HOME..'/core/locale.conf', 'rb') end
assert(f, '"core/locale.conf" not found.')
for line in f:lines() do
  -- Any line that starts with a non-word character except '[' is considered a
  -- comment.
  if not line:find('^%s*[^%w_%[]') then
    local id, str = line:match('^(.-)%s*=%s*(.+)$')
    if id and str then M[id] = not CURSES and str or str:gsub('_', '') end
  end
end
f:close()

return setmetatable(M,
                    {__index = function(_, k) return 'No Localization:'..k end})

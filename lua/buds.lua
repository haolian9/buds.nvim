---design
---* trigger intentionaly
---* no nvim_buf_attach, which leads to an unstable fragile impl
---* not support multi-line list item
---

local ctx = require("infra.ctx")
local jelly = require("infra.jellyfish")("buds", "info")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local unsafe = require("infra.unsafe")
local wincursor = require("infra.wincursor")

local try_unordered, try_ordered, try_ftspec
do
  ---@alias buds.Try fun(prevline: string): nil|string

  ---for '* ', '- '
  ---@type buds.Try
  function try_unordered(prevline)
    local prefix = string.match(prevline, "^%s*[*-] ")
    if prefix == nil then return end
    jelly.debug("new unordered: %s", prefix)
    return prefix
  end

  ---for '1. '
  ---@type buds.Try
  function try_ordered(prevline)
    local prefix, no = string.match(prevline, "^(%s*(%d+)%. )")
    if not (prefix and no) then return end
    local next_no = tostring(assert(tonumber(no)) + 1)
    prefix = string.gsub(prefix, no, next_no)
    jelly.debug("new ordered: %s", prefix)
    return prefix
  end

  do
    try_ftspec = {}
    ---@type buds.Try
    function try_ftspec.lua(prevline)
      do --'---* abc', '-- * abc'
        local prefix = string.match(prevline, "^%s*--[ -]%* ")
        if prefix ~= nil then return prefix end
      end
    end
  end
end

---@param str string
---@return boolean
local function is_blank(str)
  if str == "" then return true end
  return string.match(str, "^%s+$") ~= nil
end

---@return true?
return function()
  local winid = ni.get_current_win()
  local bufnr = ni.win_get_buf(winid)
  local cursor = wincursor.position(winid)

  --only takes first 64 chars from cursor line, which should just be enough
  local curline = ni.buf_get_text(bufnr, cursor.lnum, 0, cursor.lnum, 64, {})[1]
  if is_blank(curline) then return jelly.debug("aborted: blank cursor line") end

  --NB: order matters
  local tries = { try_unordered, try_ordered, try_ftspec[prefer.bo(bufnr, "filetype")] }

  local newline
  for idx, try in ipairs(tries) do
    newline = try(curline)
    if newline ~= nil then
      jelly.debug("try#%d wins", idx)
      break
    end
  end
  if newline == nil then return jelly.debug("aborted: all tries failed") end

  ctx.undoblock(bufnr, function()
    --for '- a<cr>b', just replace the text before cursor
    ni.buf_set_text(bufnr, cursor.lnum, cursor.col, cursor.lnum, cursor.col, { "", newline })
  end)
  wincursor.go(winid, cursor.lnum + 1, assert(unsafe.linelen(bufnr, cursor.lnum + 1)))

  return true
end

---design
---* keep the logic minimal
---* only support i_cr
---
---known facts
---* :bd and :bw will remove all the attached callback of nvim_buf_attach of the buffer
---* nvim generate bufnr in an auto_increment way, so old bufnr will not be used once it's been wiped out
---
---known wontfix issues
---* not work with: p, o, O, gw, gq
---* not support multi-line list item
---* `<cr><cr>` will remove the trailing space from the previous line,
---  which is caused by &autoindent, actually i'd treat it as a feature
---* `<cr><cr>` will not remove the previously inserted `*` line
---
---todo
---* remap i_cr could lead to a much simpler impl

local M = {}

local ctx = require("infra.ctx")
local jelly = require("infra.jellyfish")("buds", "info")
local prefer = require("infra.prefer")
local wincursor = require("infra.wincursor")

local api = vim.api

local bufwatcher = {}
do
  ---@private
  ---@type {[integer]: true} @{bufnr}
  bufwatcher.running = {}
  ---@private
  ---@type {[integer]: true} @{bufnr}
  bufwatcher.cancelled = {}

  function bufwatcher:is_attached(bufnr) return self.running[bufnr] == true or self.cancelled[bufnr] == true end

  function bufwatcher:mark_attached(bufnr)
    assert(self.cancelled[bufnr] == nil, "attach to a being cancelled buf")
    self.running[bufnr] = true
  end

  function bufwatcher:is_cancelled(bufnr) return self.running[bufnr] == true and self.cancelled[bufnr] == true end

  function bufwatcher:mark_cancelled(bufnr)
    assert(self.running[bufnr] == true, "cancel an unattached buf")
    self.cancelled[bufnr] = true
  end

  function bufwatcher:mark_detached(bufnr)
    assert(self.running[bufnr] == true)
    assert(self.cancelled[bufnr] == true)
    self.running[bufnr] = nil
    self.cancelled[bufnr] = nil
  end
end

local try_unordered, try_ordered, try_ftspec
do
  ---@alias Try fun(prevline: string): nil|string

  ---for '* ', '- '
  ---@type Try
  function try_unordered(prevline)
    local prefix = string.match(prevline, "^%s*[*-] ")
    if prefix == nil then return end
    jelly.debug("new unordered: %s", prefix)
    return prefix
  end

  ---for '1. '
  ---@type Try
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
    ---@type Try
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

---@param bufnr integer
function M.attach(bufnr)
  assert(bufnr ~= 0)

  if bufwatcher:is_attached(bufnr) then return end
  bufwatcher:mark_attached(bufnr)

  --NB: order matters
  local tries = { try_unordered, try_ordered, try_ftspec[prefer.bo(bufnr, "filetype")] }

  api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, _, tick, first_line, old_last, new_last)
      --[[ sample first_line, old_last, new_last
        yy2p: 4, 4, 6
        d2k:  1, 4, 1
        dk:   3, 5, 3
        <cr>: 0, 1, 2
        o:    2, 2, 3
        O:    2, 2, 3
        yyp:  3, 3, 4
        abcd: 2, 3, 3
        gw:   2, 3, 4; 3, 4, 5
      --]]

      if bufwatcher:is_cancelled(bufnr) then
        bufwatcher:mark_detached(bufnr)
        return true
      end

      --the data seems to be produced by i_cr
      if not (old_last - first_line == 1 and new_last - old_last == 1) then return end
      assert(new_last ~= 1)

      --only takes first 64 chars from prevline, which should just be enough
      local prevline = api.nvim_buf_get_text(bufnr, first_line, 0, first_line, 64, {})[1]
      if is_blank(prevline) then return jelly.debug("cancelled: blank prevline") end
      --todo: check if the current line has been modified by other plugins already

      local newline
      for idx, try in ipairs(tries) do
        newline = try(prevline)
        if newline ~= nil then
          jelly.debug("try#%d wins", idx)
          break
        end
      end
      if newline == nil then return jelly.debug("cancelled: all tries failed") end

      vim.schedule(function()
        --could be gw/gq
        if api.nvim_buf_get_changedtick(bufnr) ~= tick then return jelly.warn("cancelled: buf#%d has changed", bufnr) end

        local winid = api.nvim_get_current_win()
        local cursor = wincursor.position(winid)
        --could be gw/gq
        if new_last ~= cursor.lnum + 1 then return jelly.warn("cancelled: cursor has moved") end

        ctx.undoblock(bufnr, function()
          --for '-- a<cr>b', just replace the text before cursor
          api.nvim_buf_set_text(bufnr, cursor.lnum, 0, cursor.lnum, cursor.col, { newline })
        end)

        wincursor.go(winid, cursor.lnum, #newline)
      end)
    end,
  })
end

function M.detach(bufnr)
  assert(bufnr ~= 0)
  if api.nvim_buf_is_valid(bufnr) then
    bufwatcher:mark_cancelled(bufnr)
  else
    bufwatcher:mark_detached(bufnr)
  end
end

return M

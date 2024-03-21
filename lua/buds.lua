---design
---* keep the logic minimal
---* only supports i_cr
---
---known wontfix issues
---* not work on: p, o, O
---* not support multi-line list item
---* `<cr><cr>` will remove the trailing space from the previous line,
---  which is caused by &autoindent, actually i'd treat it as a feature
---* `<cr><cr>` will not remove the previously inserted `*` line

local M = {}

local ctx = require("infra.ctx")
local jelly = require("infra.jellyfish")("buds", "info")
local prefer = require("infra.prefer")

local api = vim.api

local bufwatcher = {}
do
  ---@private
  ---@type {[integer]: true} @integer
  bufwatcher.attached_bufs = {}

  function bufwatcher:is_attached(bufnr) return self.attached_bufs[bufnr] == true end
  function bufwatcher:mark_attached(bufnr) self.attached_bufs[bufnr] = true end
  function bufwatcher:cancelled(bufnr) return self.attached_bufs[bufnr] == nil end
  function bufwatcher:mark_cancelled(bufnr) self.attached_bufs[bufnr] = nil end
end

local filetype_spec = {}
do
  ---@alias FiletypeSpec fun(prevline: string): nil|string

  ---@type FiletypeSpec
  function filetype_spec.lua(prevline)
    do --'---* abc', '-- * abc'
      local prefix = string.match(prevline, "^%s*--[ -]%* ")
      if prefix ~= nil then return prefix end
    end
  end
end

---@param str string
---@return boolean
local function is_blank(str)
  if #str == 0 then return true end
  return string.match(str, "^%s+$") ~= nil
end

---@param bufnr integer
function M.attach(bufnr)
  assert(bufnr ~= 0)

  --todo: there could be a race condition between mark_attached and cancel
  if bufwatcher:is_attached(bufnr) then return end
  bufwatcher:mark_attached(bufnr)

  local ftspec = filetype_spec[prefer.bo(bufnr, "filetype")]

  api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, _, _, first_line, old_last, new_last)
      --[[ sample first_line, old_last, new_line
        yy2p: 4, 4, 6
        d2k:  1, 4, 1
        dk:   3, 5, 3
        <cr>: 0, 1, 2
        o:    2, 2, 3
        O:    2, 2, 3
        yyp:  3, 3, 4
        abcd: 2, 3, 3
      --]]

      if bufwatcher:cancelled(bufnr) then return true end

      --the data seems to be produced by i_cr
      if not (old_last - first_line == 1 and new_last - old_last == 1) then return end
      assert(new_last ~= 1)

      local prevline
      do
        local lines = api.nvim_buf_get_lines(bufnr, first_line, new_last, false)
        if #lines ~= 2 then return jelly.debug("#lines!=2; %s", lines) end
        local l0, l1 = unpack(lines)
        if is_blank(l0) then return jelly.debug("l0 is blank: '%s'", l0) end
        if not is_blank(l1) then return jelly.warn("l1 isnt blank: '%s'", l1) end
        assert(l0 ~= l1)

        prevline = l0
      end

      local newline

      do -- '* ', '- '
        local prefix = string.match(prevline, "^%s*[*-] ")
        if prefix then
          jelly.debug("new unordered: %s", prefix)
          newline = prefix
        end
      end

      do -- '1. '
        local prefix, no = string.match(prevline, "^(%s*(%d+)%. )")
        if prefix and no then
          local next_no = tostring(assert(tonumber(no)) + 1)
          newline = string.gsub(prefix, no, next_no)
          jelly.debug("new ordered: %s", prefix)
        end
      end

      if ftspec then
        jelly.debug("ftspec is honored")
        newline = ftspec(prevline)
      end

      if newline == nil then return jelly.debug("nothing to do: %s", prevline) end

      vim.schedule(function()
        ctx.undoblock(bufnr, function() api.nvim_buf_set_lines(bufnr, new_last - 1, new_last, false, { newline }) end)
        api.nvim_win_set_cursor(0, { new_last, #newline })
      end)
    end,
  })
end

function M.detach(bufnr)
  assert(bufnr ~= 0)
  bufwatcher.mark_cancelled(bufnr)
end

return M

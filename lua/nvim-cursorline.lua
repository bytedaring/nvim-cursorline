local M = {
  exclude = {"qf", "fugitive", "nerdtree", "gundo", "diff", "fzf", "floaterm"}
}

local DISABLED = 0
local CURSOR = 1
local WINDOW = 2
local status = CURSOR
local timer = vim.loop.new_timer()

local w = vim.w
local o = vim.o
local g = vim.g
local fn = vim.fn
local api = vim.api

local cursorline_timeout = g.cursorline_timeout and g.cursorline_timeout or 1000

o.cursorline = true

local function return_highlight_term(group, term)
  local output = api.nvim_exec("highlight " .. group, true)
  local hi = fn.matchstr(output, term .. [[=\zs\S*]])
  if hi == nil or hi == "" then
    return "None"
  else
    return hi
  end
end

local normal_bg = return_highlight_term("Normal", "guibg")
local cursorline_bg = return_highlight_term("CursorLine", "guibg")

function M.is_enabled()
  local option = M.get_option()
  for _, parser in pairs(M.exclude) do
    vim.notify("------:xw " + option + "  ---  " + parser)
    if option == parser then
      return false
    end
  end
  return true
end

function M.get_option(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  return api.nvim_buf_get_option(bufnr, "ft")
end

function M.highlight_cursorword()
  if M.is_enabled == false then
    return
  end
  if g.cursorword_highlight ~= false then
    vim.cmd("highlight CursorWord term=underline cterm=underline gui=underline")
  end
end

function M.matchadd()
  if fn.hlexists("CursorWord") == 0 then
    return
  end
  local column = api.nvim_win_get_cursor(0)[2]
  local line = api.nvim_get_current_line()
  local cursorword = fn.matchstr(line:sub(1, column + 1), [[\k*$]])
    .. fn.matchstr(line:sub(column + 1), [[^\k*]]):sub(2)

  if cursorword == w.cursorword then
    return
  end
  w.cursorword = cursorword
  if w.cursorword_match == 1 then
    vim.call("matchdelete", w.cursorword_id)
  end
  w.cursorword_match = 0
  if cursorword == "" or #cursorword > 100 or #cursorword < 3 or string.find(cursorword, "[\192-\255]+") ~= nil then
    return
  end
  local pattern = [[\<]] .. cursorword .. [[\>]]
  w.cursorword_id = fn.matchadd("CursorWord", pattern, -1)
  w.cursorword_match = 1
end

function M.cursor_moved()
  M.matchadd()
  if status == WINDOW then
    status = CURSOR
    return
  end
  M.timer_start()
  if status == CURSOR and cursorline_timeout ~= 0 then
    -- disable cursorline
    vim.cmd("highlight! CursorLine guibg=" .. normal_bg)
    vim.cmd("highlight! CursorLineNr guibg=" .. normal_bg)
    status = DISABLED
  end
end

function M.win_enter()
  o.cursorline = true
  status = WINDOW
end

function M.win_leave()
  o.cursorline = false
  status = WINDOW
end

function M.timer_start()
  timer:start(
    cursorline_timeout,
    0,
    vim.schedule_wrap(function()
      -- enable cursorline
      vim.cmd("highlight! CursorLine guibg=" .. cursorline_bg)
      vim.cmd("highlight! CursorLineNr guibg=" .. cursorline_bg)
      status = CURSOR
    end)
  )
end

return M

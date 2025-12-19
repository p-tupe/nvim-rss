local M = {}

local sanitize = require("nvim-rss.modules.utils").sanitize

function M.insert_entries(entries)
	local append = vim.fn.append
	local line = vim.fn.line

	for i, entry in ipairs(entries) do
		append(line("$"), "")
		append(line("$"), "")
		append(line("$"), entry.title)
		append(line("$"), "------------------------")
		append(line("$"), entry.link)
		append(line("$"), "")
		if entry.summary then
			append(line("$"), sanitize(entry.summary))
		end
	end

	vim.cmd("0")
end

function M.update_feed_line(opt)
	-- Don't update if asterisk is disabled
	if opt.show_asterisk == false then
		return
	end

	-- Find the feed line
	vim.cmd("/" .. opt.xmlUrl:gsub("/", "\\/"))
	vim.cmd("nohlsearch")

	-- Get current line
	local line = vim.api.nvim_get_current_line()

	-- Remove existing asterisk if present
	local cleaned_line = line:gsub("^%*%s*", "")

	-- Add asterisk if feed changed
	if opt.changed then
		vim.api.nvim_set_current_line("* " .. cleaned_line)
	else
		vim.api.nvim_set_current_line(cleaned_line)
	end
end

function M.insert_feed_info(feed_info)
	-- feed_info is now the direct feed object from feedparser
	vim.cmd("normal o " .. (feed_info.title or "Untitled Feed"))
	vim.cmd("center")
	vim.cmd("normal o")
	if feed_info.link then
		vim.cmd("normal o " .. feed_info.link)
		vim.cmd("center")
	end
	vim.cmd("normal o")
	if feed_info.subtitle then
		vim.cmd("normal o " .. feed_info.subtitle)
		vim.cmd("center")
	end
	vim.cmd("normal o")

	vim.cmd("normal o ========================================")
	vim.cmd("center")
end

function M.create_feed_buffer()
	vim.cmd([[

    let win = bufwinnr("__FEED__")

    if win == -1
      vsplit __FEED__
      setlocal buftype=nofile
      setlocal nobackup noswapfile nowritebackup
      setlocal noautoindent nosmartindent
      setlocal nonumber norelativenumber
      setlocal filetype=markdown
    else
      exe win . "winvim.cmd w"
      normal! ggdG
    endif

  ]])
end

return M

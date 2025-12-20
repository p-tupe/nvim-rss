local M = {}

local utils = require("nvim-rss.modules.utils")
local sanitize = utils.sanitize
local format_relative_time = utils.format_relative_time

function M.insert_entries(entries)
	local append = vim.fn.append
	local line = vim.fn.line

	for i, entry in ipairs(entries) do
		append(line("$"), "")
		append(line("$"), "")
		append(line("$"), entry.title)

		-- Show publish date if available
		if entry.updated_parsed then
			append(line("$"), "Added " .. format_relative_time(entry.updated_parsed))
		end

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
	if opt.star_updated == false then
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

function M.insert_feed_info(feed_info, metadata)
	metadata = metadata or {}

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

	-- Show metadata if available
	if metadata.item_count or metadata.last_checked then
		vim.cmd("normal o")
		local meta_line = ""
		if metadata.item_count then
			meta_line = metadata.item_count .. " item" .. (metadata.item_count ~= 1 and "s" or "")
		end
		if metadata.last_checked then
			if meta_line ~= "" then
				meta_line = meta_line .. " • "
			end
			meta_line = meta_line .. "Synced " .. metadata.last_checked
		end
		vim.cmd("normal o " .. meta_line)
		vim.cmd("center")
	end

	vim.cmd("normal o")
	vim.cmd("normal o ========================================")
	vim.cmd("center")
end

function M.create_feed_buffer()
	vim.cmd([[

    " Close window if __FEED__ is open
    let win = bufwinnr("__FEED__")
    if win != -1
      exe win . "wincmd w"
      close
    endif

    " Delete __FEED__ buffer if it exists
    let buf = bufnr("__FEED__")
    if buf != -1
      exe "bwipeout! " . buf
    endif

    " Always create fresh buffer
    vsplit __FEED__
    setlocal buftype=nofile
    setlocal nobackup noswapfile nowritebackup
    setlocal noautoindent nosmartindent
    setlocal nonumber norelativenumber
    setlocal filetype=markdown

  ]])
end

return M

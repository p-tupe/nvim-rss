local M = {}

local utils = require("nvim-rss.modules.utils")
local sanitize = utils.sanitize
local format_relative_time = utils.format_relative_time

function M.insert_entries(entries)
	local lines = {}

	for i, entry in ipairs(entries) do
		table.insert(lines, "")
		table.insert(lines, "")
		table.insert(lines, entry.title)

		-- Show publish date if available
		if entry.updated_parsed then
			table.insert(lines, "Added " .. format_relative_time(entry.updated_parsed))
		end

		table.insert(lines, "------------------------")
		table.insert(lines, entry.link)
		table.insert(lines, "")
		if entry.summary then
			local summary_lines = sanitize(entry.summary)
			if summary_lines then
				for _, summary_line in ipairs(summary_lines) do
					table.insert(lines, summary_line)
				end
			end
		end
	end

	-- Append all lines at once
	vim.api.nvim_buf_set_lines(0, -1, -1, false, lines)

	-- Go to first line
	vim.api.nvim_win_set_cursor(0, {1, 0})
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
	-- Close window if __FEED__ is open
	local win = vim.fn.bufwinnr("__FEED__")
	if win ~= -1 then
		vim.cmd(win .. "wincmd w")
		vim.cmd("close")
	end

	-- Delete __FEED__ buffer if it exists
	local buf = vim.fn.bufnr("__FEED__")
	if buf ~= -1 then
		vim.cmd("bwipeout! " .. buf)
	end

	-- Create fresh buffer in vsplit
	vim.cmd("vsplit __FEED__")

	-- Set buffer options
	local bufnr = vim.fn.bufnr("__FEED__")
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].autoindent = false
	vim.bo[bufnr].smartindent = false
	vim.bo[bufnr].filetype = "markdown"

	-- Set window-local options
	vim.wo.number = false
	vim.wo.relativenumber = false

	-- Set buffer-local versions of global options
	vim.opt_local.backup = false
	vim.opt_local.swapfile = false
	vim.opt_local.writebackup = false
end

return M

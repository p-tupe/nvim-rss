---Mock vim API for testing
local M = {}

-- Helper function for deep copy
local function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == "table" then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

-- Mock vim global
_G.vim = {
	deepcopy = deepcopy,
	fn = {
		stdpath = function(what)
			if what == "data" then
				return "/tmp/nvim_rss_test_data"
			elseif what == "cache" then
				return "/tmp/nvim_rss_test_cache"
			end
			return "/tmp/nvim_rss_test"
		end,
		expand = function(path)
			-- Simple path expansion
			if path:match("^~") then
				return path:gsub("^~", os.getenv("HOME") or "/home/user")
			end
			return path
		end,
		mkdir = function(path, mode)
			-- Mock directory creation
			M.created_dirs = M.created_dirs or {}
			table.insert(M.created_dirs, path)
			return 1
		end,
		filereadable = function(path)
			-- Check if file exists in mock filesystem
			M.mock_files = M.mock_files or {}
			return M.mock_files[path] and 1 or 0
		end,
		readfile = function(path)
			-- Read from mock filesystem
			M.mock_files = M.mock_files or {}
			if M.mock_files[path] then
				return vim.split(M.mock_files[path], "\n")
			end
			return {}
		end,
		writefile = function(lines, path, flags)
			-- Write to mock filesystem
			M.mock_files = M.mock_files or {}
			M.mock_files[path] = table.concat(lines, "\n")
			return 0
		end,
		glob = function(pattern, nosuf, list)
			-- Mock glob - return files matching pattern
			M.mock_files = M.mock_files or {}
			local matches = {}
			for path in pairs(M.mock_files) do
				-- Convert glob pattern to Lua pattern
				-- Escape special Lua pattern characters except *
				local lua_pattern = pattern
					:gsub("([%.%-%+%[%]%(%)%^%$])", "%%%1") -- Escape special chars
					:gsub("%*", ".-") -- Convert * to .- (non-greedy match)
				if path:match("^" .. lua_pattern .. "$") then
					table.insert(matches, path)
				end
			end
			return list and matches or table.concat(matches, "\n")
		end,
		delete = function(path)
			-- Delete from mock filesystem
			M.mock_files = M.mock_files or {}
			M.mock_files[path] = nil
			return 0
		end,
	},
	split = function(str, sep)
		local result = {}
		for line in str:gmatch("[^\n]+") do
			table.insert(result, line)
		end
		return result
	end,
	log = {
		levels = {
			DEBUG = 0,
			INFO = 1,
			WARN = 2,
			ERROR = 3,
		},
	},
	notify = function(msg, level)
		-- Store notifications for testing
		M.notifications = M.notifications or {}
		table.insert(M.notifications, { msg = msg, level = level })
	end,
	loop = {
		new_pipe = function(ipc)
			-- Mock pipe for testing
			return {
				shutdown = function() end,
				read_stop = function() end,
				close = function() end,
			}
		end,
	},
	cmd = function(command)
		-- Mock vim commands
		M.commands = M.commands or {}
		table.insert(M.commands, command)
	end,
	api = {
		nvim_get_current_line = function()
			return M.current_line or ""
		end,
		nvim_eval = function(expr)
			return M.eval_result or {}
		end,
		nvim_exec = function(commands, output)
			return ""
		end,
	},
}

-- Helper to reset mocks
function M.reset()
	M.notifications = {}
	M.commands = {}
	M.mock_files = {}
	M.created_dirs = {}
	M.current_line = ""
	M.eval_result = {}

	-- Reset stdpath to default
	_G.vim.fn.stdpath = function(what)
		if what == "data" then
			return "/tmp/nvim_rss_test_data"
		elseif what == "cache" then
			return "/tmp/nvim_rss_test_cache"
		end
		return "/tmp/nvim_rss_test"
	end
end

-- Helper to get notifications
function M.get_notifications()
	return M.notifications or {}
end

-- Helper to clear notifications
function M.clear_notifications()
	M.notifications = {}
end

-- Helper to find notification by pattern
function M.find_notification(pattern)
	for _, notif in ipairs(M.notifications or {}) do
		if notif.msg:match(pattern) then
			return notif
		end
	end
	return nil
end

-- Helper to set mock file content
function M.set_file(path, content)
	M.mock_files = M.mock_files or {}
	M.mock_files[path] = content
end

-- Helper to get mock file content
function M.get_file(path)
	M.mock_files = M.mock_files or {}
	return M.mock_files[path]
end

return M

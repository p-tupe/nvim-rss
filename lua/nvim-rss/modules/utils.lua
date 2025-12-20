local M = {}

function M.sanitize(text)
	if not text then
		return
	end
	local str = tostring(text):gsub("<.->", "") -- Remove markup
	local t = {}
	for s in string.gmatch(str, "([^\n]+)") do
		t[#t + 1] = s
	end
	return t
end

function M.get_url(str)
	local url = str:match("https?://%S*")
	return url
end

function M.format_relative_time(timestamp)
	if not timestamp then
		return "unknown"
	end

	local now = os.time()
	local diff = now - timestamp

	if diff < 60 then
		return "just now"
	elseif diff < 3600 then
		local mins = math.floor(diff / 60)
		return mins .. " min" .. (mins ~= 1 and "s" or "") .. " ago"
	elseif diff < 86400 then
		local hours = math.floor(diff / 3600)
		return hours .. " hour" .. (hours ~= 1 and "s" or "") .. " ago"
	elseif diff < 604800 then
		local days = math.floor(diff / 86400)
		return days .. " day" .. (days ~= 1 and "s" or "") .. " ago"
	else
		local weeks = math.floor(diff / 604800)
		return weeks .. " week" .. (weeks ~= 1 and "s" or "") .. " ago"
	end
end

return M

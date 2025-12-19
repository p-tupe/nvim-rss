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

return M

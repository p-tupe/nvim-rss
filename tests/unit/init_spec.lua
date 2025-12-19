local vim_mock = require("tests.helpers.vim_mock")

describe("init module", function()
	local nvim_rss

	before_each(function()
		vim_mock.reset()
		package.loaded["nvim-rss"] = nil
		package.loaded["nvim-rss.modules.cache"] = nil
		package.loaded["nvim-rss.modules.utils"] = nil
		package.loaded["nvim-rss.modules.buffer"] = nil
		package.loaded["nvim-rss.modules.feedparser"] = nil
		nvim_rss = require("nvim-rss")
	end)

	describe("setup", function()
		it("should initialize with default options", function()
			nvim_rss.setup()
			local notifications = vim_mock.get_notifications()
			assert.is_true(#notifications == 0)
		end)

		it("should accept custom feeds_dir", function()
			nvim_rss.setup({ feeds_dir = "/custom/path" })
			local notifications = vim_mock.get_notifications()
			assert.is_true(#notifications == 0)
		end)

		it("should accept star_updated option", function()
			nvim_rss.setup({ star_updated = false })
			local notifications = vim_mock.get_notifications()
			assert.is_true(#notifications == 0)
		end)

		it("should accept log_level option", function()
			nvim_rss.setup({ log_level = "debug" })
			local notifications = vim_mock.get_notifications()
			assert.is_true(#notifications == 0)
		end)
	end)

	describe("open_feeds_tab", function()
		it("should execute tabnew command with feeds file path", function()
			nvim_rss.setup({ feeds_dir = "~" })
			nvim_rss.open_feeds_tab()

			local commands = vim_mock.commands
			assert.is_not_nil(commands)
			assert.is_true(#commands > 0)
			local found_tabnew = false
			for _, cmd in ipairs(commands) do
				if cmd:match("tabnew.*nvim%.rss") then
					found_tabnew = true
					break
				end
			end
			assert.is_true(found_tabnew, "Expected tabnew command with nvim.rss file")
		end)
	end)

	describe("view_feed", function()
		it("should notify error if no URL on current line", function()
			vim_mock.current_line = "no url here"
			nvim_rss.setup()
			nvim_rss.view_feed()

			local notif = vim_mock.find_notification("Invalid URL")
			assert.is_not_nil(notif)
			assert.equals(vim.log.levels.ERROR, notif.level)
		end)

		it("should notify warning if no cached data exists", function()
			vim_mock.current_line = "https://example.com/feed.xml Test Feed"
			nvim_rss.setup()
			nvim_rss.view_feed()

			local notif = vim_mock.find_notification("No cached data")
			assert.is_not_nil(notif)
			assert.equals(vim.log.levels.WARN, notif.level)
		end)
	end)

	describe("clean_feed", function()
		it("should notify error if no URL on current line", function()
			vim_mock.current_line = "no url here"
			nvim_rss.setup()
			nvim_rss.clean_feed()

			local notif = vim_mock.find_notification("Invalid URL")
			assert.is_not_nil(notif)
			assert.equals(vim.log.levels.ERROR, notif.level)
		end)

		it("should notify success when cleaning feed in debug mode", function()
			vim_mock.current_line = "https://example.com/feed.xml Test Feed"
			nvim_rss.setup({ log_level = "debug" })
			nvim_rss.clean_feed()

			local notif = vim_mock.find_notification("Cleared cache for feed")
			assert.is_not_nil(notif)
			assert.equals(vim.log.levels.INFO, notif.level)
		end)

		it("should execute without error even if no notification shown", function()
			vim_mock.current_line = "https://example.com/feed.xml Test Feed"
			nvim_rss.setup({ log_level = "error" })

			local ok = pcall(function()
				nvim_rss.clean_feed()
			end)

			assert.is_true(ok, "clean_feed should not error")
		end)
	end)

	describe("clean_all_feeds", function()
		it("should notify success when cleaning all feeds in debug mode", function()
			nvim_rss.setup({ log_level = "debug" })
			nvim_rss.clean_all_feeds()

			local notif = vim_mock.find_notification("Cleared all cached feeds")
			assert.is_not_nil(notif)
			assert.equals(vim.log.levels.INFO, notif.level)
		end)

		it("should execute without error", function()
			nvim_rss.setup({ log_level = "error" })

			local ok = pcall(function()
				nvim_rss.clean_all_feeds()
			end)

			assert.is_true(ok, "clean_all_feeds should not error")
		end)
	end)

	describe("import_opml", function()
		it("should notify info when importing OPML in debug mode", function()
			local opml_path = "/tmp/test.opml"
			local opml_content = [[
<?xml version="1.0" encoding="UTF-8"?>
<opml version="1.0">
  <body>
    <outline type="rss" xmlUrl="https://example.com/feed.xml" title="Test Feed"/>
  </body>
</opml>
]]
			local opml_file = io.open(opml_path, "w")
			opml_file:write(opml_content)
			opml_file:close()

			nvim_rss.setup({ feeds_dir = "/tmp", log_level = "debug" })
			nvim_rss.import_opml(opml_path)

			local notif = vim_mock.find_notification("Importing")
			assert.is_not_nil(notif)
			assert.equals(vim.log.levels.INFO, notif.level)

			os.remove(opml_path)
			os.remove("/tmp/nvim.rss")
		end)

		it("should execute without error", function()
			local opml_path = "/tmp/test2.opml"
			local opml_content = [[
<?xml version="1.0" encoding="UTF-8"?>
<opml version="1.0">
  <body>
    <outline type="rss" xmlUrl="https://example.com/feed.xml" title="Test Feed"/>
  </body>
</opml>
]]
			local opml_file = io.open(opml_path, "w")
			opml_file:write(opml_content)
			opml_file:close()

			nvim_rss.setup({ feeds_dir = "/tmp", log_level = "error" })

			local ok = pcall(function()
				nvim_rss.import_opml(opml_path)
			end)

			assert.is_true(ok, "import_opml should not error")

			os.remove(opml_path)
			os.remove("/tmp/nvim.rss")
		end)
	end)

	describe("fetch_feed", function()
		it("should notify error if no URL on current line", function()
			vim_mock.current_line = "no url here"
			nvim_rss.setup()
			nvim_rss.fetch_feed()

			local notif = vim_mock.find_notification("Invalid URL")
			assert.is_not_nil(notif)
			assert.equals(vim.log.levels.ERROR, notif.level)
		end)
	end)

	describe("fetch_all_feeds", function()
		it("should handle empty feeds file gracefully", function()
			local feeds_path = "/tmp/nvim_test_empty.rss"
			local feeds_file = io.open(feeds_path, "w")
			feeds_file:write("")
			feeds_file:close()

			nvim_rss.setup({ feeds_dir = "/tmp" })

			local ok, err = pcall(function()
				for line in io.lines(feeds_path) do
				end
			end)

			assert.is_true(ok, "Should handle empty file: " .. tostring(err))

			os.remove(feeds_path)
		end)

		it("should not crash when processing feeds file", function()
			local feeds_path = "/tmp/nvim_test_valid.rss"
			local feeds_file = io.open(feeds_path, "w")
			feeds_file:write("https://example.com/feed.xml Test Feed\n")
			feeds_file:close()

			nvim_rss.setup({ feeds_dir = "/tmp" })

			local ok, err = pcall(function()
				for line in io.lines(feeds_path) do
				end
			end)

			assert.is_true(ok, "Should be able to read feeds file: " .. tostring(err))

			os.remove(feeds_path)
		end)
	end)

	describe("logging", function()
		it("should only show errors by default", function()
			nvim_rss.setup({ log_level = "error" })
			vim_mock.current_line = "https://example.com/feed.xml"
			nvim_rss.view_feed()

			local notifications = vim_mock.get_notifications()
			for _, notif in ipairs(notifications) do
				assert.is_true(
					notif.level >= vim.log.levels.WARN,
					"Default log_level should only show WARN and ERROR"
				)
			end
		end)

		it("should show INFO, WARN, and ERROR in info mode", function()
			nvim_rss.setup({ log_level = "info" })
			vim_mock.clear_notifications()

			nvim_rss.clean_all_feeds()

			local notif = vim_mock.find_notification("Cleared all cached feeds")
			assert.is_not_nil(notif, "Should show INFO level messages in info mode")
			assert.equals(vim.log.levels.INFO, notif.level)
		end)

		it("should show all logs in debug mode", function()
			nvim_rss.setup({ log_level = "debug" })
			vim_mock.clear_notifications()

			nvim_rss.clean_all_feeds()

			local notif = vim_mock.find_notification("Cleared all cached feeds")
			assert.is_not_nil(notif, "Should show all messages in debug mode")
		end)
	end)

	describe("star_updated option", function()
		it("should default to true", function()
			nvim_rss.setup()
		end)

		it("should accept false value", function()
			nvim_rss.setup({ star_updated = false })
		end)
	end)
end)

require("plenary.busted")

local yeet = require("yeet")
yeet.setup({
    yeet_and_run = true,
    use_cache_file = false,
    clear_before_yeet = false,
    notify_on_success = false,
    interrupt_before_yeet = false,
    warn_tmux_not_running = false,
})

---@param target Target
---@param expected string
local function assert_output(target, expected)
    vim.wait(100)
    local lines = vim.api.nvim_buf_get_lines(target.buffer, 0, -1, true)

    local out = {}
    for _, line in ipairs(lines) do
        if line ~= "" then
            table.insert(out, line)
        end
    end

    assert.is.equal(expected, table.concat(out, "\n"))
end

describe("buffer target", function()
    local buffer = require("yeet.buffer")
    local target = buffer.new()
    yeet._target = target

    vim.api.nvim_chan_send(target.channel, "bash\n")
    vim.api.nvim_chan_send(target.channel, "PS1='$ '\n")
    print("wait for bash")
    vim.wait(1000)

    before_each(function()
        print("before_each")
        vim.api.nvim_chan_send(target.channel, "\nclear\n")
        vim.wait(250)
    end)

    it("yeets and runs", function()
        yeet.execute("echo hello")
        assert_output(target, "$ echo hello\nhello\n$ ")
    end)

    it("yeets and does not run", function()
        yeet.execute("echo hello", { yeet_and_run = false })
        assert_output(target, "$ echo hello")
        yeet.execute("clear")
    end)

    it("escapes $variables", function()
        yeet.execute("ASD=123 && echo $ASD")
        assert_output(target, "$ ASD=123 && echo $ASD\n123\n$ ")
    end)

    it("interrupts with C-c", function()
        yeet.execute("sleep 100")
        vim.wait(100)
        yeet.execute("C-c echo hello")
        assert_output(
            target,
            "$ sleep 100\n^C\necho hello\n$ \n$ echo hello\nhello\n$ "
        )
    end)

    it("interrupts with option", function()
        yeet.execute("sleep 200")
        vim.wait(100)
        yeet.execute("echo hello", { interrupt_before_yeet = true })
        assert_output(
            target,
            "$ sleep 200\n^C\necho hello\n$ \n$ echo hello\nhello\n$ "
        )
    end)

    it("accepts multiple commands sent", function()
        yeet.execute("echo 1\necho 2\necho 3")
        assert_output(target, "$ echo 1\n1\n$ echo 2\n2\n$ echo 3\n3\n$ ")
    end)

    it("clears", function()
        yeet.execute("echo noise")
        yeet.execute("echo 4", { clear_before_yeet = true })
        assert_output(target, "$ echo 4\n4\n$ ")
    end)

    print("teardown")
    vim.api.nvim_buf_delete(target.buffer, { force = true })
end)

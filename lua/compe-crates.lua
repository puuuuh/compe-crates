local compe = require'compe'
local uv = vim.loop

local Crates = {
    count = 0,
    index = {}
}

local function get_path()
    if vim.g.cargo_compe_path then
        return vim.fn.expand(vim.g.cargo_compe_path)
    else
        return vim.fn.expand("~/.local/share/cargo-compe/")
    end
end

local function start(args, callback, cwd)
    local stdin = uv.new_pipe(true)
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)
    local stdio = {stdin, stdout, stderr}

    local handle_stderr = vim.schedule_wrap(function(err, chunk)
        if err then error("stderr error: " .. err) end

        if chunk then
            print(chunk)
        end
    end)

    local handle_stdout = vim.schedule_wrap(function(err, chunk)
        if err then error("stdout error: " .. err) end

        if chunk then
            print(chunk)
        else
            callback()
        end
    end)

    uv.spawn("git", {args = args, stdio = stdio, cwd = cwd}, function()
        stdout:read_stop()
        stdout:read_stop()
    end)

    uv.read_start(stdout, handle_stdout)
    uv.read_start(stderr, handle_stderr)
end

Crates.force_update = function(self)
    local root = get_path()
    local cache_path = root .. "cache.json"
    local index_path = root .. "index/"
    local cb = function ()
        os.remove(cache_path)
        self:load()
    end
    if vim.fn.isdirectory(index_path) == 0 then
        start({"clone", "https://github.com/rust-lang/crates.io-index.git", "--progress", "--depth=1", index_path}, cb)
    else
        start({"pull"}, cb, index_path)
    end
end

Crates.load = function(self)
    local root = get_path()
    local cache_path = root .. "cache.json"
    local index_path = root .. "index/"
    local f = io.open(cache_path, "r")
    if f then
        local data = vim.fn.json_decode(f:read("*a"))
        self.index = data.index
        self.count = data.count
        print("Indexed ", data.count, "crates")
        return
    end

    self.index = {}
    self.count = 0

    local function get_items(path)
        local current_items = {}
        local subdirs = {}
        do
            local fs, e = uv.fs_scandir(path)
            if e then
                return
            end
            while true do
                local name, type, e = uv.fs_scandir_next(fs)
                if e then
                    break
                end
                if not name then
                    break
                end

                if type == 'directory' then
                    table.insert(subdirs, name)
                else
                    local lpath = path .. name
                    local f = io.open(lpath)
                    local ver = ""
                    while true do
                        local new_ver = f:read("*l")
                        if not new_ver then
                            break
                        end
                        ver = new_ver
                    end
                    f:close()

                    local status, res = pcall(vim.fn.json_decode, ver)
                    if status then
                        self.count = self.count + 1
                        table.insert(current_items, {
                            path = lpath,
                            word = name .. ' = "' .. res.vers .. '"',
                            abbr = name,
                            vers = res.vers,
                        })
                    end
                end
            end
        end

        for i=1, #subdirs do
            current_items[subdirs[i]] = get_items(path .. subdirs[i] .. '/')
        end
        return current_items
    end

    self.index = get_items(index_path)
    local serialized = vim.fn.json_encode({ index = self.index, count = self.count})
    local f = io.open(cache_path, "w")
	if f == nil then
		uv.fs_mkdir(root, 511, nil)
		f = io.open(cache_path, "w")
	end
    f:write(serialized)
    print("Indexed ", self.count, "crates")
    -- print(tprint(self.index))
end

--- get_metadata
Crates.get_metadata = function(_)
    return {
        sort = false,
        priority = 10000,
        menu = '[CRG]';
        dup = 1,
    }
end

--- determine
Crates.determine = function(_, context)
    if vim.fn.expand('%:t') ~= "Cargo.toml" then
        return
    end
    local res = compe.helper.determine(context, {
        keyword_pattern = [[^\w*$]],
    })
    if res.keyword_pattern_offset ~= 0 then
       res.trigger_character_offset = #context.before_line
    end
    return res
end

--- complete
Crates.complete = function(self, args)
    local dirname = args.context.before_line
    if not dirname or #dirname < 4 then
        return args.abort()
    end

    self:_candidates(dirname, function(err, candidates)
        if err then
            return args.abort()
        end
        table.sort(candidates, function(item1, item2)
            return self:_compare(item1, item2)
        end)

        args.callback({
            items = candidates,
        })
    end)
end

Crates._candidates = function(self, prefix, callback)
    local current = self.index
    local chunksize = 2
    for i=1, #prefix, chunksize do
        local cur_prefix = prefix:sub(i,i+chunksize - 1)

        local current_node = current[cur_prefix]
        if not current_node then
            break
        end
        current = current_node
    end

    local items = {}

    local function get_items(node)
        for k, v in pairs(node) do
            if type(k) ~= "number" then
                get_items(v)
            else
                table.insert(items, v)
            end
        end
    end

    get_items(current)

    callback(nil, items)
end

--- _compare
Crates._compare = function(self, item1, item2)
    return item1.word < item2.word
end

return Crates

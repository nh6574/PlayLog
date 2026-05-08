PlayLog.log_store = PlayLog.log_store or {}

local LogStore = PlayLog.log_store

local PLAYLOG_RUNS_DIR = "Mods/PlayLog/playlog_runs"
local PLAYLOG_SECTION_PLAIN = "[PLAIN]"

local function pl_make_run_id()
    return os.date("%Y%m%d_%H%M%S") .. "_" .. tostring(math.random(100000, 999999))
end

local function pl_get_log_file_path()
    if not (G and G.GAME) then return nil end
    if not G.GAME.playlog_run_id then
        G.GAME.playlog_run_id = pl_make_run_id()
    end
    if not G.GAME.playlog_log_path then
        G.GAME.playlog_log_path = PLAYLOG_RUNS_DIR .. "/" .. tostring(G.GAME.playlog_run_id) .. ".txt"
    end
    G.playlog_last_log_path = G.GAME.playlog_log_path
    return G.GAME.playlog_log_path
end

local function pl_split_by(text, sep)
    local parts = {}
    text = tostring(text or "")
    sep = tostring(sep or "")
    if sep == "" then
        parts[1] = text
        return parts
    end
    local start_idx = 1
    while true do
        local at = text:find(sep, start_idx, true)
        if not at then
            parts[#parts + 1] = text:sub(start_idx)
            break
        end
        parts[#parts + 1] = text:sub(start_idx, at - 1)
        start_idx = at + #sep
    end
    return parts
end

local function pl_encode_text(text)
    text = tostring(text or "")
    if love and love.data and love.data.encode then
        return love.data.encode("string", "base64", text)
    end
    return text:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
end

local function pl_decode_text(text)
    text = tostring(text or "")
    if love and love.data and love.data.decode then
        local ok, decoded = pcall(function()
            return love.data.decode("string", "base64", text)
        end)
        if ok and decoded then
            return decoded
        end
    end
    return text:gsub("\\t", "\t"):gsub("\\r", "\r"):gsub("\\n", "\n"):gsub("\\\\", "\\")
end

local function pl_serialize_colour(col)
    if not col then return "" end
    return string.format("%.6f,%.6f,%.6f,%.6f", col[1] or 1, col[2] or 1, col[3] or 1, col[4] or 1)
end

local function pl_deserialize_colour(s)
    s = tostring(s or "")
    if s == "" then return nil end
    local parts = pl_split_by(s, ",")
    local r = tonumber(parts[1])
    local g = tonumber(parts[2])
    local b = tonumber(parts[3])
    local a = tonumber(parts[4])
    if not (r and g and b and a) then return nil end
    return { r, g, b, a }
end

function LogStore.plain_from_segments(segments)
    if not segments then return "" end
    local out = {}
    for i = 1, #segments do
        out[#out + 1] = tostring((segments[i] and segments[i].text) or "")
    end
    return table.concat(out, "")
end

function LogStore.serialize_segments(segments)
    if not segments then return "" end
    local items = {}
    for i = 1, #segments do
        local seg = segments[i] or {}
        items[#items + 1] = table.concat({
            pl_encode_text(seg.text or ""),
            pl_serialize_colour(seg.colour),
            pl_serialize_colour(seg.bg_colour),
            tostring(tonumber(seg.scale) or 1),
            pl_encode_text(seg.tooltip or ""),
            pl_serialize_colour(seg.underline_colour),
            pl_serialize_colour(seg.strikethrough_colour),
        }, "|")
    end
    return table.concat(items, ";")
end

function LogStore.deserialize_segments(blob)
    blob = tostring(blob or "")
    if blob == "" then return nil end
    local raw_segments = pl_split_by(blob, ";")
    local segments = {}
    for i = 1, #raw_segments do
        local raw_seg = raw_segments[i]
        if raw_seg ~= "" then
            local fields = pl_split_by(raw_seg, "|")
            local colour = pl_deserialize_colour(fields[2])
            local tooltip = pl_decode_text(fields[5] or "")
            local seg = {
                text = pl_decode_text(fields[1] or ""),
                colour = colour,
                plain = not colour,
                bg_colour = pl_deserialize_colour(fields[3]),
                scale = tonumber(fields[4]) or 1,
                underline_colour = pl_deserialize_colour(fields[6]),
                strikethrough_colour = pl_deserialize_colour(fields[7]),
            }
            if tooltip ~= "" then seg.tooltip = tooltip end
            segments[#segments + 1] = seg
        end
    end
    if #segments == 0 then return nil end
    return segments
end

local function pl_build_plain_log_text(run_id, plain_entries)
    local out = {}
    out[#out + 1] = "PLAYLOG2\t" .. tostring(run_id or "")
    out[#out + 1] = ""
    out[#out + 1] = PLAYLOG_SECTION_PLAIN
    for i = 1, #(plain_entries or {}) do
        local plain = tostring(plain_entries[i] or "")
        out[#out + 1] = plain:gsub("\n", "\\n")
    end
    out[#out + 1] = ""
    return table.concat(out, "\n")
end

local function pl_reset_runtime_entries()
    G.playlog_entries = {}
    G.playlog_pending_entries = {}
    G.playlog_pending_start = 1
    G.playlog_plain_entries = {}
    G.playlog_saved_segments = {}
    G.playlog_scroll_shift = nil
end

function LogStore.ensure_log_file_initialized()
    if not (G and G.GAME) then return nil end
    local path = pl_get_log_file_path()
    if not path then return nil end
    G.playlog_plain_entries = G.playlog_plain_entries or {}
    if G.GAME.playlog_log_initialized then
        return path
    end
    if love and love.filesystem and love.filesystem.createDirectory then
        love.filesystem.createDirectory("Mods")
        love.filesystem.createDirectory("Mods/PlayLog")
        love.filesystem.createDirectory(PLAYLOG_RUNS_DIR)
    end

    local info = love.filesystem.getInfo(path)
    if not info then
        local initial = pl_build_plain_log_text(G.GAME.playlog_run_id, G.playlog_plain_entries)
        love.filesystem.write(path, initial)
    end
    G.GAME.playlog_log_initialized = true
    return path
end

local function pl_append_log_file(line)
    local path = LogStore.ensure_log_file_initialized()
    if not path then return end
    local payload = tostring(line or "") .. "\n"
    if love.filesystem.append then
        love.filesystem.append(path, payload)
    else
        local existing = love.filesystem.read(path) or ""
        love.filesystem.write(path, existing .. payload)
    end
end

function LogStore.append_rich_segments(segments)
    if not (G and G.GAME) then return end
    G.playlog_saved_segments = G.playlog_saved_segments or {}
    G.playlog_saved_segments[#G.playlog_saved_segments + 1] = segments
    G.GAME.playlog_segment_payloads = G.GAME.playlog_segment_payloads or {}
    G.GAME.playlog_segment_payloads[#G.GAME.playlog_segment_payloads + 1] = LogStore.serialize_segments(segments)
    pl_append_log_file(LogStore.plain_from_segments(segments):gsub("\n", "\\n"))
end

function LogStore.restore_from_game()
    if not (G and G.GAME) then return 0 end

    local restored = 0
    pl_reset_runtime_entries()
    G.GAME.playlog_segment_payloads = G.GAME.playlog_segment_payloads or {}

    for i = 1, #G.GAME.playlog_segment_payloads do
        local payload = tostring(G.GAME.playlog_segment_payloads[i] or "")
        if payload ~= "" then
            local segments = LogStore.deserialize_segments(payload)
            if segments then
                G.playlog_entries[#G.playlog_entries + 1] = { segments = segments }
                G.playlog_saved_segments[#G.playlog_saved_segments + 1] = segments
                G.playlog_plain_entries[#G.playlog_plain_entries + 1] = LogStore.plain_from_segments(segments)
                restored = restored + 1
            end
        end
    end
    G.GAME.playlog_log_initialized = true
    return restored
end

function LogStore.begin_new_run()
    if not (G and G.GAME) then return nil end
    local run_id = pl_make_run_id()
    local log_path = PLAYLOG_RUNS_DIR .. "/" .. tostring(run_id) .. ".txt"
    G.GAME.playlog_run_id = run_id
    G.GAME.playlog_log_path = log_path
    G.GAME.playlog_log_initialized = nil
    G.GAME.playlog_segment_payloads = {}
    pl_reset_runtime_entries()
    G.playlog_last_log_path = log_path
    return LogStore.ensure_log_file_initialized()
end

function LogStore.prepare_start_run()
    if not (G and G.GAME) then return end
    if not G.GAME.playlog_run_id then
        G.GAME.playlog_run_id = pl_make_run_id()
    end
    if not G.GAME.playlog_log_path then
        G.GAME.playlog_log_path = PLAYLOG_RUNS_DIR .. "/" .. tostring(G.GAME.playlog_run_id) .. ".txt"
    end
    if (type(G.GAME.playlog_segment_payloads) ~= 'table' or #G.GAME.playlog_segment_payloads == 0)
        and type(G.playlog_saved_segments) == 'table'
        and #G.playlog_saved_segments > 0
        and G.playlog_last_log_path == G.GAME.playlog_log_path then
        G.GAME.playlog_segment_payloads = {}
        for i = 1, #G.playlog_saved_segments do
            G.GAME.playlog_segment_payloads[#G.GAME.playlog_segment_payloads + 1] =
                LogStore.serialize_segments(G.playlog_saved_segments[i])
        end
    end
    G.GAME.playlog_log_initialized = nil
    G.playlog_last_log_path = G.GAME.playlog_log_path
end

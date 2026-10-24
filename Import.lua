-- BALEREOT COMMUNITY  |  Toolbox + Asset Importer (satu panel)
--   Tab TOOLBOX     : cari & insert Model / Texture / Decal / Audio lewat Studio Lite
--   Tab IMPORT FILE : import file .rbxm / .rbxmx / .rbxl / .rbxlx dari workspace executor
--   Tab TOOLS       : SCRIPT LIBRARY (snippet siap pakai) + SCANNER script berbahaya (auto-scan saat insert model)
--   Akses           : key (Worker ATAU key.txt via KEY_LIST_URL, terikat akun + masa aktif) atau trial gratis 1 hari per akun
--   Pembuat key     : BalereotKeyManager.lua (script terpisah, khusus owner)
--   TEMA            : Royal Gold (premium) + tombol 3D + animasi buka/tutup

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local InsertService = game:GetService("InsertService")
local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local UIS = game:GetService("UserInputService")

-- PENGATURAN KEY
-- =====================================================================
-- Key dicek ke SERVER KEY milikmu (Cloudflare Worker, lihat SETUP.md).
-- Daftar key tidak pernah dikirim ke pemakai: script hanya mengirim key + akun,
-- server menjawab valid / tidak. Key dibuat & dicabut lewat BalereotKeyManager.lua.
--
-- ISI CHECK_URL dengan alamat Worker-mu, contoh:
--     https://balereot-key.namamu.workers.dev
-- (tanpa garis miring di akhir)
-- =====================================================================
local CHECK_URL = "https://GANTI-DENGAN-ALAMAT-WORKER-MU.workers.dev"  -- <<< alamat Worker
local KEY_LIST_URL = "https://raw.githubusercontent.com/sunlightwar7-bot/Import-/refs/heads/main/key.txt"   -- <<< CADANGAN tanpa Worker: link RAW key.txt (contoh: https://raw.githubusercontent.com/USER/REPO/main/key.txt)
                          --     Dipakai hanya kalau CHECK_URL belum diisi. Kurang aman dibanding Worker (daftar key bisa dibuka orang).
local KEY_FILE = "balereot_key.txt"           -- key tersimpan agar tidak input ulang
local GET_KEY_LINK = "https://discord.gg/HAkGRPayDn"  -- link tombol GET KEY (otomatis buka Discord)

-- DAFTAR HARGA (tampil di layar key). Ubah teks di sini kalau harga berubah.
local PRICES = {
    {"Permanen", "Rp 35.000"},
    {"Sebulan", "Rp 25.000"},
    {"Seminggu", "Rp 10.000"},
}

-- TRIAL GRATIS: 1 akun boleh pakai gratis selama TRIAL_HOURS jam (24 = 1 hari), sekali saja.
-- Dicatat per akun (UserId) lewat file lokal executor (butuh writefile/readfile/isfile).
local TRIAL_ENABLED = true        -- <<< true = ada trial gratis, false = semua orang wajib key
local TRIAL_HOURS = 24            -- <<< lama trial (jam)
local TRIAL_FILE_PREFIX = "balereot_trial_"

-- PENGATURAN IMPORT FILE
local ASSET_FOLDER = "ImporterAssets"   -- taruh file .rbxm / .rbxl di workspace/ImporterAssets

-- PENGATURAN
local SPAWN_DISTANCE = 12      -- jarak spawn di depan kamera (studs)
local BG_ASSET_ID = 102728536712814   -- ID gambar logo BALEREOT COMMUNITY
local BG_URL = nil            -- atau link langsung (raw) ke file PNG, contoh dari GitHub
local BG_TRANSPARENCY = 0.6   -- 0 = jelas, 1 = hilang

-- PALET PREMIUM: Royal Gold (obsidian + emas)
local C = {
    bg = Color3.fromRGB(9, 8, 11), panel = Color3.fromRGB(22, 19, 26),
    header = Color3.fromRGB(14, 12, 17), input = Color3.fromRGB(30, 26, 34),
    stroke = Color3.fromRGB(110, 86, 40), accent = Color3.fromRGB(236, 186, 74),
    accent2 = Color3.fromRGB(255, 232, 170), cyan = Color3.fromRGB(255, 142, 72),
    text = Color3.fromRGB(248, 242, 230), sub = Color3.fromRGB(176, 164, 142),
    dim = Color3.fromRGB(112, 104, 90), green = Color3.fromRGB(90, 228, 150),
    red = Color3.fromRGB(238, 82, 92), yellow = Color3.fromRGB(255, 208, 96),
    white = Color3.new(1, 1, 1), ink = Color3.fromRGB(28, 18, 4),
}

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end
local function round(o, r) return new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o) end
local function stroke(o, color, thick, transp)
    return new("UIStroke", {Color = color, Thickness = thick or 1, Transparency = transp or 0}, o)
end
local function gradient(o, keys, rot)
    local pts = {}
    for _, k in ipairs(keys) do pts[#pts + 1] = ColorSequenceKeypoint.new(k[1], k[2]) end
    return new("UIGradient", {Color = ColorSequence.new(pts), Rotation = rot or 0}, o)
end
local function spin(grad, seconds)
    TweenService:Create(grad, TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {Rotation = 360}):Play()
end
local function thumb(id, size)
    return ("rbxthumb://type=Asset&id=%d&w=%d&h=%d"):format(id, size, size)
end

-- partikel emas halus yang melayang naik (bikin panel terasa hidup)
local function particles(parent, count, z)
    local holder = new("Frame", {Name = "FXParticles", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z or 1}, parent)
    local rnd = Random.new()
    for _ = 1, count do
        task.spawn(function()
            task.wait(rnd:NextNumber(0, 4))
            local s0 = rnd:NextInteger(2, 4)
            local d = new("Frame", {
                Size = UDim2.fromOffset(s0, s0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 218, 130),
                BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z or 1,
            }, holder)
            new("UICorner", {CornerRadius = UDim.new(1, 0)}, d)
            while d.Parent do
                local x = rnd:NextNumber(0.04, 0.96)
                local dur = rnd:NextNumber(5, 9)
                d.Position = UDim2.new(x, 0, 1.03, 0)
                d.BackgroundTransparency = 1
                TweenService:Create(d, TweenInfo.new(dur, Enum.EasingStyle.Linear), {Position = UDim2.new(x + rnd:NextNumber(-0.08, 0.08), 0, -0.05, 0)}):Play()
                TweenService:Create(d, TweenInfo.new(dur * 0.3), {BackgroundTransparency = rnd:NextNumber(0.35, 0.7)}):Play()
                task.wait(dur * 0.7)
                TweenService:Create(d, TweenInfo.new(dur * 0.3), {BackgroundTransparency = 1}):Play()
                task.wait(dur * 0.3)
            end
        end)
    end
end

-- =====================================================================
-- TEMA OTOMATIS + ANIMASI
--   - warna ungu lama otomatis diganti ke tema baru
--   - tombol: hover membesar, ditekan menciut, dilepas memantul + ripple
--   - jendela utama & layar key muncul dengan animasi pop
--   - garis header berkilau bergerak
-- =====================================================================
do
    local GuiService = game:GetService("GuiService")
    local Debris = game:GetService("Debris")

    local function key(c)
        return math.round(c.R * 255) .. "," .. math.round(c.G * 255) .. "," .. math.round(c.B * 255)
    end

    local function ripple(b, input)
        if b.BackgroundTransparency > 0.9 then return end
        local inset = GuiService:GetGuiInset()
        local sz = b.AbsoluteSize
        local rel = Vector2.new(input.Position.X, input.Position.Y) - inset - b.AbsolutePosition
        rel = Vector2.new(math.clamp(rel.X, 0, sz.X), math.clamp(rel.Y, 0, sz.Y))
        local dot = Instance.new("Frame")
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Position = UDim2.fromOffset(rel.X, rel.Y)
        dot.Size = UDim2.fromOffset(0, 0)
        dot.BackgroundColor3 = Color3.new(1, 1, 1)
        dot.BackgroundTransparency = 0.65
        dot.BorderSizePixel = 0
        dot.ZIndex = b.ZIndex + 20
        local cr = Instance.new("UICorner")
        cr.CornerRadius = UDim.new(1, 0)
        cr.Parent = dot
        b.ClipsDescendants = true
        dot.Parent = b
        local d = math.max(sz.X, sz.Y) * 2.4
        TweenService:Create(dot, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.fromOffset(d, d), BackgroundTransparency = 1}):Play()
        Debris:AddItem(dot, 0.6)
    end

    local function isPress(i)
        return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
    end

    local function shade(c, f) return Color3.new(c.R * f, c.G * f, c.B * f) end

    -- tampilan 3D: kilau atas, bayangan bawah, garis highlight, bibir tebal di dasar
    local function bevel(b)
        if b.Name:sub(1, 5) == "Btn3D" then return nil end
        if b.Size == UDim2.new() or b.Size.Y.Offset > 60 then return nil end
        local cr = b:FindFirstChildOfClass("UICorner")
        local rad = cr and cr.CornerRadius.Offset or 6
        local els = {}
        local function mk(props)
            local f = Instance.new("Frame")
            f.BorderSizePixel = 0
            f.Active = false
            f.ZIndex = b.ZIndex + 1
            for k, v in pairs(props) do f[k] = v end
            f.Parent = b
            els[#els + 1] = f
            return f
        end
        local sheen = mk({Name = "FX3D_Sheen", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82})
        if cr then
            local c2 = Instance.new("UICorner")
            c2.CornerRadius = cr.CornerRadius
            c2.Parent = sheen
        end
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0))
        g.Rotation = 90
        g.Parent = sheen
        mk({Name = "FX3D_Hi", Size = UDim2.new(1, -rad * 1.5, 0, 1), Position = UDim2.new(0, rad * 0.75, 0, 1),
            BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45})
        local lip = mk({Name = "FX3D_Lip", Size = UDim2.new(1, -rad, 0, 3), Position = UDim2.new(0, rad / 2, 1, -3),
            BackgroundColor3 = shade(b.BackgroundColor3, 0.45), BackgroundTransparency = 0.05, ZIndex = b.ZIndex + 2})
        local lc = Instance.new("UICorner")
        lc.CornerRadius = UDim.new(0, 2)
        lc.Parent = lip
        local st
        if not b:FindFirstChildOfClass("UIStroke") then
            st = Instance.new("UIStroke")
            st.Thickness = 1.2
            st.Transparency = 0.45
            st.Color = Color3.new(1, 1, 1)
            st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            local sg = Instance.new("UIGradient")
            sg.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(40, 40, 40))
            sg.Rotation = 90
            sg.Parent = st
            st.Parent = b
        end
        local function sync()
            local on = b.BackgroundTransparency < 0.5
            for _, e in ipairs(els) do e.Visible = on end
            if st then st.Enabled = on end
        end
        sync()
        b:GetPropertyChangedSignal("BackgroundTransparency"):Connect(sync)
        b:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
            lip.BackgroundColor3 = shade(b.BackgroundColor3, 0.45)
        end)
        return lip, sheen, rad
    end

    local function attach(b)
        if b:GetAttribute("FX") then return end
        if b.Size.X.Scale >= 1 and b.Size.Y.Scale >= 1 then return end -- overlay layar penuh
        b:SetAttribute("FX", true)
        local sc = Instance.new("UIScale")
        sc.Parent = b
        local lip, sheen, rad
        task.defer(function()
            if b.Parent then lip, sheen, rad = bevel(b) end
        end)
        local function go(s, t, style)
            TweenService:Create(sc, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = s}):Play()
        end
        local function lipTo(down)
            if not lip then return end
            local h = down and 1 or 3
            TweenService:Create(lip, TweenInfo.new(0.07, Enum.EasingStyle.Quad), {
                Size = UDim2.new(1, -rad, 0, h), Position = UDim2.new(0, rad / 2, 1, -h),
            }):Play()
            TweenService:Create(sheen, TweenInfo.new(0.07), {BackgroundTransparency = down and 0.7 or 0.82}):Play()
        end
        local function big() return b.AbsoluteSize.X > 140 end
        local down = false
        b.MouseEnter:Connect(function() go(big() and 1.015 or 1.06, 0.15) end)
        b.MouseLeave:Connect(function() down = false; go(1, 0.2); lipTo(false) end)
        b.InputBegan:Connect(function(i)
            if isPress(i) then
                down = true
                go(big() and 0.97 or 0.88, 0.07)
                lipTo(true)
                ripple(b, i)
            end
        end)
        b.InputEnded:Connect(function(i)
            if down and isPress(i) then
                down = false
                go(1, 0.45, Enum.EasingStyle.Back)
                lipTo(false)
            end
        end)
    end

    local function pop(f)
        local s = f:FindFirstChild("FXPop") or Instance.new("UIScale")
        s.Name = "FXPop"
        s.Scale = 0.86
        s.Parent = f
        TweenService:Create(s, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    end

    local function handle(d)
        local g = d:FindFirstAncestorWhichIsA("ScreenGui")
        if not (g and (g.Name == "BalereotKey" or g.Name == "BalereotCommunity")) then return end
        if d:IsA("TextButton") then
            attach(d)
        elseif d:IsA("Frame") and d.Active and d.Parent:IsA("ScreenGui") and d.Name ~= "BalereotMain" then
            pop(d)
            d:GetPropertyChangedSignal("Visible"):Connect(function()
                if d.Visible then pop(d) end
            end)
        elseif d:IsA("UIGradient") and d.Parent:IsA("Frame") and d.Parent.Size.Y.Offset == 1.5 then
            d.Offset = Vector2.new(-0.5, 0)
            TweenService:Create(d, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                {Offset = Vector2.new(0.5, 0)}):Play()
        end
    end

    local roots = {}
    pcall(function() if gethui then table.insert(roots, gethui()) end end)
    pcall(function() table.insert(roots, game:GetService("CoreGui")) end)
    pcall(function() table.insert(roots, player:WaitForChild("PlayerGui", 5)) end)
    for _, r in ipairs(roots) do
        pcall(function() r.DescendantAdded:Connect(handle) end)
    end
end

-- =========================================================
-- AUTO JOIN DISCORD
-- Mengirim perintah ke aplikasi Discord desktop (RPC lokal) supaya
-- langsung muncul jendela "Join Server". Butuh Discord PC terbuka
-- dan executor yang mendukung request/http_request.
-- return: true kalau berhasil, false kalau gagal (pakai cadangan salin link)
-- =========================================================
local function joinDiscord(link)
    local code = tostring(link):match("discord%.gg/([%w%-_]+)") or tostring(link):match("invite/([%w%-_]+)")
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if not (code and req) then return false end
    local ok, res = pcall(req, {
        Url = "http://127.0.0.1:6463/rpc?v=1",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["Origin"] = "https://discord.com",
        },
        Body = HttpService:JSONEncode({
            cmd = "INVITE_BROWSER",
            args = {code = code},
            nonce = HttpService:GenerateGUID(false),
        }),
    })
    if ok and type(res) == "table" and (res.StatusCode == 200 or res.Success == true) then
        return true
    end
    return false
end

-- =========================================================
-- KEY SYSTEM (dicek ke server key)
-- Waktu memakai jam server Roblox (GetServerTimeNow) supaya mengubah jam PC tidak berguna.
-- =========================================================
local function nowTs()
    local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
    if ok and type(t) == "number" and t > 1600000000 then return math.floor(t) end
    return os.time()
end

local function fmtDur(sec)
    sec = math.max(0, math.floor(sec))
    if sec >= 172800 then
        return ("%d hari %d jam"):format(math.floor(sec / 86400), math.floor((sec % 86400) / 3600))
    end
    return ("%d jam %d menit"):format(math.floor(sec / 3600), math.floor((sec % 3600) / 60))
end

local function isSet(u)
    return type(u) == "string" and u ~= "" and not u:find("GANTI", 1, true)
end
local function trimS(s) return (tostring(s or ""):match("^%s*(.-)%s*$")) end

-- apakah akun ini termasuk pemilik key (UserId / username / daftar dipisah koma / *)
local function ownerMatch(field)
    field = trimS(field)
    if field == "*" then return true end
    for part in field:gmatch("[^,]+") do
        part = trimS(part)
        if part == tostring(player.UserId) or part:lower() == player.Name:lower() then return true end
    end
    return false
end

-- mode daftar: baca key.txt dari KEY_LIST_URL, format  KEY|pemilik|perm/unix  # catatan
local function checkKeyList(input)
    local url = KEY_LIST_URL .. (KEY_LIST_URL:find("?", 1, true) and "&" or "?") .. "t=" .. os.time()
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok or type(body) ~= "string" or #body == 0 then return false, "Daftar key tidak bisa dimuat" end
    local seen = false
    for line in body:gmatch("[^\r\n]+") do
        line = trimS(line)
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local main = line:match("^(.-)%s+#") or line
            local k, owner, exp = main:match("^([^|]+)|([^|]*)|(.*)$")
            if k and trimS(k):upper() == input then
                seen = true
                if ownerMatch(owner) then
                    exp = trimS(exp):lower()
                    if exp == "perm" or exp == "0" or exp == "" then return true, "OK", {expires = math.huge} end
                    local t = tonumber(exp)
                    if not t then return false, "Format masa aktif key rusak" end
                    if nowTs() >= t then return false, "Key sudah habis masa aktif" end
                    return true, "OK", {expires = t}
                end
            end
        end
    end
    if seen then return false, "Key ini bukan untuk akun kamu" end
    return false, "Key salah"
end

-- return: true, "OK", {expires = detik unix / math.huge}  |  false, pesan error
local function checkKey(input)
    input = tostring(input or ""):upper():gsub("%s", "")
    if #input < 8 or #input > 64 or input:find("[^A-Z0-9%-]") then return false, "Format key tidak valid" end
    if not isSet(CHECK_URL) then
        if isSet(KEY_LIST_URL) then return checkKeyList(input) end
        return false, "Isi CHECK_URL atau KEY_LIST_URL di script"
    end
    local url = ("%s/check?key=%s&uid=%d&name=%s&t=%d"):format(
        CHECK_URL, HttpService:UrlEncode(input), player.UserId, HttpService:UrlEncode(player.Name), os.time())
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok or type(body) ~= "string" then return false, "Server key tidak bisa dihubungi" end
    local okJ, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not okJ or type(data) ~= "table" then return false, "Respons server tidak valid" end
    if data.ok == true then
        local exp = tonumber(data.exp) or 0
        return true, "OK", {expires = (exp == 0) and math.huge or exp}
    end
    return false, tostring(data.msg or "Key salah")
end

local function savedKey()
    if readfile and isfile and isfile(KEY_FILE) then
        local ok, k = pcall(readfile, KEY_FILE)
        if ok then return k end
    end
end
local function saveKey(k)
    if writefile then pcall(writefile, KEY_FILE, k) end
end

-- =========================================================
-- TRIAL GRATIS (1 akun = 1 kali, TRIAL_HOURS jam sejak pertama dipakai)
-- Disimpan di dua file per UserId; jam dimundurkan / file rusak = dianggap habis.
-- =========================================================
local TRIAL_SECONDS = TRIAL_HOURS * 3600
local function trialPaths()
    return {TRIAL_FILE_PREFIX .. player.UserId .. ".txt", ".bc_" .. player.UserId .. ".dat"}
end
local function writeTrial(ts)
    local okAny = false
    for _, f in ipairs(trialPaths()) do
        if pcall(writefile, f, tostring(ts)) then okAny = true end
    end
    return okAny
end

-- return: "off" | "nofile" | "fresh" | "active", sisaDetik | "expired"
local function trialState()
    if not TRIAL_ENABLED then return "off" end
    if not (readfile and writefile and isfile) then return "nofile" end
    local started, found, corrupt = nil, false, false
    for _, f in ipairs(trialPaths()) do
        local okE, exists = pcall(isfile, f)
        if okE and exists then
            found = true
            local okR, data = pcall(readfile, f)
            local n = okR and tonumber(data)
            if n then
                if not started or n < started then started = n end
            else
                corrupt = true
            end
        end
    end
    if not found then return "fresh" end
    if corrupt or not started then return "expired" end
    local now = nowTs()
    if now < started - 600 then return "expired" end
    local remaining = started + TRIAL_SECONDS - now
    if remaining > 0 then
        writeTrial(started) -- pulihkan file yang hilang
        return "active", remaining
    end
    return "expired"
end

local function trialLabel(state, left)
    local span = (TRIAL_HOURS % 24 == 0) and ((TRIAL_HOURS / 24) .. " HARI") or (TRIAL_HOURS .. " JAM")
    if state == "fresh" then return "COBA GRATIS " .. span .. " (1 AKUN 1X)" end
    if state == "active" then return "LANJUT TRIAL (sisa " .. fmtDur(left) .. ")" end
    if state == "expired" then return "TRIAL GRATIS SUDAH HABIS" end
    if state == "nofile" then return "TRIAL BUTUH writefile / readfile" end
    return "TRIAL NONAKTIF"
end

-- hasil akses (dipakai panel setelah lolos)
local accessTag, accessInfo, accessExpiry = "KEY", "", nil
local function describeKey(info)
    -- user yang terdaftar di key.txt = PREMIUM (waktu tidak ditampilkan)
    accessTag, accessInfo = "PREMIUM", "Premium aktif"
    accessExpiry = (info.expires ~= math.huge) and info.expires or nil -- tetap menutup panel saat key habis
end

local function requireKey()
    local saved = savedKey()
    if saved then
        local ok, _, info = checkKey(saved)
        if ok then
            describeKey(info)
            return true
        end
    end

    -- trial otomatis: pemakai baru langsung masuk tanpa key selama TRIAL_HOURS jam
    local tState, tLeft = trialState()
    if tState == "fresh" and writeTrial(nowTs()) then
        tState, tLeft = "active", TRIAL_SECONDS
    end
    if tState == "active" then
        accessTag, accessInfo, accessExpiry = "TRIAL", "Trial gratis, sisa " .. fmtDur(tLeft), nowTs() + tLeft
        return true
    end

    local kgui = new("ScreenGui", {Name = "BalereotKey", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000}, nil)
    local mounted = pcall(function() kgui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
    if not mounted or not kgui.Parent then kgui.Parent = player:WaitForChild("PlayerGui") end

    -- ukuran desain; otomatis mengecil kalau layar pendek (HP landscape) supaya tidak terpotong
    local KW, KH = 332, 428
    local holder = new("Frame", {
        Name = "KeyHolder", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(KW, KH), BackgroundTransparency = 1,
    }, kgui)
    local fit = new("UIScale", {Scale = 1}, holder)
    local function refit()
        local vp = camera.ViewportSize
        fit.Scale = math.clamp(math.min((vp.Y - 16) / KH, (vp.X - 16) / KW), 0.45, 1)
    end
    refit()
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)

    local panel = new("Frame", {Name = "KeyPanel", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = true, Draggable = true}, holder)

    -- aura emas berdenyut di belakang kartu
    local glow = new("ImageLabel", {
        Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 64, 1, 64), BackgroundTransparency = 1, Image = "rbxassetid://1316045217",
        ImageColor3 = C.accent, ImageTransparency = 0.55, ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(10, 10, 118, 118), ZIndex = 0,
    }, panel)
    TweenService:Create(glow, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {ImageTransparency = 0.82}):Play()

    local card = new("Frame", {Name = "Card", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 1}, panel)
    round(card, 18)
    gradient(card, {{0, Color3.fromRGB(34, 25, 12)}, {0.4, Color3.fromRGB(13, 11, 15)}, {1, Color3.fromRGB(6, 5, 9)}}, 90)
    spin(gradient(stroke(card, C.white, 2.5), {{0, C.accent}, {0.25, C.cyan}, {0.5, C.white}, {0.75, C.accent2}, {1, C.accent}}), 4)
    local entry = new("UIScale", {Scale = 0.86}, card)
    TweenService:Create(entry, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()

    -- latar: logo samar + vinyet + cahaya emas atas + partikel emas melayang
    if BG_ASSET_ID then
        local img = new("ImageLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ImageTransparency = 0.8, ScaleType = Enum.ScaleType.Crop, ZIndex = 1}, card)
        img.Image = thumb(tonumber(BG_ASSET_ID) or 0, 420)
    end
    local vig = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 2}, card)
    new("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(4, 3, 6)), Rotation = 90,
        Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0.1)}),
    }, vig)
    local topGlowK = new("Frame", {Size = UDim2.new(1, 0, 0, 150), BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 2}, card)
    new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(1, 1)})}, topGlowK)
    particles(card, 18, 3)

    -- util kecil untuk panel ini
    local function spaced(s) return (s:gsub(".", "%0 "):sub(1, -2)) end
    local EDGE_L = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1)})
    local EDGE_R = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
    local function shimmerText(lbl, base, hi)
        local g = gradient(lbl, {{0, base}, {0.42, base}, {0.5, hi}, {0.58, base}, {1, base}}, 0)
        g.Offset = Vector2.new(-1, 0)
        task.spawn(function()
            while lbl.Parent do
                g.Offset = Vector2.new(-1, 0)
                local tw = TweenService:Create(g, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Offset = Vector2.new(1, 0)})
                tw:Play()
                tw.Completed:Wait()
                task.wait(1.8)
            end
        end)
    end
    local function divider(y, text)
        local midW = text and 104 or 16
        local wrap = new("Frame", {Position = UDim2.fromOffset(20, y), Size = UDim2.new(1, -40, 0, 12), BackgroundTransparency = 1, ZIndex = 5}, card)
        local l = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0.5, -(midW / 2 + 6), 0, 1), BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 5}, wrap)
        new("UIGradient", {Transparency = EDGE_L}, l)
        local r = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0.5, -(midW / 2 + 6), 0, 1), BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 5}, wrap)
        new("UIGradient", {Transparency = EDGE_R}, r)
        if text then
            new("TextLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(midW, 12), BackgroundTransparency = 1, Text = spaced(text), Font = Enum.Font.GothamBold, TextSize = 8, TextColor3 = C.accent, ZIndex = 5}, wrap)
        else
            local d = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = C.white, Rotation = 45, BorderSizePixel = 0, ZIndex = 5}, wrap)
            gradient(d, {{0, C.accent2}, {1, C.accent}}, 90)
            TweenService:Create(d, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Size = UDim2.fromOffset(10, 10)}):Play()
        end
    end

    -- emblem: berlian emas berputar + cincin denyut
    local ring = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 1, Rotation = 45, ZIndex = 4}, card)
    round(ring, 12)
    local ringStroke = stroke(ring, C.accent, 1.5, 0.2)
    local ringInfo = TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1)
    TweenService:Create(ring, ringInfo, {Size = UDim2.fromOffset(92, 92)}):Play()
    TweenService:Create(ringStroke, ringInfo, {Transparency = 1}):Play()
    local emblem = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = C.white, Rotation = 45, BorderSizePixel = 0, ZIndex = 5}, card)
    round(emblem, 11)
    gradient(emblem, {{0, Color3.fromRGB(255, 240, 190)}, {1, Color3.fromRGB(190, 128, 34)}}, 90)
    spin(gradient(stroke(emblem, C.white, 1.8), {{0, C.accent2}, {0.5, C.cyan}, {1, C.accent2}}), 3)
    new("TextLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Rotation = -45, Text = "BC", Font = Enum.Font.GothamBlack, TextSize = 17, TextColor3 = C.ink, ZIndex = 6}, emblem)

    local titleLbl = new("TextLabel", {Position = UDim2.fromOffset(10, 76), Size = UDim2.new(1, -20, 0, 24), BackgroundTransparency = 1, Text = spaced("BALEREOT"), Font = Enum.Font.GothamBlack, TextSize = 21, TextColor3 = C.white, ZIndex = 5}, card)
    shimmerText(titleLbl, Color3.fromRGB(236, 178, 62), Color3.fromRGB(255, 252, 238))
    new("TextLabel", {Position = UDim2.fromOffset(10, 100), Size = UDim2.new(1, -20, 0, 12), BackgroundTransparency = 1, Text = spaced("COMMUNITY"), Font = Enum.Font.GothamMedium, TextSize = 9, TextColor3 = C.sub, ZIndex = 5}, card)
    divider(116)
    new("TextLabel", {
        Position = UDim2.fromOffset(24, 130), Size = UDim2.new(1, -48, 0, 26), BackgroundTransparency = 1, TextWrapped = true,
        Text = (tState == "expired") and "Trial gratis sudah habis. Masukkan key untuk lanjut" or "Masukkan key premium, atau coba gratis dulu",
        Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.sub, ZIndex = 5,
    }, card)

    -- kolom key
    local inputFrame = new("Frame", {Position = UDim2.fromOffset(20, 162), Size = UDim2.new(1, -40, 0, 42), BackgroundColor3 = C.white, BackgroundTransparency = 0.05, BorderSizePixel = 0, ZIndex = 5}, card)
    round(inputFrame, 11)
    gradient(inputFrame, {{0, Color3.fromRGB(20, 17, 24)}, {1, Color3.fromRGB(34, 29, 40)}}, 90)
    local inStroke = stroke(inputFrame, C.stroke, 1.4, 0.15)
    new("TextLabel", {Size = UDim2.fromOffset(46, 42), BackgroundTransparency = 1, Text = "KEY", Font = Enum.Font.GothamBlack, TextSize = 10, TextColor3 = C.accent, ZIndex = 6}, inputFrame)
    local sep = new("Frame", {Position = UDim2.fromOffset(46, 9), Size = UDim2.new(0, 1, 1, -18), BackgroundColor3 = C.stroke, BorderSizePixel = 0, ZIndex = 6}, inputFrame)
    local keyBox = new("TextBox", {
        Position = UDim2.fromOffset(56, 0), Size = UDim2.new(1, -64, 1, 0), BackgroundTransparency = 1, Text = "",
        PlaceholderText = "BLR-XXXX-XXXX-XXXX-XXXX", TextColor3 = C.text, PlaceholderColor3 = C.dim,
        Font = Enum.Font.Code, TextSize = 13, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
    }, inputFrame)
    keyBox.Focused:Connect(function()
        TweenService:Create(inStroke, TweenInfo.new(0.2), {Color = C.accent, Transparency = 0, Thickness = 1.9}):Play()
        TweenService:Create(sep, TweenInfo.new(0.2), {BackgroundColor3 = C.accent}):Play()
    end)
    keyBox.FocusLost:Connect(function()
        TweenService:Create(inStroke, TweenInfo.new(0.25), {Color = C.stroke, Transparency = 0.15, Thickness = 1.4}):Play()
        TweenService:Create(sep, TweenInfo.new(0.25), {BackgroundColor3 = C.stroke}):Play()
    end)

    local status = new("TextLabel", {Position = UDim2.fromOffset(20, 208), Size = UDim2.new(1, -40, 0, 14), BackgroundTransparency = 1, Text = "", Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = C.sub, ZIndex = 5}, card)
    local function setStatus(text, color)
        status.Text = text
        status.TextColor3 = color or C.sub
        status.TextTransparency = 1
        TweenService:Create(status, TweenInfo.new(0.25), {TextTransparency = 0}):Play()
    end
    setStatus("Akun: " .. player.Name .. "  |  ID " .. player.UserId, C.dim)

    -- tombol premium 3D: permukaan gradasi + sisi tebal + kilau menyapu
    local STYLES = {
        gold = {top = Color3.fromRGB(255, 243, 200), bot = Color3.fromRGB(226, 168, 56), depth = Color3.fromRGB(128, 84, 18), text = C.ink, line = Color3.fromRGB(255, 246, 215), sweep = true},
        green = {top = Color3.fromRGB(104, 222, 160), bot = Color3.fromRGB(28, 128, 86), depth = Color3.fromRGB(14, 72, 48), text = C.white, line = Color3.fromRGB(200, 255, 225), sweep = true},
        glass = {top = Color3.fromRGB(54, 46, 62), bot = Color3.fromRGB(26, 22, 32), depth = Color3.fromRGB(10, 8, 13), text = C.accent2, line = C.stroke, sweep = false},
        off = {top = Color3.fromRGB(38, 34, 42), bot = Color3.fromRGB(24, 21, 27), depth = Color3.fromRGB(12, 10, 14), text = C.dim, line = Color3.fromRGB(60, 54, 66), sweep = false},
    }
    local rnd = Random.new()
    local function premiumBtn(name, text, y, h, styleName, textSize)
        local s = STYLES[styleName]
        local LIP = 3
        local b = new("TextButton", {Name = "Btn3D" .. name, Position = UDim2.fromOffset(20, y), Size = UDim2.new(1, -40, 0, h), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 6}, card)
        round(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = s.depth, BorderSizePixel = 0, ZIndex = 6}, b), 11)
        local face = new("Frame", {Name = "Face", Size = UDim2.new(1, 0, 1, -LIP), BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 7}, b)
        round(face, 11)
        gradient(face, {{0, s.top}, {1, s.bot}}, 90)
        local fs = stroke(face, s.line, 1.2, (styleName == "glass" or styleName == "off") and 0.3 or 0.5)
        new("Frame", {Position = UDim2.fromOffset(10, 1), Size = UDim2.new(1, -20, 0, 1), BackgroundColor3 = C.white, BackgroundTransparency = (styleName == "off") and 0.85 or 0.4, BorderSizePixel = 0, ZIndex = 8}, face)
        if s.sweep then
            local sheen = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 8}, face)
            round(sheen, 11)
            local sg = new("UIGradient", {
                Rotation = 20,
                Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1)}),
            }, sheen)
            task.spawn(function()
                task.wait(rnd:NextNumber(0, 1.5))
                while sheen.Parent do
                    sg.Offset = Vector2.new(-1, 0)
                    local tw = TweenService:Create(sg, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Offset = Vector2.new(1, 0)})
                    tw:Play()
                    tw.Completed:Wait()
                    task.wait(2.2 + rnd:NextNumber(0, 1))
                end
            end)
        end
        local lbl = new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text, Font = Enum.Font.GothamBold, TextSize = textSize or 12, TextColor3 = s.text, ZIndex = 9}, face)
        local function press(on)
            TweenService:Create(face, TweenInfo.new(0.07, Enum.EasingStyle.Quad), {Position = UDim2.fromOffset(0, on and (LIP - 1) or 0)}):Play()
        end
        b.MouseButton1Down:Connect(function() press(true) end)
        b.MouseButton1Up:Connect(function() press(false) end)
        b.MouseEnter:Connect(function() TweenService:Create(fs, TweenInfo.new(0.15), {Transparency = 0.05}):Play() end)
        b.MouseLeave:Connect(function()
            press(false)
            TweenService:Create(fs, TweenInfo.new(0.2), {Transparency = (styleName == "glass" or styleName == "off") and 0.3 or 0.5}):Play()
        end)
        return b, lbl
    end

    local trialUsable = (tState == "fresh" or tState == "active")
    local checkBtn, checkLbl = premiumBtn("Check", "CHECK KEY", 228, 40, "gold", 14)
    local trialBtn, trialLbl = premiumBtn("Trial", trialLabel(tState, tLeft), 274, 34, trialUsable and "green" or "off", 11)
    local getBtn = premiumBtn("Get", "GET KEY / BELI DI DISCORD", 314, 34, "glass", 11)

    -- paket harga: 3 kartu, paket pertama di PRICES disorot "BEST"
    divider(356, "PAKET PREMIUM")
    local row = new("Frame", {Position = UDim2.fromOffset(20, 376), Size = UDim2.new(1, -40, 0, 44), BackgroundTransparency = 1, ZIndex = 5}, card)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, row)
    local np = #PRICES
    for i, p in ipairs(PRICES) do
        local best = (i == 1)
        local c = new("Frame", {LayoutOrder = i, Size = UDim2.new(1 / np, -(8 * (np - 1)) / np, 1, 0), BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 5}, row)
        round(c, 10)
        gradient(c, best and {{0, Color3.fromRGB(88, 64, 22)}, {1, Color3.fromRGB(30, 22, 10)}} or {{0, Color3.fromRGB(42, 36, 48)}, {1, Color3.fromRGB(20, 17, 24)}}, 90)
        local cst = stroke(c, best and C.white or C.stroke, best and 1.6 or 1, best and 0 or 0.4)
        new("TextLabel", {Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 12), BackgroundTransparency = 1, Text = p[1], Font = Enum.Font.GothamMedium, TextSize = 9, TextColor3 = best and C.accent2 or C.sub, ZIndex = 6}, c)
        new("TextLabel", {Position = UDim2.fromOffset(0, 23), Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = p[2], Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = best and C.white or C.yellow, ZIndex = 6}, c)
        if best then
            spin(gradient(cst, {{0, C.accent}, {0.5, C.white}, {1, C.accent}}), 3)
            local rib = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.fromOffset(46, 13), BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 8}, c)
            round(rib, 6)
            gradient(rib, {{0, C.accent2}, {1, C.accent}}, 90)
            new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "BEST", Font = Enum.Font.GothamBlack, TextSize = 8, TextColor3 = C.ink, ZIndex = 9}, rib)
        end
    end

    -- efek: getar saat salah, kilat saat benar
    local flashFrame = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 30}, card)
    round(flashFrame, 18)
    local function flash(color, amount)
        flashFrame.BackgroundColor3 = color
        flashFrame.BackgroundTransparency = amount
        TweenService:Create(flashFrame, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
    end
    local function shake()
        flash(C.red, 0.82)
        task.spawn(function()
            for i = 1, 4 do
                local dx = ((i % 2 == 0) and 1 or -1) * (9 - i * 1.6)
                TweenService:Create(card, TweenInfo.new(0.05), {Position = UDim2.fromOffset(dx, 0)}):Play()
                task.wait(0.05)
            end
            TweenService:Create(card, TweenInfo.new(0.07), {Position = UDim2.new()}):Play()
        end)
    end

    local result, attempts, busy = nil, 0, false
    local function submit()
        if busy or result ~= nil then return end
        busy = true
        checkLbl.Text = "MEMERIKSA..."
        setStatus("Menghubungi server key...", C.sub)
        local okc, ok, msg, info = pcall(checkKey, keyBox.Text)
        if not okc then ok, msg = false, "Error: " .. tostring(ok):sub(1, 60) end
        checkLbl.Text = "CHECK KEY"
        if ok then
            saveKey((keyBox.Text:upper():gsub("%s", "")))
            describeKey(info)
            setStatus("Key valid! Memuat panel...", C.green)
            flash(C.accent, 0.55)
            task.wait(0.7)
            result = true
        else
            attempts += 1
            setStatus(msg .. " (" .. attempts .. "/5)", C.red)
            shake()
            if attempts >= 5 then
                task.wait(1)
                result = false
            end
        end
        busy = false
    end
    checkBtn.MouseButton1Click:Connect(function() task.spawn(submit) end)
    keyBox.FocusLost:Connect(function(enter) if enter then task.spawn(submit) end end)

    -- Trial gratis
    trialBtn.MouseButton1Click:Connect(function()
        if result ~= nil then return end
        local st, left = trialState()
        if st == "fresh" then
            if not writeTrial(nowTs()) then
                setStatus("Gagal menyimpan data trial", C.red)
                return
            end
            st, left = "active", TRIAL_SECONDS
        end
        if st == "active" then
            accessTag, accessInfo, accessExpiry = "TRIAL", "Trial gratis, sisa " .. fmtDur(left), nowTs() + left
            setStatus("Trial dimulai! Memuat panel...", C.green)
            flash(C.green, 0.65)
            task.wait(0.5)
            result = true
        else
            setStatus(trialLabel(st, left), C.red)
            trialLbl.Text = trialLabel(st, left)
            shake()
        end
    end)

    -- GET KEY: otomatis buka Discord, cadangan salin link ke clipboard
    getBtn.MouseButton1Click:Connect(function()
        if setclipboard then pcall(setclipboard, GET_KEY_LINK) end
        setStatus("Membuka Discord...", C.sub)
        task.spawn(function()
            if joinDiscord(GET_KEY_LINK) then
                setStatus("Discord terbuka, klik Join Server", C.green)
            else
                setStatus(setclipboard and "Link disalin, tempel di browser" or GET_KEY_LINK, C.yellow)
            end
        end)
    end)

    repeat task.wait(0.1) until result ~= nil
    kgui:Destroy()
    return result
end

if not requireKey() then return end


-- =========================================================
-- IMPORT FILE
-- Scan .rbxm / .rbxmx / .rbxl / .rbxlx dari workspace executor, lalu import ke Folder baru di Workspace.
-- Mode utama : GetObjects / LoadLocalAsset
-- Mode cadangan "Rebuild": membaca isi file sendiri (struktur, part, properti, script)
-- =========================================================
local function buildImporter(host, ctx)
    local lp = ctx.player
    local gui = ctx.gui
    local TC = ctx.colors
    local TOP = ctx.top
    local accessInfo = ctx.accessInfo or ""

    local SCAN_FOLDERS = {ASSET_FOLDER, ""}

    local ICON = {
        PACKAGE = "rbxassetid://128864012857079",
        FOLDER = "rbxassetid://88761476236687",
        SETTINGS = "rbxassetid://11956055886",
        FILE = "rbxassetid://17109896197",
        GAMEPAD = "rbxassetid://115836418226834",
        REFRESH = "rbxassetid://13492317101",
        CHECK = "rbxassetid://18349889388",
        ALERT = "rbxassetid://7634887649",
        LOGO = "rbxassetid://133871331523241",
    }

    -- palet disamakan dengan toolbox
    local C = {
        surface = TC.panel, surface2 = TC.input, line = TC.stroke,
        a1 = Color3.fromRGB(255, 232, 170), a2 = TC.cyan,
        text = TC.text, muted = TC.sub, ink = TC.ink or Color3.fromRGB(28, 18, 4),
        ok = TC.green, err = TC.red,
    }
    local WHITE = Color3.new(1, 1, 1)

    local settings = {anchor = true, force = false}

    -- ============ Helper UI ============
    local function new(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props or {}) do o[k] = v end
        o.Parent = parent
        return o
    end
    local function corner(p, r) return new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, p) end
    local function stroke(p, col, tr, th)
        return new("UIStroke", {
            Color = col or C.line, Transparency = tr or 0.5, Thickness = th or 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, p)
    end
    local function gradient(p, c0, c1, rot)
        return new("UIGradient", {Color = ColorSequence.new(c0, c1), Rotation = rot or 0}, p)
    end
    local function gradient3(p, c0, c1, c2, rot)
        return new("UIGradient", {Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, c0), ColorSequenceKeypoint.new(0.5, c1), ColorSequenceKeypoint.new(1, c2),
        }), Rotation = rot or 0}, p)
    end
    local function label(p, text, size, pos, sz, col, font)
        return new("TextLabel", {
            BackgroundTransparency = 1, Text = text, TextSize = size or 12,
            Font = font or Enum.Font.GothamBold, TextColor3 = col or C.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = pos or UDim2.new(), Size = sz or UDim2.new(1, 0, 0, 20),
        }, p)
    end
    local function tween(o, t, props)
        TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
    end
    local function spin(g, t)
        task.spawn(function()
            while g.Parent do
                g.Rotation = 0
                TweenService:Create(g, TweenInfo.new(t, Enum.EasingStyle.Linear), {Rotation = 360}):Play()
                task.wait(t)
            end
        end)
    end

    -- Tombol 3D: sisi bawah (depth) + permukaan yang turun saat ditekan.
    local DEPTH_COL = Color3.fromRGB(150, 100, 26)
    local function gradButton(parent, text, pos, size, textSize)
        local LIP = 3
        local b = new("TextButton", {
            Name = "Btn3D", Position = pos, Size = size, BackgroundTransparency = 1, Text = "",
            AutoButtonColor = false, BorderSizePixel = 0,
        }, parent)
        local depth = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = DEPTH_COL, BorderSizePixel = 0}, b)
        corner(depth, 9)
        local face = new("Frame", {Size = UDim2.new(1, 0, 1, -LIP), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2}, b)
        corner(face, 9)
        gradient(face, Color3.fromRGB(255, 242, 196), Color3.fromRGB(230, 176, 66), 90)
        local st = stroke(face, WHITE, 0.45, 1)
        new("Frame", {
            Size = UDim2.new(1, -14, 0, 1), Position = UDim2.fromOffset(7, 1), BackgroundColor3 = WHITE,
            BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 3,
        }, face)
        local lb = new("TextLabel", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text,
            Font = Enum.Font.GothamBold, TextSize = textSize or 11, TextColor3 = C.ink, ZIndex = 4,
        }, face)
        local function press(on)
            tween(face, 0.07, {Position = UDim2.fromOffset(0, on and (LIP - 1) or 0)})
        end
        b.MouseButton1Down:Connect(function() press(true) end)
        b.MouseButton1Up:Connect(function() press(false) end)
        b.MouseEnter:Connect(function() tween(st, 0.15, {Transparency = 0.1}) end)
        b.MouseLeave:Connect(function() press(false); tween(st, 0.15, {Transparency = 0.45}) end)
        return b, lb
    end

    -- ============ Notifikasi ============
    local function notify(title, msg, isErr)
        local col = isErr and C.err or C.ok
        local f = new("Frame", {
            Size = UDim2.fromOffset(320, 60), AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, -80), BackgroundColor3 = C.surface, BorderSizePixel = 0, ZIndex = 60,
        }, gui)
        corner(f, 14)
        stroke(f, col, 0.3, 1.2)
        gradient(f, C.surface2, C.surface, 90)
        local bar = new("Frame", {Size = UDim2.new(0, 3, 1, -20), Position = UDim2.fromOffset(9, 10), BackgroundColor3 = col, BorderSizePixel = 0}, f)
        corner(bar, 2)
        new("ImageLabel", {
            Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(22, 21), BackgroundTransparency = 1,
            Image = isErr and ICON.ALERT or ICON.CHECK, ImageColor3 = col,
        }, f)
        label(f, title, 12, UDim2.fromOffset(50, 8), UDim2.new(1, -60, 0, 16))
        local m = label(f, msg, 10, UDim2.fromOffset(50, 25), UDim2.new(1, -60, 0, 32), C.muted, Enum.Font.Gotham)
        m.TextWrapped = true; m.TextYAlignment = Enum.TextYAlignment.Top
        tween(f, 0.4, {Position = UDim2.new(0.5, 0, 0, 14)})
        task.delay(4.5, function()
            tween(f, 0.3, {Position = UDim2.new(0.5, 0, 0, -80)})
            task.wait(0.35)
            f:Destroy()
        end)
    end

    -- ============ Tab (Library / Scripts / Settings) ============
    local tabs, views = {}, {}
    local function showTab(name)
        for n, v in pairs(views) do v.Visible = (n == name) end
        for n, t in pairs(tabs) do
            local on = (n == name)
            t.BackgroundColor3 = on and TC.accent or TC.input
            t.TextColor3 = on and TC.ink or TC.sub
        end
    end
    local tabRow = new("Frame", {Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, TOP), BackgroundTransparency = 1}, host)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, tabRow)
    for i, name in ipairs({"Library", "Scripts", "Settings"}) do
        local b = new("TextButton", {
            LayoutOrder = i, Size = UDim2.new(1 / 3, -3, 1, 0), BackgroundColor3 = TC.input, Text = name,
            TextColor3 = TC.sub, TextSize = 10, Font = Enum.Font.GothamBold, BorderSizePixel = 0, AutoButtonColor = false,
        }, tabRow)
        corner(b, 6)
        tabs[name] = b
        b.MouseButton1Click:Connect(function() showTab(name) end)
    end

    -- ============ Statistik ============
    local counts = {files = 0, imported = 0, scripts = 0}
    local statsLbl = label(host, "", 9, UDim2.fromOffset(10, TOP + 30), UDim2.new(1, -20, 0, 12), C.muted, Enum.Font.GothamMedium)
    local function renderStats()
        statsLbl.Text = ("FILE %d   |   IMPORT %d   |   SCRIPT %d"):format(counts.files, counts.imported, counts.scripts)
    end
    renderStats()
    local function chipProxy(key)
        return setmetatable({}, {__newindex = function(_, k, v)
            if k == "Text" then
                counts[key] = tonumber(v) or 0
                renderStats()
            end
        end})
    end
    local statFiles, statImported, statScripts = chipProxy("files"), chipProxy("imported"), chipProxy("scripts")
    local importedTotal, scriptTotal = 0, 0

    -- ============ Footer (status + progress) ============
    local execName = "Executor"
    pcall(function()
        if identifyexecutor then execName = tostring((identifyexecutor())) end
    end)
    local readyText = "Siap  |  " .. execName .. ((accessInfo ~= "") and ("  |  " .. accessInfo) or "")
    local statusLbl = label(host, readyText, 10, UDim2.new(0, 10, 1, -34), UDim2.new(1, -90, 0, 14), C.muted, Enum.Font.GothamMedium)
    statusLbl.TextTruncate = Enum.TextTruncate.AtEnd
    local pctLbl = label(host, "", 10, UDim2.new(1, -72, 1, -34), UDim2.fromOffset(62, 14), C.a1)
    pctLbl.TextXAlignment = Enum.TextXAlignment.Right
    local progTrack = new("Frame", {Size = UDim2.new(1, -20, 0, 4), Position = UDim2.new(0, 10, 1, -16), BackgroundColor3 = C.surface2, BorderSizePixel = 0}, host)
    corner(progTrack, 2)
    local progFill = new("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0}, progTrack)
    corner(progFill, 2)
    gradient(progFill, C.a1, C.a2, 0)

    local function setProg(frac, text)
        if text then statusLbl.Text = text end
        frac = math.clamp(frac or 0, 0, 1)
        tween(progFill, 0.15, {Size = UDim2.new(frac, 0, 1, 0)})
        pctLbl.Text = (frac > 0) and (math.floor(frac * 100) .. "%") or ""
    end
    local function resetProg()
        setProg(0, readyText)
    end

    -- ============ Body ============
    local BODY_Y = TOP + 46
    local function makeView(name)
        local v = new("Frame", {
            Size = UDim2.new(1, -16, 1, -(BODY_Y + 42)), Position = UDim2.fromOffset(8, BODY_Y),
            BackgroundTransparency = 1, Visible = false,
        }, host)
        views[name] = v
        return v
    end

    -- ===== Library =====
    local lib = makeView("Library")
    local rows, filterKind, searchText = {}, "ALL", ""

    local searchBox = new("TextBox", {
        Size = UDim2.new(1, -(150 + 30 + 12), 0, 30), Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = C.surface2, BackgroundTransparency = 0.1, BorderSizePixel = 0,
        Text = "", PlaceholderText = "Cari asset...", PlaceholderColor3 = C.muted, TextColor3 = C.text,
        Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
    }, lib)
    corner(searchBox, 15); stroke(searchBox, C.line, 0.4)
    new("UIPadding", {PaddingLeft = UDim.new(0, 12)}, searchBox)

    local seg = new("Frame", {Size = UDim2.fromOffset(150, 30), Position = UDim2.new(1, -(150 + 30 + 6), 0, 0), BackgroundColor3 = C.surface2, BackgroundTransparency = 0.1, BorderSizePixel = 0}, lib)
    corner(seg, 15); stroke(seg, C.line, 0.4)
    local segBtns = {}
    for i, nmk in ipairs({"ALL", "MODEL", "PLACE"}) do
        local b = new("TextButton", {
            Size = UDim2.fromOffset(46, 24), Position = UDim2.fromOffset(3 + (i - 1) * 48, 3),
            BackgroundColor3 = TC.accent, BackgroundTransparency = (i == 1) and 0 or 1, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
        }, seg)
        corner(b, 12)
        local lb = new("TextLabel", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = nmk, Font = Enum.Font.GothamBold,
            TextSize = 9, TextColor3 = (i == 1) and C.ink or C.text,
        }, b)
        segBtns[nmk] = {btn = b, lbl = lb}
    end

    local rescan = new("TextButton", {
        Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -30, 0, 0), BackgroundColor3 = WHITE,
        Text = "", AutoButtonColor = false, BorderSizePixel = 0,
    }, lib)
    corner(rescan, 15)
    gradient(rescan, Color3.fromRGB(255, 242, 196), Color3.fromRGB(230, 176, 66), 90)
    local rescanIcon = new("ImageLabel", {
        Size = UDim2.fromOffset(16, 16), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1, Image = ICON.REFRESH, ImageColor3 = C.ink,
    }, rescan)

    local emptyLbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 1, -38), Position = UDim2.fromOffset(0, 38), BackgroundTransparency = 1,
        Text = "", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.muted, TextWrapped = true,
    }, lib)

    local listFrame = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -38), Position = UDim2.fromOffset(0, 38), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.a1,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
    }, lib)
    new("UIGridLayout", {
        CellSize = UDim2.new(0.5, -4, 0, 92), CellPadding = UDim2.fromOffset(8, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, listFrame)

    local function applyFilter()
        local vis = 0
        for _, r in ipairs(rows) do
            local okK = (filterKind == "ALL") or (r.kind == filterKind)
            local okS = (searchText == "") or (r.name:lower():find(searchText, 1, true) ~= nil)
            r.frame.Visible = okK and okS
            if okK and okS then vis += 1 end
        end
        emptyLbl.Visible = (vis == 0)
        if #rows == 0 then
            emptyLbl.Text = "Belum ada file.\nLetakkan .rbxm / .rbxl di workspace/" .. ASSET_FOLDER
        else
            emptyLbl.Text = "Tidak ada hasil."
        end
    end
    for nmk, s in pairs(segBtns) do
        s.btn.MouseButton1Click:Connect(function()
            filterKind = nmk
            for n2, s2 in pairs(segBtns) do
                local on = (n2 == nmk)
                tween(s2.btn, 0.2, {BackgroundTransparency = on and 0 or 1})
                s2.lbl.TextColor3 = on and C.ink or C.text
            end
            applyFilter()
        end)
    end
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchText = searchBox.Text:lower()
        applyFilter()
    end)

    -- ===== Scripts =====
    local scv = makeView("Scripts")
    local scList = new("ScrollingFrame", {
        Size = UDim2.new(0, 118, 1, 0), BackgroundColor3 = C.surface, BackgroundTransparency = 0.2, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.a1,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
    }, scv)
    corner(scList, 10); stroke(scList, C.line, 0.4)
    new("UIPadding", {PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5)}, scList)
    new("UIListLayout", {Padding = UDim.new(0, 4)}, scList)

    local codeBox = new("TextBox", {
        Size = UDim2.new(1, -124, 1, -36), Position = UDim2.fromOffset(124, 0), BackgroundColor3 = Color3.fromRGB(11, 10, 9), BackgroundTransparency = 0.1, BorderSizePixel = 0,
        Text = "Import file dulu, lalu pilih script di kiri.", TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        ClearTextOnFocus = false, TextEditable = false, MultiLine = true, TextWrapped = false, ClipsDescendants = true,
    }, scv)
    corner(codeBox, 10); stroke(codeBox, C.line, 0.4)
    new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6)}, codeBox)
    local pathLbl = label(scv, "", 9, UDim2.new(0, 124, 1, -30), UDim2.new(1, -124 - 90, 0, 28), C.muted, Enum.Font.Gotham)
    pathLbl.TextTruncate = Enum.TextTruncate.AtEnd
    local copyBtn = gradButton(scv, "COPY", UDim2.new(1, -84, 1, -31), UDim2.fromOffset(84, 28))

    local currentSrc = ""
    local function showSource(path, src)
        currentSrc = src
        pathLbl.Text = path
        if #src > 20000 then
            codeBox.Text = src:sub(1, 20000) .. "\n-- [dipotong, pakai COPY untuk isi penuh]"
        else
            codeBox.Text = src
        end
    end
    copyBtn.MouseButton1Click:Connect(function()
        if setclipboard and currentSrc ~= "" then
            pcall(setclipboard, currentSrc)
            notify("Tersalin", "Isi script disalin ke clipboard.", false)
        else
            notify("Gagal", "Pilih script dulu / executor tanpa setclipboard.", true)
        end
    end)

    local function registerScript(path, class, src)
        scriptTotal += 1
        statScripts.Text = tostring(scriptTotal)
        local b = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = C.surface2, Text = " [" .. class:sub(1, 1) .. "] " .. path,
            Font = Enum.Font.GothamMedium, TextSize = 9, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = false, BorderSizePixel = 0,
        }, scList)
        corner(b, 7)
        b.MouseEnter:Connect(function() tween(b, 0.12, {BackgroundColor3 = C.line}) end)
        b.MouseLeave:Connect(function() tween(b, 0.12, {BackgroundColor3 = C.surface2}) end)
        b.MouseButton1Click:Connect(function() showSource(path, src) end)
    end

    -- ===== Settings =====
    local sv = makeView("Settings")
    local card1 = new("Frame", {Size = UDim2.new(1, 0, 0, 112), BackgroundColor3 = C.surface, BackgroundTransparency = 0.2, BorderSizePixel = 0}, sv)
    corner(card1, 12); stroke(card1, C.line, 0.4)

    local function toggleRow(y, title, desc, key)
        label(card1, title, 12, UDim2.fromOffset(14, y), UDim2.new(1, -84, 0, 16))
        local d = label(card1, desc, 9, UDim2.fromOffset(14, y + 17), UDim2.new(1, -84, 0, 26), C.muted, Enum.Font.Gotham)
        d.TextWrapped = true; d.TextYAlignment = Enum.TextYAlignment.Top
        local track = new("TextButton", {
            Size = UDim2.fromOffset(44, 22), Position = UDim2.new(1, -58, 0, y + 8), BackgroundColor3 = C.surface2,
            Text = "", AutoButtonColor = false, BorderSizePixel = 0,
        }, card1)
        corner(track, 11); stroke(track, C.line, 0.4)
        local g = gradient(track, C.a1, C.a2, 0)
        local knob = new("Frame", {Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = WHITE, BorderSizePixel = 0}, track)
        corner(knob, 8)
        local function render(v, animate)
            g.Enabled = v
            local pos = v and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)
            if animate then
                tween(knob, 0.15, {Position = pos})
                tween(track, 0.15, {BackgroundColor3 = v and WHITE or C.surface2})
            else
                knob.Position = pos
                track.BackgroundColor3 = v and WHITE or C.surface2
            end
        end
        render(settings[key], false)
        track.MouseButton1Click:Connect(function()
            settings[key] = not settings[key]
            render(settings[key], true)
        end)
    end
    toggleRow(8, "Anchor semua part", "Mode Rebuild: part dikunci supaya tidak jatuh / berantakan.", "anchor")
    toggleRow(58, "Paksa mode Rebuild", "Lewati GetObjects, selalu baca isi file sendiri.", "force")

    local card2 = new("Frame", {Size = UDim2.new(1, 0, 0, 96), Position = UDim2.fromOffset(0, 120), BackgroundColor3 = C.surface, BackgroundTransparency = 0.2, BorderSizePixel = 0}, sv)
    corner(card2, 12); stroke(card2, C.line, 0.4)
    label(card2, "BALEREOT COMMUNITY", 12, UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 16))
    local ab = label(card2, "Import file .rbxm / .rbxl dari workspace/" .. ASSET_FOLDER .. " ke Workspace (lokal / client). RightShift untuk buka / tutup panel.", 9, UDim2.fromOffset(14, 29), UDim2.new(1, -28, 0, 36), C.muted, Enum.Font.Gotham)
    ab.TextWrapped = true; ab.TextYAlignment = Enum.TextYAlignment.Top
    local unload = gradButton(card2, "UNLOAD PANEL", UDim2.new(1, -124, 1, -36), UDim2.fromOffset(110, 28))
    unload.MouseButton1Click:Connect(function() gui:Destroy() end)

    -- ============ Logic ============
    -- ============ Logic ============
    local SCRIPT_CLASSES = {Script = true, LocalScript = true, ModuleScript = true}
    local SKIP_CLASSES = {Terrain = true, Camera = true}

    local spack, sunpack = string.pack, string.unpack
    local byte = string.byte

    -- ---------- LZ4 / ZSTD ----------
    local function lz4block(src)
        local out, o, i, n = {}, 0, 1, #src
        while i <= n do
            local token = byte(src, i); i += 1
            local lit = bit32.rshift(token, 4)
            if lit == 15 then
                local b
                repeat b = byte(src, i); i += 1; lit += b until b ~= 255
            end
            for k = 0, lit - 1 do out[o + k + 1] = byte(src, i + k) end
            o += lit; i += lit
            if i > n then break end
            local off = byte(src, i) + byte(src, i + 1) * 256; i += 2
            local ml = bit32.band(token, 15)
            if ml == 15 then
                local b
                repeat b = byte(src, i); i += 1; ml += b until b ~= 255
            end
            ml += 4
            local start = o - off
            for k = 1, ml do out[o + k] = out[start + k] end
            o += ml
        end
        local parts = {}
        for st = 1, o, 4096 do
            parts[#parts + 1] = string.char(table.unpack(out, st, math.min(st + 4095, o)))
        end
        return table.concat(parts)
    end

    local function decompressChunk(comp, raw)
        if comp == 0 then return raw end
        if raw:sub(1, 4) == "\40\181\47\253" then
            assert(zstddecompress, "executor tidak support zstddecompress")
            return zstddecompress(raw)
        end
        return lz4block(raw)
    end

    -- ---------- Pembaca array biner (interleaved) ----------
    local function readRaw(data, pos, n)
        local res = table.create(n)
        for i = 0, n - 1 do
            res[i + 1] = byte(data, pos + i) * 16777216 + byte(data, pos + n + i) * 65536
                + byte(data, pos + 2 * n + i) * 256 + byte(data, pos + 3 * n + i)
        end
        return res, pos + n * 4
    end
    local function readInts(data, pos, n)
        local res, np = readRaw(data, pos, n)
        for i = 1, n do
            local x = res[i]
            res[i] = (x % 2 == 0) and (x / 2) or (-(x + 1) / 2)
        end
        return res, np
    end
    local function readRefs(data, pos, n)
        local ints, np = readInts(data, pos, n)
        local acc = 0
        for i = 1, n do acc += ints[i]; ints[i] = acc end
        return ints, np
    end
    local function decF(x)
        local bits = bit32.rshift(x, 1) + (x % 2) * 2147483648
        return (sunpack(">f", spack(">I4", bits)))
    end
    local function readFloats(data, pos, n)
        local res, np = readRaw(data, pos, n)
        for i = 1, n do res[i] = decF(res[i]) end
        return res, np
    end

    -- tabel rotasi CFrame (id -> R00,R01,R02,R10,R11,R12,R20,R21,R22)
    local ROT = {
        [0x02] = {1,0,0, 0,1,0, 0,0,1},   [0x03] = {1,0,0, 0,0,-1, 0,1,0},
        [0x05] = {1,0,0, 0,-1,0, 0,0,-1}, [0x06] = {1,0,0, 0,0,1, 0,-1,0},
        [0x07] = {0,1,0, 1,0,0, 0,0,-1},  [0x09] = {0,0,1, 1,0,0, 0,1,0},
        [0x0A] = {0,-1,0, 1,0,0, 0,0,1},  [0x0C] = {0,0,-1, 1,0,0, 0,-1,0},
        [0x0D] = {0,1,0, 0,0,1, 1,0,0},   [0x0E] = {0,0,-1, 0,1,0, 1,0,0},
        [0x10] = {0,-1,0, 0,0,-1, 1,0,0}, [0x11] = {0,0,1, 0,-1,0, 1,0,0},
        [0x14] = {-1,0,0, 0,1,0, 0,0,-1}, [0x15] = {-1,0,0, 0,0,1, 0,1,0},
        [0x17] = {-1,0,0, 0,-1,0, 0,0,1}, [0x18] = {-1,0,0, 0,0,-1, 0,-1,0},
        [0x19] = {0,1,0, -1,0,0, 0,0,1},  [0x1B] = {0,0,-1, -1,0,0, 0,1,0},
        [0x1C] = {0,-1,0, -1,0,0, 0,0,-1},[0x1E] = {0,0,1, -1,0,0, 0,-1,0},
        [0x1F] = {0,1,0, 0,0,-1, -1,0,0}, [0x20] = {0,0,1, 0,1,0, -1,0,0},
        [0x22] = {0,-1,0, 0,0,1, -1,0,0}, [0x23] = {0,0,-1, 0,-1,0, -1,0,0},
    }

    -- decode satu chunk PROP (tipe yang didukung). Return tabel nilai 1..n atau nil
    local function decodeProp(ptype, chunk, p, n)
        local v = table.create(n)
        if ptype == 1 then
            for i = 1, n do local s; s, p = sunpack("<s4", chunk, p); v[i] = s end
        elseif ptype == 2 then
            for i = 1, n do v[i] = byte(chunk, p + i - 1) ~= 0 end
        elseif ptype == 3 then
            v = readInts(chunk, p, n)
        elseif ptype == 4 then
            v = readFloats(chunk, p, n)
        elseif ptype == 5 then
            for i = 1, n do v[i] = (sunpack("<d", chunk, p)); p += 8 end
        elseif ptype == 6 then
            local s, o
            s, p = readFloats(chunk, p, n); o, p = readInts(chunk, p, n)
            for i = 1, n do v[i] = UDim.new(s[i], o[i]) end
        elseif ptype == 7 then
            local sx, sy, ox, oy
            sx, p = readFloats(chunk, p, n); sy, p = readFloats(chunk, p, n)
            ox, p = readInts(chunk, p, n); oy, p = readInts(chunk, p, n)
            for i = 1, n do v[i] = UDim2.new(sx[i], ox[i], sy[i], oy[i]) end
        elseif ptype == 11 then
            local r = readRaw(chunk, p, n)
            for i = 1, n do
                local ok, bc = pcall(BrickColor.new, r[i])
                if ok then v[i] = bc end
            end
        elseif ptype == 12 then
            local r, g, b
            r, p = readFloats(chunk, p, n); g, p = readFloats(chunk, p, n); b, p = readFloats(chunk, p, n)
            for i = 1, n do v[i] = Color3.new(r[i], g[i], b[i]) end
        elseif ptype == 13 then
            local x, y
            x, p = readFloats(chunk, p, n); y, p = readFloats(chunk, p, n)
            for i = 1, n do v[i] = Vector2.new(x[i], y[i]) end
        elseif ptype == 14 then
            local x, y, z
            x, p = readFloats(chunk, p, n); y, p = readFloats(chunk, p, n); z, p = readFloats(chunk, p, n)
            for i = 1, n do v[i] = Vector3.new(x[i], y[i], z[i]) end
        elseif ptype == 16 then
            local rots = {}
            for i = 1, n do
                local id = byte(chunk, p); p += 1
                if id == 0 then
                    local m = {}
                    for k = 1, 9 do m[k] = (sunpack("<f", chunk, p)); p += 4 end
                    rots[i] = m
                else
                    rots[i] = ROT[id]
                end
            end
            local x, y, z
            x, p = readFloats(chunk, p, n); y, p = readFloats(chunk, p, n); z, p = readFloats(chunk, p, n)
            for i = 1, n do
                local m = rots[i] or ROT[0x02]
                v[i] = CFrame.new(x[i], y[i], z[i], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9])
            end
        elseif ptype == 18 then
            local r = readRaw(chunk, p, n)
            for i = 1, n do v[i] = {tok = r[i]} end
        elseif ptype == 19 then
            v = readRefs(chunk, p, n)
        elseif ptype == 23 then
            for i = 1, n do
                local a, b = sunpack("<ff", chunk, p); p += 8
                v[i] = NumberRange.new(a, b)
            end
        elseif ptype == 26 then
            for i = 1, n do
                v[i] = Color3.fromRGB(byte(chunk, p + i - 1), byte(chunk, p + n + i - 1), byte(chunk, p + 2 * n + i - 1))
            end
        elseif ptype == 34 then
            local types
            types, p = readRaw(chunk, p, n)
            for i = 1, n do
                if types[i] == 1 then
                    local s; s, p = sunpack("<s4", chunk, p); v[i] = s
                end
            end
        else
            return nil
        end
        return v
    end

    local function chainPath(insts, inst)
        local names, cur, guard = {}, inst, 0
        while cur and guard < 200 do
            table.insert(names, 1, cur.name)
            cur = insts[cur.parent]
            guard += 1
        end
        return table.concat(names, "/")
    end

    -- return: list script, tree {insts, order}
    local function parseBinary(data)
        if data:sub(1, 8) ~= "<roblox!" then return nil end
        local pos = 33
        local classes, insts, order = {}, {}, {}
        local chunks = 0
        while pos <= #data do
            local name = data:sub(pos, pos + 3)
            local comp, unc = sunpack("<I4I4", data, pos + 4)
            pos += 16
            local raw
            if comp == 0 then
                raw = data:sub(pos, pos + unc - 1); pos += unc
            else
                raw = data:sub(pos, pos + comp - 1); pos += comp
            end
            if name == "END\0" then break end
            chunks += 1
            if chunks % 20 == 0 then task.wait() end
            if name == "INST" or name == "PROP" or name == "PRNT" then
                local chunk = decompressChunk(comp, raw)
                if name == "INST" then
                    local cid, p = sunpack("<I4", chunk, 1)
                    local cname; cname, p = sunpack("<s4", chunk, p)
                    p += 1
                    local count; count, p = sunpack("<I4", chunk, p)
                    local refs = readRefs(chunk, p, count)
                    classes[cid] = {name = cname, refs = refs}
                    for _, r in ipairs(refs) do
                        insts[r] = {class = cname, name = cname, parent = -1}
                        order[#order + 1] = r
                    end
                elseif name == "PROP" then
                    local cid, p = sunpack("<I4", chunk, 1)
                    local pname; pname, p = sunpack("<s4", chunk, p)
                    local ptype = byte(chunk, p); p += 1
                    local cls = classes[cid]
                    if cls then
                        local okD, vals = pcall(decodeProp, ptype, chunk, p, #cls.refs)
                        if okD and vals then
                            for i, r in ipairs(cls.refs) do
                                local val = vals[i]
                                local it = insts[r]
                                if val ~= nil and it then
                                    if pname == "Name" and ptype == 1 then
                                        it.name = val
                                    elseif pname == "Source" and ptype == 1 then
                                        it.source = val
                                    elseif ptype == 19 then
                                        if val >= 0 then
                                            it.refprops = it.refprops or {}
                                            it.refprops[pname] = val
                                        end
                                    else
                                        it.props = it.props or {}
                                        it.props[pname] = val
                                    end
                                end
                            end
                        end
                    end
                else -- PRNT
                    local p = 2
                    local count; count, p = sunpack("<I4", chunk, p)
                    local kids; kids, p = readRefs(chunk, p, count)
                    local pars = readRefs(chunk, p, count)
                    for i = 1, count do
                        local k = insts[kids[i]]
                        if k then k.parent = pars[i] end
                    end
                end
            end
        end
        local list = {}
        for _, r in ipairs(order) do
            local it = insts[r]
            if SCRIPT_CLASSES[it.class] and it.source and #it.source > 0 then
                list[#list + 1] = {path = chainPath(insts, it), class = it.class, source = it.source}
            end
        end
        return list, {insts = insts, order = order}
    end

    -- ---------- Parser XML (rbxmx / rbxlx) ----------
    local function unesc(str)
        return (str:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&apos;", "'"):gsub("&amp;", "&"))
    end
    local function xmlStr(inner)
        return inner:match("^%s*<!%[CDATA%[(.*)%]%]>%s*$") or unesc(inner)
    end
    local function xn(inner, tag) return tonumber(inner:match("<" .. tag .. ">%s*(.-)%s*</" .. tag .. ">")) or 0 end
    local function c3u(n)
        n = n or 0
        return Color3.fromRGB(bit32.band(bit32.rshift(n, 16), 255), bit32.band(bit32.rshift(n, 8), 255), bit32.band(n, 255))
    end

    local function applyXmlProp(node, tag, pname, inner)
        if not pname then return end
        node.props = node.props or {}
        local props = node.props
        if tag == "string" or tag == "ProtectedString" then
            local v = xmlStr(inner)
            if pname == "Name" then node.name = v
            elseif pname == "Source" then node.source = v
            else props[pname] = v end
        elseif tag == "bool" then
            props[pname] = inner:find("true", 1, true) ~= nil
        elseif tag == "int" or tag == "float" or tag == "double" or tag == "int64" then
            local n = tonumber(inner)
            if n then props[pname] = n end
        elseif tag == "token" then
            local n = tonumber(inner)
            if n then props[pname] = {tok = n} end
        elseif tag == "Color3uint8" then
            props[pname] = c3u(tonumber(inner))
        elseif tag == "Color3" then
            if inner:find("<R>", 1, true) then
                props[pname] = Color3.new(xn(inner, "R"), xn(inner, "G"), xn(inner, "B"))
            else
                props[pname] = c3u(tonumber(inner))
            end
        elseif tag == "Vector3" then
            props[pname] = Vector3.new(xn(inner, "X"), xn(inner, "Y"), xn(inner, "Z"))
        elseif tag == "Vector2" then
            props[pname] = Vector2.new(xn(inner, "X"), xn(inner, "Y"))
        elseif tag == "CoordinateFrame" then
            props[pname] = CFrame.new(xn(inner, "X"), xn(inner, "Y"), xn(inner, "Z"),
                xn(inner, "R00"), xn(inner, "R01"), xn(inner, "R02"),
                xn(inner, "R10"), xn(inner, "R11"), xn(inner, "R12"),
                xn(inner, "R20"), xn(inner, "R21"), xn(inner, "R22"))
        elseif tag == "UDim2" then
            props[pname] = UDim2.new(xn(inner, "XS"), xn(inner, "XO"), xn(inner, "YS"), xn(inner, "YO"))
        elseif tag == "UDim" then
            props[pname] = UDim.new(xn(inner, "S"), xn(inner, "O"))
        elseif tag == "BrickColor" then
            local ok, bc = pcall(BrickColor.new, tonumber(inner) or 194)
            if ok then props[pname] = bc end
        elseif tag == "Content" then
            local url = inner:match("<url>(.-)</url>")
            if url and url ~= "" then props[pname] = unesc(url) end
        elseif tag == "NumberRange" then
            local a, b = inner:match("([%-%d%.eE]+)%s+([%-%d%.eE]+)")
            if a and b then props[pname] = NumberRange.new(tonumber(a), tonumber(b)) end
        elseif tag == "Ref" then
            node.refname = node.refname or {}
            node.refname[pname] = inner:match("^%s*(.-)%s*$")
        end
    end

    local function parseXml(data)
        local insts, order, stack, refMap, list = {}, {}, {}, {}, {}
        local idc, pos, steps = 0, 1, 0
        local find = string.find
        while true do
            local s, e, closing, tag, attrs = find(data, "<(/?)([%w_]+)([^>]*)>", pos)
            if not s then break end
            pos = e + 1
            steps += 1
            if steps % 600 == 0 then task.wait() end
            if tag == "Item" then
                local selfClose = attrs:sub(-1) == "/"
                if closing == "" then
                    idc += 1
                    local top = stack[#stack]
                    local node = {
                        id = idc, class = attrs:match('class="([^"]*)"') or "Folder", name = "?",
                        parent = top and top.id or -1,
                    }
                    node.name = node.class
                    local rf = attrs:match('referent="([^"]*)"')
                    if rf then refMap[rf] = idc end
                    insts[idc] = node
                    order[#order + 1] = idc
                    if not selfClose then table.insert(stack, node) end
                else
                    local it = table.remove(stack)
                    if it and SCRIPT_CLASSES[it.class] and it.source and #it.source > 0 then
                        local names = {}
                        for _, a in ipairs(stack) do names[#names + 1] = a.name end
                        names[#names + 1] = it.name
                        list[#list + 1] = {path = table.concat(names, "/"), class = it.class, source = it.source}
                    end
                end
            elseif closing == "" and #stack > 0 and tag ~= "Properties" and attrs:sub(-1) ~= "/" then
                local cs, ce = find(data, "</" .. tag .. ">", pos, true)
                if cs then
                    local inner = data:sub(pos, cs - 1)
                    pos = ce + 1
                    applyXmlProp(stack[#stack], tag, attrs:match('name="([^"]*)"'), inner)
                end
            end
        end
        for _, it in pairs(insts) do
            if it.refname then
                it.refprops = {}
                for k, rf in pairs(it.refname) do
                    if refMap[rf] then it.refprops[k] = refMap[rf] end
                end
                it.refname = nil
            end
        end
        return list, {insts = insts, order = order}
    end

    -- ---------- Studio Lite editor ----------
    local function pathOf(inst, stopAt)
        local names, cur = {}, inst
        while cur and cur ~= stopAt do
            table.insert(names, 1, cur.Name)
            cur = cur.Parent
        end
        return table.concat(names, "/")
    end

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TEMPLATE_KEY = {
        Script = "InsertScriptScript",
        LocalScript = "InsertLocalScriptLocalScript",
        ModuleScript = "InsertModuleScriptModuleScript",
    }
    local templateCache = {}

    local function getServerFunctions()
        local f = ReplicatedStorage:FindFirstChild("StudioLiteFolder")
        return f and f:FindFirstChild("ServerFunctions")
    end

    local function getTemplate(className)
        if templateCache[className] then return templateCache[className] end
        local sf, key = getServerFunctions(), TEMPLATE_KEY[className]
        if not (sf and key) then return nil end
        pcall(function() sf:InvokeServer("LoadAssetToPlayerGui", key) end)
        local holder = lp:WaitForChild("PlayerGui"):WaitForChild(key, 3)
        if not holder then return nil end
        local list = {}
        for _, c in ipairs(holder:GetChildren()) do table.insert(list, c:Clone()) end
        pcall(function() sf:InvokeServer("ClearAssetFromPlayerGui", key) end)
        templateCache[className] = list
        return list
    end

    local function applySource(inst, text)
        if not inst:FindFirstChild("SL_CodeTextBox") then
            local tpl = getTemplate(inst.ClassName)
            if tpl then
                for _, c in ipairs(tpl) do c:Clone().Parent = inst end
            end
        end
        local box = inst:FindFirstChild("SL_CodeTextBox")
        if not box then
            box = Instance.new("TextBox")
            box.Name = "SL_CodeTextBox"
            box.MultiLine = true
            box.ClearTextOnFocus = false
            box.Visible = false
            box.Parent = inst
        end
        box.Text = text
        if inst.ClassName == "ModuleScript" then
            local ro = inst:FindFirstChild("SL_1ReadOnly")
            if ro then
                pcall(function() ro.ContentText = text end)
                pcall(function() ro.Text = text end)
            end
        end
    end

    local function cleanSource(src)
        if src:find("<font color=", 1, true) or src:find("<b><font", 1, true) then
            src = src:gsub("</?font[^>]*>", ""):gsub("</?[biu]>", "")
            src = src:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&apos;", "'"):gsub("&amp;", "&")
        end
        return src
    end

    local function pushSource(inst, folderName, path, class, source)
        local env = (getgenv and getgenv()) or _G
        env.ImportedSources = env.ImportedSources or {}
        pcall(function()
            if setscriptable then setscriptable(inst, "Source", true) end
            inst.Source = source
        end)
        local text = #source > 150000 and source:sub(1, 150000) or source
        applySource(inst, text)
        env.ImportedSources[folderName .. "/" .. path] = source
        registerScript(path, class, source)
    end

    -- jalur GetObjects: cocokkan script berdasar path
    local function attachSources(objs, folder, parsed)
        local queues = {}
        for _, sc in ipairs(parsed) do
            sc.source = cleanSource(sc.source)
            local key = sc.path .. "|" .. sc.class
            queues[key] = queues[key] or {}
            table.insert(queues[key], sc)
        end
        local n = 0
        local function handle(inst)
            if SCRIPT_CLASSES[inst.ClassName] then
                local q = queues[pathOf(inst, folder) .. "|" .. inst.ClassName]
                local sc = q and table.remove(q, 1)
                if sc then
                    n += 1
                    pushSource(inst, folder.Name, sc.path, sc.class, sc.source)
                end
            end
        end
        local visited = 0
        for _, obj in ipairs(objs) do
            handle(obj)
            for _, d in ipairs(obj:GetDescendants()) do
                handle(d)
                visited += 1
                if visited % 150 == 0 then task.wait() end
            end
        end
        return n
    end

    -- ---------- Rebuild: bangun instance asli dari isi file ----------
    local MAX_NODES = 60000
    local ALIAS = {size = "Size", Color3uint8 = "Color", MeshContent = "MeshId", TextureContent = "TextureID"}

    local function buildFromTree(folder, tree, opts, prog)
        local insts, order = tree.insts, tree.order
        local skipMemo = {}
        local function isSkipped(r)
            local m = skipMemo[r]
            if m ~= nil then return m end
            local it = insts[r]
            local res = false
            if not it then
                res = true
            elseif SKIP_CLASSES[it.class] then
                res = true
            elseif it.parent and it.parent ~= -1 and insts[it.parent] then
                res = isSkipped(it.parent)
            end
            skipMemo[r] = res
            return res
        end

        local list, truncated = {}, false
        for _, r in ipairs(order) do
            if #list >= MAX_NODES then truncated = true; break end
            if not isSkipped(r) then list[#list + 1] = r end
        end
        local total = #list
        local made = {}
        local st = {objects = 0, scripts = 0, parts = 0, meshFail = 0, unions = 0, truncated = truncated}

        -- 1) buat instance + set properti
        for idx, r in ipairs(list) do
            local it = insts[r]
            local okN, inst = pcall(Instance.new, it.class)
            if not okN then inst = Instance.new("Folder") end
            pcall(function() inst.Name = it.name end)
            made[r] = inst
            if it.props then
                local hasC3 = it.props.Color3uint8 ~= nil
                for pname, val in pairs(it.props) do
                    if not (pname == "BrickColor" and hasC3) then
                        local target = ALIAS[pname] or pname
                        if type(val) == "table" and val.tok ~= nil then
                            pcall(function()
                                local cur = inst[target]
                                if typeof(cur) == "EnumItem" then
                                    inst[target] = cur.EnumType:FromValue(val.tok)
                                end
                            end)
                        else
                            local ok = pcall(function() inst[target] = val end)
                            if not ok and target == "MeshId" then st.meshFail += 1 end
                        end
                    end
                end
            end
            if inst:IsA("BasePart") then
                st.parts += 1
                if opts.anchor then pcall(function() inst.Anchored = true end) end
            end
            if it.class == "UnionOperation" or it.class == "NegateOperation" then st.unions += 1 end
            if idx % 200 == 0 then
                prog(0.30 + 0.35 * idx / total, "Membuat object " .. idx .. " / " .. total)
                task.wait()
            end
        end

        -- 2) susun hierarki (anak ke induk dulu, root terakhir supaya masuk Workspace sekali jalan)
        for idx, r in ipairs(list) do
            local par = made[insts[r].parent]
            if par then pcall(function() made[r].Parent = par end) end
            if idx % 400 == 0 then task.wait() end
        end
        for idx, r in ipairs(list) do
            if not made[insts[r].parent] then
                pcall(function() made[r].Parent = folder end)
                st.objects += 1
            end
            if idx % 400 == 0 then task.wait() end
        end
        st.objects = total

        -- 3) referensi (PrimaryPart, Part0/Part1 weld, dll)
        prog(0.70, "Menyambung referensi...")
        for _, r in ipairs(list) do
            local it = insts[r]
            if it.refprops then
                for pname, id in pairs(it.refprops) do
                    local target = made[id]
                    if target then pcall(function() made[r][pname] = target end) end
                end
            end
        end

        -- 4) script
        local sc = 0
        local scriptTotalCount = 0
        for _, r in ipairs(list) do
            local it = insts[r]
            if SCRIPT_CLASSES[it.class] and it.source and #it.source > 0 then scriptTotalCount += 1 end
        end
        for idx, r in ipairs(list) do
            local it = insts[r]
            local inst = made[r]
            if SCRIPT_CLASSES[it.class] and it.source and #it.source > 0 and inst.ClassName == it.class then
                sc += 1
                pushSource(inst, folder.Name, chainPath(insts, it), it.class, cleanSource(it.source))
                if sc % 10 == 0 then
                    prog(0.75 + 0.22 * sc / math.max(scriptTotalCount, 1), "Script " .. sc .. " / " .. scriptTotalCount)
                    task.wait()
                end
            end
        end
        st.scripts = sc
        return st
    end

    -- ---------- Import ----------
    local function tryLoad(path)
        local okA, asset = pcall(getcustomasset, path)
        if not okA then return nil end
        local ok1, o1 = pcall(function() return game:GetObjects(asset) end)
        if ok1 and type(o1) == "table" and #o1 > 0 then return o1 end
        local ok2, o2 = pcall(function() return game:GetService("InsertService"):LoadLocalAsset(asset) end)
        if ok2 and typeof(o2) == "Instance" then return {o2} end
        return nil
    end

    local function importFile(info, prog)
        if not (readfile and getcustomasset) then
            return false, "Executor tidak support readfile/getcustomasset"
        end
        prog(0.04, "Membaca file...")
        local okR, data = pcall(readfile, info.path)
        if not (okR and type(data) == "string") then return false, "Gagal membaca file" end

        prog(0.10, "Membaca struktur file...")
        local parsed, tree, perr
        local okP, a, b = pcall(function()
            if data:sub(1, 8) == "<roblox!" then return parseBinary(data) end
            if data:find("<roblox", 1, true) then return parseXml(data) end
        end)
        if okP then parsed, tree = a, b else perr = tostring(a) end
        data = nil

        local base = info.name:gsub("%.[^%.]+$", "")
        local name, n = base, 1
        while workspace:FindFirstChild(name) do n += 1; name = base .. "_" .. n end
        local folder = new("Folder", {Name = name}, workspace)

        local count, via, scriptCount, detail = 0, "GetObjects", 0, ""
        local expected = tree and #tree.order or 0

        -- cara 1: GetObjects / LoadLocalAsset
        if not settings.force then
            prog(0.20, "Memuat model...")
            local objs = tryLoad(info.path)
            if objs then
                local function adopt(obj)
                    local okp = pcall(function() obj.Parent = folder end)
                    if okp and obj.Parent == folder then count += 1 return end
                    local sub = Instance.new("Folder")
                    sub.Name = obj.Name
                    local moved = 0
                    for _, ch in ipairs(obj:GetChildren()) do
                        if pcall(function() ch.Parent = sub end) and ch.Parent == sub then moved += 1 end
                    end
                    if moved > 0 then sub.Parent = folder; count += moved else sub:Destroy() end
                end
                for _, obj in ipairs(objs) do
                    if typeof(obj) == "Instance" then
                        if obj:IsA("DataModel") then
                            for _, svc in ipairs(obj:GetChildren()) do adopt(svc) end
                        else
                            adopt(obj)
                        end
                    end
                end
                local totalDesc = #folder:GetDescendants() + #folder:GetChildren()
                if expected > 0 and totalDesc < expected * 0.7 then
                    -- hasil GetObjects tidak lengkap -> buang, pakai Rebuild
                    folder:ClearAllChildren()
                    count = 0
                end
            end
        end

        if count > 0 then
            if parsed then
                prog(0.70, "Memasukkan script ke editor...")
                local okA, res = pcall(attachSources, {folder}, folder, parsed)
                if okA then scriptCount = res else detail = " (error script: " .. tostring(res):sub(1, 50) .. ")" end
            end
        else
            -- cara 2: Rebuild dari isi file
            if not tree or #tree.order == 0 then
                folder:Destroy()
                return false, perr and ("Gagal parse: " .. perr:sub(1, 70)) or "File kosong / format tidak didukung"
            end
            via = "Rebuild"
            prog(0.30, "Membangun ulang model & part...")
            local okB, st = pcall(buildFromTree, folder, tree, {anchor = settings.anchor}, prog)
            if not okB then
                folder:Destroy()
                return false, "Rebuild gagal: " .. tostring(st):sub(1, 80)
            end
            count, scriptCount = st.objects, st.scripts
            detail = " | " .. st.parts .. " part"
            if st.meshFail > 0 then detail = detail .. " | " .. st.meshFail .. " mesh gagal di-set" end
            if st.unions > 0 then detail = detail .. " | " .. st.unions .. " union kosong" end
            if st.truncated then detail = detail .. " | dipotong " .. MAX_NODES .. " node" end
        end

        if count == 0 then
            folder:Destroy()
            return false, "File kosong / format tidak didukung executor"
        end
        prog(1, "Selesai")
        return true, count .. " object, " .. scriptCount .. " script [" .. via .. "]" .. detail .. " -> Workspace." .. name
    end

    -- ---------- Scan + daftar file ----------
    local function kindOf(name)
        local l = name:lower()
        if l:match("%.rbxmx?$") then return "MODEL" end
        if l:match("%.rbxlx?$") then return "PLACE" end
    end
    local function fileName(path) return path:match("([^/\\]+)$") or path end

    local function scanFiles()
        local found, seen = {}, {}
        if not listfiles then return found end
        for _, folder in ipairs(SCAN_FOLDERS) do
            local ok, list = pcall(listfiles, folder)
            if ok and type(list) == "table" then
                for _, path in ipairs(list) do
                    local kind = kindOf(path)
                    if kind and not seen[path] then
                        seen[path] = true
                        table.insert(found, {name = fileName(path), path = path, kind = kind})
                    end
                end
            end
        end
        table.sort(found, function(x, y) return x.name:lower() < y.name:lower() end)
        return found
    end

    local importing = false
    local function addRow(info, order)
        local isPlace = info.kind == "PLACE"
        local col = isPlace and C.a2 or C.a1
        local f = new("Frame", {BackgroundColor3 = WHITE, BackgroundTransparency = 0.25, BorderSizePixel = 0, LayoutOrder = order}, listFrame)
        corner(f, 14)
        local st = stroke(f, C.line, 0.35, 1)
        gradient(f, C.surface2, C.surface, 135)
        f.MouseEnter:Connect(function() tween(st, 0.15, {Color = col, Transparency = 0.1}) end)
        f.MouseLeave:Connect(function() tween(st, 0.15, {Color = C.line, Transparency = 0.35}) end)

        local tile = new("Frame", {Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = col, BackgroundTransparency = 0.8, BorderSizePixel = 0}, f)
        corner(tile, 10)
        new("ImageLabel", {
            Size = UDim2.fromOffset(18, 18), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1, Image = isPlace and ICON.GAMEPAD or ICON.FILE, ImageColor3 = col,
        }, tile)
        local nl = label(f, info.name, 11, UDim2.fromOffset(52, 9), UDim2.new(1, -62, 0, 16))
        nl.TextTruncate = Enum.TextTruncate.AtEnd
        local tag = new("TextLabel", {
            Size = UDim2.fromOffset(44, 14), Position = UDim2.fromOffset(52, 29), BackgroundColor3 = col,
            Text = info.kind, Font = Enum.Font.GothamBold, TextSize = 8, TextColor3 = C.ink, BorderSizePixel = 0,
        }, f)
        corner(tag, 7)
        local ext = info.name:match("(%.[^%.]+)$") or ""
        label(f, ext, 9, UDim2.fromOffset(102, 28), UDim2.fromOffset(60, 16), C.muted, Enum.Font.Gotham)

        local btn, btnLbl = gradButton(f, "IMPORT", UDim2.fromOffset(10, 56), UDim2.new(1, -20, 0, 26))
        btn.MouseButton1Click:Connect(function()
            if importing then
                notify("Sibuk", "Tunggu import sebelumnya selesai.", true)
                return
            end
            importing = true
            btnLbl.Text = "LOADING..."
            task.spawn(function()
                local pok, ok, msg = pcall(importFile, info, setProg)
                if not pok then
                    msg = "Error: " .. tostring(ok):sub(1, 90)
                    ok = false
                end
                btnLbl.Text = ok and "DONE" or "FAIL"
                if ok then
                    importedTotal += 1
                    statImported.Text = tostring(importedTotal)
                end
                setProg(ok and 1 or 0, ok and "Selesai" or "Gagal")
                notify(ok and "Berhasil" or "Gagal", msg, not ok)
                importing = false
                task.wait(2.5)
                resetProg()
                if btn.Parent then btnLbl.Text = "IMPORT" end
            end)
        end)
        table.insert(rows, {frame = f, kind = info.kind, name = info.name})
    end

    local scanning = false
    local function refresh()
        if scanning then return end
        scanning = true
        for _, r in ipairs(rows) do r.frame:Destroy() end
        table.clear(rows)
        if makefolder and isfolder and not isfolder(ASSET_FOLDER) then pcall(makefolder, ASSET_FOLDER) end
        setProg(0.5, "Memindai file...")
        local files = scanFiles()
        for i, info in ipairs(files) do addRow(info, i) end
        statFiles.Text = tostring(#files)
        applyFilter()
        resetProg()
        if #files > 0 then
            notify("Pemindaian selesai", "Ditemukan " .. #files .. " file asset.", false)
        else
            notify("Kosong", "Tidak ada file asset di workspace/" .. ASSET_FOLDER, true)
        end
        scanning = false
    end
    rescan.MouseButton1Click:Connect(function()
        tween(rescanIcon, 0.4, {Rotation = rescanIcon.Rotation + 360})
        refresh()
    end)


    showTab("Library")
    return {refresh = refresh}
end

-- ScreenGui
local gui = new("ScreenGui", {
    Name = "BalereotCommunity", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
}, nil)
local okParent = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not okParent or not gui.Parent then gui.Parent = player:WaitForChild("PlayerGui") end

-- Jendela utama
local main = new("Frame", {
    Name = "BalereotMain", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    BackgroundColor3 = C.bg, BorderSizePixel = 0, Active = true, Draggable = true,
    ClipsDescendants = true,
}, gui)
round(main, 14)
new("UISizeConstraint", {MaxSize = Vector2.new(420, 9999), MinSize = Vector2.new(280, 394)}, main)
gradient(main, {{0, Color3.fromRGB(34, 26, 14)}, {0.5, Color3.fromRGB(14, 12, 13)}, {1, Color3.fromRGB(5, 5, 7)}}, 90)
local mainStroke = stroke(main, C.stroke, 3)
spin(gradient(mainStroke, {{0, C.accent}, {0.25, C.cyan}, {0.5, Color3.fromRGB(255, 255, 255)}, {0.75, C.accent2}, {1, C.accent}}), 4)

-- Cahaya emas lembut di bagian atas jendela
local topGlow = new("Frame", {Name = "TopGlow", Size = UDim2.new(1, 0, 0, 130), BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 1}, main)
new("UIGradient", {Color = ColorSequence.new(C.accent), Rotation = 90,
    Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1)})}, topGlow)

particles(main, 14, 1)

-- Animasi buka / tutup jendela (slide + zoom memantul + kilatan border)
local mainScale = new("UIScale", {Name = "FXMainScale", Scale = 1}, main)
local restPos = main.Position
local closing = false
local function openMain()
    if closing or main.Visible then return end
    main.Position = restPos + UDim2.fromOffset(0, 60)
    mainScale.Scale = 0.72
    mainStroke.Thickness = 8
    main.Visible = true
    TweenService:Create(mainScale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    TweenService:Create(main, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = restPos}):Play()
    TweenService:Create(mainStroke, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Thickness = 3}):Play()
end
local function closeMain()
    if closing or not main.Visible then return end
    closing = true
    restPos = main.Position
    TweenService:Create(mainScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0.6}):Play()
    TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = restPos + UDim2.fromOffset(0, 50)}):Play()
    task.delay(0.27, function()
        main.Visible = false
        mainScale.Scale = 1
        main.Position = restPos
        closing = false
    end)
end
local function toggleMain()
    if closing then return end
    if main.Visible then closeMain() else openMain() end
end

-- Background gambar (logo)
local bg = new("ImageLabel", {
    Name = "Background", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    ImageTransparency = BG_TRANSPARENCY, ScaleType = Enum.ScaleType.Crop, ZIndex = 0,
}, main)
round(bg, 14)
task.spawn(function()
    if BG_ASSET_ID then
        bg.Image = thumb(tonumber(BG_ASSET_ID) or 0, 420)
    elseif BG_URL and writefile and getcustomasset then
        local ok, data = pcall(function() return game:HttpGet(BG_URL) end)
        if ok and data then
            pcall(function()
                writefile("balereot_bg.png", data)
                bg.Image = getcustomasset("balereot_bg.png")
            end)
        end
    end
end)

-- Tombol toggle (kiri atas)
local toggleBox = new("Frame", {
    Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(8, 8),
    BackgroundColor3 = C.header, BorderSizePixel = 0, ZIndex = 100,
}, gui)
round(toggleBox, 8)
spin(gradient(stroke(toggleBox, C.accent, 1.5), {{0, C.accent}, {0.33, C.cyan}, {0.66, C.accent2}, {1, C.accent}}), 2.5)
local toggleBtn = new("TextButton", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "BC",
    TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = C.white, ZIndex = 101,
}, toggleBox)
toggleBtn.MouseButton1Click:Connect(toggleMain)

-- Header
local header = new("Frame", {Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = C.header, BorderSizePixel = 0, ZIndex = 3}, main)
round(header, 14)
gradient(header, {{0, Color3.fromRGB(40, 31, 16)}, {1, Color3.fromRGB(12, 11, 13)}}, 90)
local line = new("Frame", {Size = UDim2.new(1, 0, 0, 1.5), Position = UDim2.new(0, 0, 1, -1.5), BorderSizePixel = 0, BackgroundColor3 = C.white, ZIndex = 5}, header)
gradient(line, {{0, C.accent}, {0.5, C.cyan}, {1, C.accent2}})
local title = new("TextLabel", {
    Position = UDim2.new(0, 12, 0.5, -9), Size = UDim2.new(0, 170, 0, 18), BackgroundTransparency = 1,
    Text = "BALEREOT COMMUNITY", TextSize = 12, Font = Enum.Font.Arcade, TextColor3 = C.white,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
}, header)
gradient(title, {{0, Color3.fromRGB(255, 214, 120)}, {0.5, Color3.fromRGB(255, 250, 235)}, {1, Color3.fromRGB(214, 168, 80)}}, 15)

local right = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(140, 24), BackgroundTransparency = 1, ZIndex = 4}, header)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, right)
local isPremium = (accessTag == "PREMIUM")
local online = new("Frame", {LayoutOrder = 1, Size = UDim2.fromOffset(isPremium and 96 or 58, 22), BackgroundColor3 = isPremium and C.white or C.input, BorderSizePixel = 0, ZIndex = 4}, right)
round(online, 11)
if isPremium then
    -- badge emas dengan kilau yang menyapu
    local pg = gradient(online, {{0, Color3.fromRGB(176, 116, 30)}, {0.4, Color3.fromRGB(255, 220, 125)}, {0.5, Color3.fromRGB(255, 250, 220)}, {0.6, Color3.fromRGB(255, 220, 125)}, {1, Color3.fromRGB(176, 116, 30)}}, 20)
    pg.Offset = Vector2.new(-1, 0)
    TweenService:Create(pg, TweenInfo.new(2.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {Offset = Vector2.new(1, 0)}):Play()
    stroke(online, Color3.fromRGB(255, 238, 180), 1.2, 0.15)
    new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "* PREMIUM *", Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = C.ink, ZIndex = 5}, online)
else
    stroke(online, C.stroke, 1, 0.4)
    new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = accessTag, Font = Enum.Font.GothamBold, TextSize = 8, TextColor3 = C.accent2, ZIndex = 5}, online)
end
local closeBtn = new("TextButton", {LayoutOrder = 2, Size = UDim2.fromOffset(26, 24), BackgroundColor3 = C.red, Text = "X", TextColor3 = C.white, TextSize = 11, Font = Enum.Font.GothamBold, BorderSizePixel = 0, ZIndex = 4}, right)
round(closeBtn, 6)
closeBtn.MouseButton1Click:Connect(closeMain)

-- Pilihan panel: TOOLBOX / IMPORT FILE
local TB_OFF = 28   -- tinggi tambahan untuk bar pilihan panel
local modeBar = new("Frame", {Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 48), BackgroundTransparency = 1, ZIndex = 6}, main)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, modeBar)
local tbView = new("Frame", {Name = "ToolboxView", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2}, main)
local impView = new("Frame", {Name = "ImportView", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Visible = false}, main)
local toolsView = new("Frame", {Name = "ToolsView", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Visible = false}, main)
local modeButtons = {}
local onImportOpen = nil
local function setMode(name)
    tbView.Visible = (name == "Toolbox")
    impView.Visible = (name == "Import")
    toolsView.Visible = (name == "Tools")
    if name == "Tools" and modeButtons.Tools then modeButtons.Tools.Text = "TOOLS" end
    for n, b in pairs(modeButtons) do
        b.BackgroundColor3 = (n == name) and C.accent or C.input
        b.TextColor3 = (n == name) and C.ink or C.sub
    end
    if name == "Import" and onImportOpen then
        local f = onImportOpen
        onImportOpen = nil
        task.spawn(f)
    end
end
local MODE_LABELS = {Toolbox = "TOOLBOX", Import = "IMPORT FILE", Tools = "TOOLS"}
for i, name in ipairs({"Toolbox", "Import", "Tools"}) do
    local b = new("TextButton", {
        LayoutOrder = i, Size = UDim2.new(1 / 3, -3, 1, 0), BackgroundColor3 = C.input,
        Text = MODE_LABELS[name], TextColor3 = C.sub, TextSize = 9.5,
        Font = Enum.Font.GothamBold, BorderSizePixel = 0, ZIndex = 7,
    }, modeBar)
    round(b, 6)
    modeButtons[name] = b
    b.MouseButton1Click:Connect(function() setMode(name) end)
end
-- Search bar
local searchBar = new("Frame", {Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 50 + TB_OFF), BackgroundColor3 = C.input, BorderSizePixel = 0, ZIndex = 3}, tbView)
round(searchBar, 8)
local searchStroke = stroke(searchBar, C.stroke, 1.2, 0.5)
new("TextLabel", {Size = UDim2.new(0, 26, 1, 0), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1, Text = "?", TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = C.sub, ZIndex = 4}, searchBar)
local searchBox = new("TextBox", {
    Size = UDim2.new(1, -100, 1, 0), Position = UDim2.fromOffset(34, 0), BackgroundTransparency = 1,
    Text = "", PlaceholderText = "Search Assets / paste ID...", TextColor3 = C.text, PlaceholderColor3 = C.dim,
    TextSize = 10, Font = Enum.Font.Code, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
}, searchBar)
searchBox.Focused:Connect(function() searchStroke.Color = C.accent; searchStroke.Transparency = 0 end)
searchBox.FocusLost:Connect(function() searchStroke.Color = C.stroke; searchStroke.Transparency = 0.5 end)
local searchBtn = new("TextButton", {
    Size = UDim2.fromOffset(58, 30), Position = UDim2.new(1, -5, 0.5, -15), AnchorPoint = Vector2.new(1, 0),
    BackgroundColor3 = C.accent, Text = "SEARCH", TextColor3 = C.ink, TextSize = 8.5,
    Font = Enum.Font.GothamBold, BorderSizePixel = 0, ZIndex = 4,
}, searchBar)
round(searchBtn, 6)

-- Tabs
local TABS = {"Model", "Texture", "Decal", "Audio", "Favorites"}
local TAB_NAMES = {Model = "Models", Texture = "Textures", Decal = "Decals", Audio = "Audio", Favorites = "* Favs"}
local currentTab = "Model"
local tabBar = new("Frame", {Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 97 + TB_OFF), BackgroundTransparency = 1, ZIndex = 3}, tbView)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, tabBar)
local tabButtons = {}

-- Hasil (grid 2 kolom)
local RES_TOP = 134 + TB_OFF
local results = new("ScrollingFrame", {
    Size = UDim2.new(1, -16, 0, 200), Position = UDim2.fromOffset(8, RES_TOP), BackgroundTransparency = 1,
    BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 3,
}, tbView)
new("UIPadding", {PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 40)}, results)
new("UIGridLayout", {CellSize = UDim2.new(0.5, -4, 0, 165), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder}, results)

local morePill = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(150, 34), BackgroundColor3 = C.header,
    BorderSizePixel = 0, Visible = false, ZIndex = 10,
}, tbView)
round(morePill, 17)
stroke(morePill, C.accent, 1.2)
local moreBtn = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "v LOAD MORE", TextColor3 = C.text, TextSize = 10, Font = Enum.Font.GothamBold, ZIndex = 11}, morePill)

-- Log
local logFrame = new("Frame", {Size = UDim2.new(1, -16, 0, 100), BackgroundColor3 = C.header, BorderSizePixel = 0, ZIndex = 3}, tbView)
round(logFrame, 10)
stroke(logFrame, C.stroke, 1, 0.5)
new("TextLabel", {Size = UDim2.new(1, -20, 0, 16), Position = UDim2.fromOffset(10, 6), BackgroundTransparency = 1, Text = "> SYSTEM OUTPUT LOG", TextSize = 8.5, Font = Enum.Font.GothamBold, TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4}, logFrame)
new("Frame", {Size = UDim2.new(1, -20, 0, 1), Position = UDim2.fromOffset(10, 26), BackgroundColor3 = C.stroke, BorderSizePixel = 0, ZIndex = 4}, logFrame)
local logList = new("ScrollingFrame", {
    Size = UDim2.new(1, -18, 1, -36), Position = UDim2.fromOffset(9, 30), BackgroundTransparency = 1,
    BorderSizePixel = 0, ScrollBarThickness = 2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 4,
}, logFrame)
new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2)}, logList)

local logCount = 0
local function log(text, color)
    logCount += 1
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = tostring(text), TextColor3 = color or C.sub,
        Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = logCount, ZIndex = 5,
    }, logList)
    if logCount > 80 then
        for _, c in ipairs(logList:GetChildren()) do
            if c:IsA("TextLabel") then c:Destroy() break end
        end
    end
    task.defer(function() logList.CanvasPosition = Vector2.new(0, logList.AbsoluteCanvasSize.Y) end)
end

local function layout()
    local h = math.clamp(camera.ViewportSize.Y - 60, 394, 620)
    main.Size = UDim2.new(0.92, 0, 0, h)
    local avail = h - RES_TOP - 8
    local resH = math.floor(avail * 0.66)
    results.Size = UDim2.new(1, -16, 0, resH)
    logFrame.Position = UDim2.fromOffset(8, RES_TOP + resH + 6)
    logFrame.Size = UDim2.new(1, -16, 0, avail - resH - 6)
    morePill.Position = UDim2.new(0.5, 0, 0, RES_TOP + resH - 6)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
layout()

-- =========================================================
-- SCANNER SCRIPT BERBAHAYA (inti pemindai)
--   Memeriksa Script / LocalScript / ModuleScript di dalam model:
--   require(ID), loadstring, getfenv, HTTP keluar, obfuscation, dll.
-- =========================================================
local Scanner = {autoScan = true, onResult = nil, last = nil}

local SCAN_RULES = {
    {label = "require(ID) memuat modul luar", w = 5, pats = {"require%s*%(%s*%-?%d%d%d%d+"}},
    {label = "require(ID) lewat variabel/angka", w = 3, pats = {"require%s*%(%s*tonumber", "require%s*%(%s*game:GetService%(\"InsertService\"%)"}},
    {label = "loadstring (menjalankan kode dinamis)", w = 5, pats = {"loadstring"}},
    {label = "getfenv / setfenv", w = 4, pats = {"getfenv", "setfenv"}},
    {label = "HTTP keluar (kirim/ambil data)", w = 4, all = {"HttpService"}, pats = {"GetAsync", "PostAsync", "RequestAsync"}},
    {label = "InsertService:LoadAsset (muat aset luar)", w = 4, pats = {"InsertService%s*:%s*LoadAsset", ":%s*LoadAssetVersion"}},
    {label = "Shutdown server", w = 5, pats = {"game%s*:%s*Shutdown", "game%.Shutdown"}},
    {label = "ClearAllChildren (hapus massal)", w = 4, pats = {"ClearAllChildren"}},
    {label = "Kick pemain", w = 3, pats = {":%s*Kick%s*%("}},
    {label = "Prompt pembelian (Marketplace)", w = 3, pats = {"PromptPurchase", "PromptProductPurchase", "PromptGamePassPurchase", "PromptPremiumPurchase"}},
    {label = "TeleportService (pindahkan pemain)", w = 3, pats = {"TeleportService"}},
    {label = "Fungsi exploit di dalam model", w = 4, pats = {"hookfunction", "newcclosure", "getrawmetatable", "setrawmetatable", "sethiddenproperty", "getgenv", "syn%.request"}},
    {label = "Obfuscation (escape desimal \\ddd)", w = 4, pats = {"\\%d%d?%d?\\%d%d?%d?\\%d%d?%d?\\%d%d?%d?\\%d%d?%d?"}},
    {label = "Obfuscation (string.char / hex panjang)", w = 2, pats = {"string%.char%s*%(", "%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x"}},
    {label = "Nama variabel obfuscated (lIl1Il)", w = 3, pats = {"[lI1][lI1][lI1][lI1][lI1][lI1]"}},
    {label = "Menyembunyikan diri (Parent = nil)", w = 2, pats = {"script%.Parent%s*=%s*nil", "script%s*:%s*Destroy"}},
    {label = "Kata kunci mencurigakan (backdoor/virus)", w = 3, pats = {"[Bb][Aa][Cc][Kk][Dd][Oo][Oo][Rr]", "[Vv][Ii][Rr][Uu][Ss]", "[Ii][Nn][Ff][Ee][Cc][Tt]"}},
}

local function stripComments(src)
    src = src:gsub("%-%-%[%[.-%]%]", "")
    src = src:gsub("%-%-[^\n]*", "")
    return src
end

local function readSource(s)
    local ok, src = pcall(function() return s.Source end)
    if ok and type(src) == "string" and #src > 0 then return src end
    if decompile then
        local ok2, d = pcall(decompile, s)
        if ok2 and type(d) == "string" and #d > 0 then return d end
    end
    if gethiddenproperty then
        local ok3, v = pcall(gethiddenproperty, s, "Source")
        if ok3 and type(v) == "string" and #v > 0 then return v end
    end
    return nil
end

-- periksa satu script -> level ("HIGH"/"MED"/"LOW"/"UNKNOWN"/nil), skor, daftar alasan
function Scanner.check(s)
    local src = readSource(s)
    if not src then return "UNKNOWN", 0, {"Source tidak bisa dibaca executor"} end
    src = stripComments(src)
    local score, reasons = 0, {}
    for _, r in ipairs(SCAN_RULES) do
        local hit = true
        if r.all then
            for _, p in ipairs(r.all) do
                if not src:find(p) then hit = false break end
            end
        end
        if hit and r.pats then
            hit = false
            for _, p in ipairs(r.pats) do
                if src:find(p) then hit = true break end
            end
        end
        if hit then
            score += r.w
            reasons[#reasons + 1] = r.label
        end
    end
    local level
    if score >= 5 then level = "HIGH" elseif score >= 3 then level = "MED" elseif score >= 1 then level = "LOW" end
    return level, score, reasons
end

-- kumpulkan semua script dari daftar root
function Scanner.collect(roots, gui)
    local list, seen = {}, {}
    local function add(o)
        if seen[o] or not o:IsA("LuaSourceContainer") then return end
        if gui and o:IsDescendantOf(gui) then return end
        if o:IsDescendantOf(game:GetService("ReplicatedStorage")) then
            local f = game:GetService("ReplicatedStorage"):FindFirstChild("StudioLiteFolder")
            if f and o:IsDescendantOf(f) then return end
        end
        seen[o] = true
        list[#list + 1] = o
    end
    for _, root in ipairs(roots) do
        if typeof(root) == "Instance" then
            add(root)
            local ok, desc = pcall(function() return root:GetDescendants() end)
            if ok then
                for i, d in ipairs(desc) do
                    add(d)
                    if i % 1500 == 0 then task.wait() end
                end
            end
        end
    end
    return list
end

-- pindai: kembalikan {items = {...}, total, high, med, low, unknown}
function Scanner.scan(roots, gui, progress)
    local scripts = Scanner.collect(roots, gui)
    local res = {items = {}, total = #scripts, high = 0, med = 0, low = 0, unknown = 0}
    for i, s in ipairs(scripts) do
        local level, score, reasons = Scanner.check(s)
        if level then
            res.items[#res.items + 1] = {obj = s, level = level, score = score, reasons = reasons}
            if level == "HIGH" then res.high += 1
            elseif level == "MED" then res.med += 1
            elseif level == "LOW" then res.low += 1
            else res.unknown += 1 end
        end
        if i % 20 == 0 then
            if progress then progress(i, #scripts) end
            task.wait()
        end
    end
    local order = {HIGH = 1, MED = 2, LOW = 3, UNKNOWN = 4}
    table.sort(res.items, function(a, b)
        if order[a.level] ~= order[b.level] then return order[a.level] < order[b.level] end
        return a.score > b.score
    end)
    Scanner.last = res
    return res
end

-- =========================================================
-- INSERT (Studio Lite)
-- =========================================================
local function spawnCFrame()
    local cam = workspace.CurrentCamera or camera
    local look = cam.CFrame.LookVector
    local pos = cam.CFrame.Position + look * SPAWN_DISTANCE
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.01 then return CFrame.new(pos) end
    return CFrame.lookAt(pos, pos + flat.Unit)
end
local function selectObj(obj)
    pcall(function() game:GetService("Selection"):Set({obj}) end)
end

local function proxyBlock(id, kind)
    local part = new("Part", {Anchored = true, Name = kind .. "_" .. id, CFrame = spawnCFrame()})
    if kind == "Audio" then
        part.Size = Vector3.new(2, 2, 2)
        part.Material = Enum.Material.Neon
        new("Sound", {Name = "AudioData", SoundId = "rbxassetid://" .. id, Volume = 0.5, Looped = true}, part):Play()
    else
        part.Size = Vector3.new(4, 4, 0.2)
        part.Material = Enum.Material.SmoothPlastic
        new(kind, {Texture = "rbxassetid://" .. id, Face = Enum.NormalId.Front}, part)
    end
    part.Parent = workspace
    selectObj(part)
end

local function fetchFromStudioLite(id)
    local folder = ReplicatedStorage:FindFirstChild("StudioLiteFolder") or ReplicatedStorage:WaitForChild("StudioLiteFolder", 5)
    local remote = folder and folder:WaitForChild("LoadAssetModelToPlayerGuiServerFunction", 5)
    if not remote then return nil, "Studio Lite tidak ditemukan" end
    local pg = player:WaitForChild("PlayerGui")
    local before = {}
    for _, c in ipairs(pg:GetChildren()) do before[c] = true end
    local ok, res = pcall(function() return remote:InvokeServer(id) end)
    if not ok then return nil, "Server timeout" end
    if typeof(res) == "Instance" then return res end
    task.wait(0.3)
    for _, c in ipairs(pg:GetChildren()) do
        if not before[c] and c ~= gui then return c end
    end
    return nil, "Gagal merender data dari SL"
end

local function place(obj)
    local sky = obj:IsA("Sky") and obj or obj:FindFirstChildWhichIsA("Sky", true)
    local tool = ((obj:IsA("Tool") or obj:IsA("HopperBin")) and obj)
        or obj:FindFirstChildWhichIsA("Tool", true) or obj:FindFirstChildWhichIsA("HopperBin", true)
    if sky then
        sky.Parent = Lighting
        if sky ~= obj then obj:Destroy() end
        return "Sky"
    elseif tool then
        pcall(function() tool:Clone().Parent = game:GetService("StarterPack") end)
        tool.Parent = player:FindFirstChild("Backpack") or workspace
        if tool ~= obj then obj:Destroy() end
        return "Tool"
    end
    obj.Parent = workspace
    task.wait(0.05)
    if obj:IsA("Model") then obj:PivotTo(spawnCFrame())
    elseif obj:IsA("BasePart") then obj.CFrame = spawnCFrame() end
    selectObj(obj)
    return "Model"
end

local function insertAsset(item)
    local id, kind = item.id, item.kind
    if kind == "Audio" or kind == "Decal" or kind == "Texture" then
        log("Inserting " .. kind .. " " .. id .. "...", C.text)
        proxyBlock(id, kind)
        return log(kind .. " Inserted to Proxy Block", C.green)
    end
    log("Inserting " .. tostring(item.name) .. "...", C.text)
    log("Connecting to SL server...", C.sub)
    local obj, err = fetchFromStudioLite(id)
    if not obj then
        local ok, model = pcall(function() return InsertService:LoadAsset(id) end)
        if not ok or not model then return log("X " .. tostring(err), C.red) end
        obj = model
    end
    local items = obj:IsA("Folder") and obj:GetChildren() or {obj}
    local result
    for _, it in ipairs(items) do result = place(it) end
    if obj:IsA("Folder") then obj:Destroy() end
    log(("OK Inserted %s (%s)"):format(tostring(item.name), result or "?"), C.green)

    -- AUTO-SCAN: periksa script di dalam model yang baru di-insert
    if Scanner.autoScan then
        task.spawn(function()
            local roots = {}
            for _, it in ipairs(items) do
                if it.Parent then roots[#roots + 1] = it end
            end
            if #roots == 0 then return end
            local okS, res = pcall(Scanner.scan, roots, gui)
            if not okS or not res then return end
            if #res.items > 0 and Scanner.onResult then pcall(Scanner.onResult, res) end
            if res.high > 0 then
                log("! BAHAYA: " .. res.high .. " script berbahaya di model ini (TOOLS > SCANNER)", C.red)
            elseif res.med > 0 then
                log("! " .. res.med .. " script curiga di model ini (TOOLS > SCANNER)", C.yellow)
            elseif res.total > 0 then
                log("Scan: " .. res.total .. " script, tidak ada pola berbahaya", C.green)
            end
        end)
    end
end

-- =========================================================
-- FAVORITES
-- =========================================================
local favorites = {}
local function favIndex(id)
    for i, f in ipairs(favorites) do if f.id == id then return i end end
end
local function toggleFav(item)
    local i = favIndex(item.id)
    if i then table.remove(favorites, i) else favorites[#favorites + 1] = item end
    return not i
end

-- =========================================================
-- PREVIEW POPUP
-- =========================================================
local overlay = new("TextButton", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4,
    Text = "", AutoButtonColor = false, Visible = false, ZIndex = 200,
}, tbView)
local pcard = new("Frame", {
    Size = UDim2.fromOffset(240, 340), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    BackgroundColor3 = C.panel, BorderSizePixel = 0, Active = true,
}, overlay)
round(pcard, 16)
stroke(pcard, C.accent, 1.5, 0.2)
local pimgFrame = new("Frame", {Size = UDim2.new(1, -24, 0, 236), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = C.input, BorderSizePixel = 0, ClipsDescendants = true}, pcard)
round(pimgFrame, 12)
stroke(pimgFrame, C.stroke, 1, 0.5)
local pimg = new("ImageLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ImageTransparency = 0}, pimgFrame)
local pph = new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "...", TextSize = 28, Font = Enum.Font.GothamBold, TextColor3 = C.dim}, pimgFrame)
local pname = new("TextLabel", {Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(12, 258), BackgroundTransparency = 1, Text = "", TextColor3 = C.white, Font = Enum.Font.GothamBold, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd}, pcard)
local pby = new("TextLabel", {Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 278), BackgroundTransparency = 1, Text = "", TextColor3 = C.sub, Font = Enum.Font.GothamMedium, TextSize = 10}, pcard)
local pinsert = new("TextButton", {
    AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -24, 0, 36),
    BackgroundColor3 = C.accent, Text = "INSERT ASSET", TextColor3 = C.ink, TextSize = 11,
    Font = Enum.Font.GothamBold, BorderSizePixel = 0, AutoButtonColor = true,
}, pcard)
round(pinsert, 8)
local pclose = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 20), Size = UDim2.fromOffset(26, 26),
    BackgroundColor3 = Color3.fromRGB(10, 10, 10), BackgroundTransparency = 0.4, Text = "X", TextColor3 = C.white,
    TextSize = 12, Font = Enum.Font.GothamBold, BorderSizePixel = 0, ZIndex = 5,
}, pcard)
round(pclose, 13)

local previewItem
local function closePreview() overlay.Visible = false; previewItem = nil end
pclose.MouseButton1Click:Connect(closePreview)
overlay.MouseButton1Click:Connect(closePreview)
pinsert.MouseButton1Click:Connect(function()
    local item = previewItem
    if not item then return end
    closePreview()
    task.spawn(insertAsset, item)
end)

local function loadThumb(img, placeholder, id, size)
    img.Image = thumb(id, size)
    task.spawn(function()
        local t = 0
        while img.Parent and not img.IsLoaded and t < 8 do task.wait(0.2); t += 0.2 end
        if placeholder.Parent then
            if img.IsLoaded then placeholder.Visible = false else placeholder.Text = "?" end
        end
    end)
end

local function showPreview(item)
    previewItem = item
    pname.Text = tostring(item.name)
    pby.Text = "by " .. tostring(item.creator) .. "  |  ID " .. item.id
    pimg.Image = ""
    pph.Visible = true
    if item.kind == "Audio" then
        pph.Text = "AUDIO"
    else
        pph.Text = "..."
        loadThumb(pimg, pph, item.id, 420)
    end
    overlay.Visible = true
end

-- =========================================================
-- KARTU ASSET (thumbnail + nama + tombol)
-- =========================================================
local function clearResults()
    for _, c in ipairs(results:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    results.CanvasPosition = Vector2.new(0, 0)
    morePill.Visible = false
end

local order = 0
local function addCard(item)
    order += 1
    local card = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = order}, results)
    round(card, 10)
    local cst = stroke(card, C.stroke, 1, 0.5)
    card.MouseEnter:Connect(function() TweenService:Create(cst, TweenInfo.new(0.15), {Color = C.accent, Transparency = 0}):Play() end)
    card.MouseLeave:Connect(function() TweenService:Create(cst, TweenInfo.new(0.15), {Color = C.stroke, Transparency = 0.5}):Play() end)
    local tf = new("Frame", {Size = UDim2.new(1, -12, 0, 100), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = C.input, BorderSizePixel = 0, ClipsDescendants = true}, card)
    round(tf, 8)
    local img = new("ImageLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit}, tf)
    local ph = new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "...", TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = C.dim}, tf)
    if item.kind == "Audio" then ph.Text = "AUDIO" else loadThumb(img, ph, item.id, 150) end

    new("TextLabel", {Size = UDim2.new(1, -12, 0, 16), Position = UDim2.fromOffset(6, 110), BackgroundTransparency = 1, Text = tostring(item.name), TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, card)
    new("TextLabel", {Size = UDim2.new(1, -12, 0, 12), Position = UDim2.fromOffset(6, 126), BackgroundTransparency = 1, Text = "by " .. tostring(item.creator), TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, card)

    local ins = new("TextButton", {Size = UDim2.new(1, -42, 0, 18), Position = UDim2.fromOffset(6, 142), BackgroundColor3 = C.accent, Text = "INSERT", TextColor3 = C.ink, Font = Enum.Font.GothamBold, TextSize = 9, BorderSizePixel = 0}, card)
    round(ins, 5)
    local fav = new("TextButton", {Size = UDim2.fromOffset(28, 18), Position = UDim2.new(1, -34, 0, 142), BackgroundColor3 = C.input, Text = favIndex(item.id) and "*" or "+", TextColor3 = C.accent2, Font = Enum.Font.GothamBold, TextSize = 13, BorderSizePixel = 0}, card)
    round(fav, 5)

    card.MouseButton1Click:Connect(function() showPreview(item) end)
    ins.MouseButton1Click:Connect(function() task.spawn(insertAsset, item) end)
    fav.MouseButton1Click:Connect(function()
        local added = toggleFav(item)
        fav.Text = added and "*" or "+"
        log(added and "Ditambahkan ke Favorites" or "Dihapus dari Favorites", C.yellow)
        if currentTab == "Favorites" and not added then card:Destroy() end
    end)
end

-- =========================================================
-- PENCARIAN
-- =========================================================
local function toArray(res)
    if res == nil then return {} end
    if type(res) == "table" then
        if res.Results then return res.Results end
        if type(res[1]) == "table" and res[1].Results then return res[1].Results end
        return res
    end
    local ok, page = pcall(function() return res:GetCurrentPage() end)
    if ok and type(page) == "table" then return page end
    return {}
end

local function mapItem(it, kind)
    if type(it) ~= "table" then return nil end
    local id = tonumber(it.AssetId or it.Id or it.AssetID)
    if not id then return nil end
    local name = tostring(it.Name or it.Title or "Unknown")
    local low = name:lower()
    if low:match("content deleted") or low:match("%[deleted%]") or low:match("%(deleted%)") or low == "deleted" then return nil end
    local creator = "Roblox"
    if type(it.Creator) == "table" and it.Creator.Name then creator = it.Creator.Name
    elseif it.CreatorName then creator = it.CreatorName
    elseif it.Artist then creator = it.Artist end
    return {id = id, name = name, creator = tostring(creator), kind = kind}
end

local audioPages, httpCursor
local function httpSearch(kind, kw, page)
    local typeId = kind == "Model" and 10 or 13
    local url = ("https://apis.roblox.com/toolbox-service/v1/marketplace/%d?limit=20&keyword=%s"):format(typeId, HttpService:UrlEncode(kw))
    if page > 0 and httpCursor then url ..= "&cursor=" .. HttpService:UrlEncode(httpCursor) end
    local ok, res = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
    if not ok or type(res) ~= "table" or not res.data then return {} end
    httpCursor = res.nextPageCursor
    local ids = {}
    for _, d in ipairs(res.data) do ids[#ids + 1] = d.id end
    local names, creators = {}, {}
    if #ids > 0 then
        local ok2, det = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://apis.roblox.com/toolbox-service/v1/items/details?assetIds=" .. table.concat(ids, ",")))
        end)
        if ok2 and type(det) == "table" and det.data then
            for _, d in ipairs(det.data) do
                if d.asset then names[d.asset.id] = d.asset.name; creators[d.asset.id] = d.creator and d.creator.name end
            end
        end
    end
    local arr = {}
    for _, id in ipairs(ids) do arr[#arr + 1] = {AssetId = id, Name = names[id] or "Asset", CreatorName = creators[id]} end
    return arr
end

-- return: daftar item mentah, hasMore, pesan error
local function fetchPage(kind, kw, page)
    if kind == "Audio" then
        if page == 0 or not audioPages then
            local params = Instance.new("AudioSearchParams")
            params.SearchKeyword = kw
            local ok, res = pcall(function() return AssetService:SearchAudioAsync(params) end)
            if not ok or not res then return nil, false, "Audio API: " .. tostring(res) end
            audioPages = res
        else
            if not pcall(function() audioPages:AdvanceToNextPageAsync() end) then return {}, false end
        end
        return toArray(audioPages), not audioPages.IsFinished
    end
    local method = (kind == "Model") and "GetFreeModelsAsync" or "GetFreeDecalsAsync"
    local ok, res = pcall(function() return InsertService[method](InsertService, kw, page, 20) end)
    local raw = ok and toArray(res) or {}
    local err = (not ok) and tostring(res) or nil
    if #raw == 0 then
        raw = httpSearch(kind, kw, page)
        if #raw > 0 then return raw, httpCursor ~= nil end
        return nil, false, err or "Tidak ada hasil"
    end
    return raw, #raw >= 10
end

local searchToken, page, searching = 0, 0, false

local function renderFavorites()
    clearResults()
    for _, f in ipairs(favorites) do addCard(f) end
    log(#favorites .. " favorites", C.green)
end

local function runSearch(append)
    if currentTab == "Favorites" then return renderFavorites() end
    local kw = searchBox.Text:match("^%s*(.-)%s*$")
    if kw == "" then return log("Isi keyword dulu.", C.yellow) end
    if searching then return end
    searching = true
    searchToken += 1
    local token = searchToken
    searchBtn.Text = "..."
    if append then page += 1 else page = 0; clearResults(); order = 0 end

    local list, hasMore, err = {}, false, nil
    local idStr = kw:match("^(%d+)$") or (kw:find("roblox.com", 1, true) and kw:match("(%d%d%d+)"))
    if idStr and not append then
        list = {{id = tonumber(idStr), name = "Asset " .. idStr, creator = "direct ID", kind = currentTab}}
    else
        local raw
        raw, hasMore, err = fetchPage(currentTab, kw, page)
        for _, it in ipairs(raw or {}) do
            local m = mapItem(it, currentTab)
            if m then list[#list + 1] = m end
        end
    end

    searching = false
    searchBtn.Text = "SEARCH"
    if token ~= searchToken then return end
    if #list == 0 then
        morePill.Visible = false
        if page == 0 then
            log("X NO RESULTS FOUND", C.red)
            if err then log(err, C.dim) end
        else
            log("! SERVER LIMIT REACHED", C.yellow)
        end
        return
    end
    for _, m in ipairs(list) do addCard(m) end
    log(page == 0 and ("FOUND " .. #list .. " results") or ("LOADED " .. #list .. " more"), C.green)
    morePill.Visible = hasMore
    moreBtn.Text = "v LOAD MORE  [Hal." .. (page + 1) .. "]"
end

searchBtn.MouseButton1Click:Connect(function() task.spawn(runSearch, false) end)
searchBox.FocusLost:Connect(function(enter) if enter then task.spawn(runSearch, false) end end)
moreBtn.MouseButton1Click:Connect(function() task.spawn(runSearch, true) end)

-- Tabs
local function setTab(name)
    currentTab = name
    for n, b in pairs(tabButtons) do
        b.BackgroundColor3 = (n == name) and C.accent or C.input
        b.TextColor3 = (n == name) and C.ink or C.sub
    end
    audioPages, httpCursor = nil, nil
    if name == "Favorites" then
        renderFavorites()
    else
        clearResults()
        order = 0
        if searchBox.Text ~= "" then task.spawn(runSearch, false) end
    end
end
for i, name in ipairs(TABS) do
    local b = new("TextButton", {
        LayoutOrder = i, Size = UDim2.new(0.2, -4, 1, 0), BackgroundColor3 = C.input, Text = TAB_NAMES[name],
        TextColor3 = C.sub, TextSize = 8.5, Font = Enum.Font.GothamBold, BorderSizePixel = 0, ZIndex = 4,
    }, tabBar)
    round(b, 6)
    tabButtons[name] = b
    b.MouseButton1Click:Connect(function() setTab(name) end)
end
setTab("Model")

-- =========================================================
-- TAB TOOLS: SCRIPT LIBRARY + SCANNER SCRIPT BERBAHAYA
-- =========================================================
local SCRIPT_LIB = {
    {name = "Pintu Otomatis", class = "Script", target = "part", partSize = Vector3.new(8, 10, 1),
     desc = "Pintu terbuka saat pemain mendekat, menutup lagi saat pergi.",
     code = [=====[
-- Pintu otomatis: terbuka saat pemain mendekat
local door = script.Parent
local range = 10
door.Anchored = true

local function setOpen(state)
	door.CanCollide = not state
	door.Transparency = state and 0.7 or 0
end

while true do
	local near = false
	for _, plr in ipairs(game.Players:GetPlayers()) do
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - door.Position).Magnitude <= range then
			near = true
			break
		end
	end
	setOpen(near)
	task.wait(0.3)
end
]=====]},
    {name = "Leaderstats (Coins)", class = "Script", target = "sss",
     desc = "Membuat papan skor dengan nilai Coins untuk setiap pemain.",
     code = [=====[
-- Leaderstats: papan skor di pojok kanan atas
game.Players.PlayerAdded:Connect(function(plr)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = plr

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = stats
end)
]=====]},
    {name = "Teleport Pad", class = "Script", target = "part", partSize = Vector3.new(6, 1, 6),
     desc = "Pindahkan pemain ke part bernama TujuanTeleport saat menyentuh.",
     code = [=====[
-- Teleport pad: buat part lain bernama "TujuanTeleport"
local pad = script.Parent
local targetName = "TujuanTeleport"
local cooldown = {}

pad.Touched:Connect(function(hit)
	local char = hit.Parent
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local target = workspace:FindFirstChild(targetName, true)
	if not hum or not root or not target or cooldown[char] then return end
	cooldown[char] = true
	root.CFrame = target.CFrame + Vector3.new(0, 4, 0)
	task.wait(2)
	cooldown[char] = nil
end)
]=====]},
    {name = "Kill Brick", class = "Script", target = "part", partSize = Vector3.new(8, 1, 8),
     desc = "Part yang membunuh pemain saat disentuh (lava, jurang, dll).",
     code = [=====[
-- Kill brick
script.Parent.Touched:Connect(function(hit)
	local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = 0
	end
end)
]=====]},
    {name = "Checkpoint", class = "Script", target = "part", partClass = "SpawnLocation", partSize = Vector3.new(8, 1, 8),
     desc = "Simpan titik respawn pemain saat menyentuh (butuh SpawnLocation).",
     code = [=====[
-- Checkpoint: pasang di dalam SpawnLocation
local checkpoint = script.Parent
checkpoint.Touched:Connect(function(hit)
	local plr = game.Players:GetPlayerFromCharacter(hit.Parent)
	if plr then
		plr.RespawnLocation = checkpoint
	end
end)
]=====]},
    {name = "Speed Pad", class = "Script", target = "part", partSize = Vector3.new(8, 1, 8),
     desc = "Pemain berlari lebih cepat selama beberapa detik.",
     code = [=====[
-- Speed pad
local pad = script.Parent
local boostSpeed, normalSpeed, duration = 50, 16, 5

pad.Touched:Connect(function(hit)
	local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
	if not hum or hum:GetAttribute("Boosted") then return end
	hum:SetAttribute("Boosted", true)
	hum.WalkSpeed = boostSpeed
	task.wait(duration)
	hum.WalkSpeed = normalSpeed
	hum:SetAttribute("Boosted", nil)
end)
]=====]},
    {name = "Jump Pad", class = "Script", target = "part", partSize = Vector3.new(6, 1, 6),
     desc = "Melontarkan pemain ke atas saat menyentuh part.",
     code = [=====[
-- Jump pad
local pad = script.Parent
local power = 90

pad.Touched:Connect(function(hit)
	local root = hit.Parent and hit.Parent:FindFirstChild("HumanoidRootPart")
	if root then
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, power, v.Z)
	end
end)
]=====]},
    {name = "Part Berputar", class = "Script", target = "part", partSize = Vector3.new(10, 1, 2),
     desc = "Memutar part terus-menerus (baling-baling, rintangan obby).",
     code = [=====[
-- Part berputar
local part = script.Parent
part.Anchored = true
local speed = 60 -- derajat per detik

game:GetService("RunService").Heartbeat:Connect(function(dt)
	part.CFrame = part.CFrame * CFrame.Angles(0, math.rad(speed * dt), 0)
end)
]=====]},
    {name = "Lampu Klik On/Off", class = "Script", target = "part", partSize = Vector3.new(2, 2, 2),
     desc = "Klik part untuk menyalakan atau mematikan lampu.",
     code = [=====[
-- Lampu on/off dengan ClickDetector
local part = script.Parent
local light = part:FindFirstChildOfClass("PointLight") or Instance.new("PointLight", part)
light.Range = 16
light.Enabled = false

local cd = part:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector", part)
cd.MouseClick:Connect(function()
	light.Enabled = not light.Enabled
	part.Material = light.Enabled and Enum.Material.Neon or Enum.Material.SmoothPlastic
end)
]=====]},
    {name = "Coin Pickup", class = "Script", target = "part", partSize = Vector3.new(2, 2, 0.4),
     desc = "Koin yang menambah Coins pemain (butuh script Leaderstats).",
     code = [=====[
-- Coin pickup: butuh leaderstats dengan nilai "Coins"
local coin = script.Parent
local value = 1
local busy = false

coin.Touched:Connect(function(hit)
	if busy then return end
	local plr = game.Players:GetPlayerFromCharacter(hit.Parent)
	local stats = plr and plr:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if not coins then return end
	busy = true
	coins.Value += value
	coin.Transparency = 1
	coin.CanCollide = false
	task.wait(5)
	coin.Transparency = 0
	busy = false
end)
]=====]},
    {name = "Warna Pelangi", class = "Script", target = "part", partSize = Vector3.new(6, 1, 6),
     desc = "Warna part berganti mengikuti warna pelangi.",
     code = [=====[
-- Part pelangi
local part = script.Parent
local hue = 0

while true do
	hue = (hue + 0.005) % 1
	part.Color = Color3.fromHSV(hue, 1, 1)
	task.wait(0.03)
end
]=====]},
    {name = "Sprint (Shift)", class = "LocalScript", target = "player",
     desc = "Tahan Shift kiri untuk berlari lebih cepat (PC).",
     code = [=====[
-- Sprint dengan LeftShift
local UIS = game:GetService("UserInputService")
local plr = game.Players.LocalPlayer
local walk, run = 16, 32

local function getHum()
	local c = plr.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		local h = getHum()
		if h then h.WalkSpeed = run end
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		local h = getHum()
		if h then h.WalkSpeed = walk end
	end
end)
]=====]},
    {name = "Tombol Menu GUI", class = "LocalScript", target = "player",
     desc = "Membuat tombol MENU yang membuka dan menutup sebuah frame.",
     code = [=====[
-- Tombol menu: buka / tutup frame
local plr = game.Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "MenuToggle"
gui.ResetOnSpawn = false
gui.Parent = plr:WaitForChild("PlayerGui")

local btn = Instance.new("TextButton")
btn.Size = UDim2.fromOffset(100, 36)
btn.Position = UDim2.new(0, 10, 0.5, 0)
btn.Text = "MENU"
btn.Parent = gui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(240, 160)
frame.Position = UDim2.new(0.5, -120, 0.5, -80)
frame.Visible = false
frame.Parent = gui

btn.MouseButton1Click:Connect(function()
	frame.Visible = not frame.Visible
end)
]=====]},
}

local function buildTools(host, ctx)
    local C = ctx.colors
    local Scanner = ctx.scanner
    local Selection = game:GetService("Selection")
    local TOP = 106

    local function copyText(t)
        local fn = setclipboard or toclipboard
        if fn then return (pcall(fn, t)) end
        return false
    end

    -- bar sub-tab
    local subBar = new("Frame", {Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, ctx.top), BackgroundTransparency = 1, ZIndex = 4}, host)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, subBar)
    local pane = new("Frame", {Size = UDim2.new(1, -16, 1, -(TOP + 26)), Position = UDim2.fromOffset(8, TOP), BackgroundTransparency = 1, ZIndex = 3, ClipsDescendants = true}, host)
    local status = new("TextLabel", {
        Size = UDim2.new(1, -16, 0, 16), Position = UDim2.new(0, 8, 1, -20), BackgroundTransparency = 1,
        Text = "", TextColor3 = C.sub, Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4,
    }, host)
    local function setStatus(text, color)
        status.Text = tostring(text)
        status.TextColor3 = color or C.sub
    end

    local libPane = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3}, pane)
    local scanPane = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Visible = false}, pane)

    local subButtons = {}
    local function showSub(name)
        libPane.Visible = (name == "Scripts")
        scanPane.Visible = (name == "Scanner")
        for n, b in pairs(subButtons) do
            b.BackgroundColor3 = (n == name) and C.accent or C.input
            b.TextColor3 = (n == name) and C.ink or C.sub
        end
    end
    for i, name in ipairs({"Scripts", "Scanner"}) do
        local b = new("TextButton", {
            LayoutOrder = i, Size = UDim2.new(0.5, -2, 1, 0), BackgroundColor3 = C.input,
            Text = (name == "Scripts") and "SCRIPT LIBRARY" or "SCANNER", TextColor3 = C.sub, TextSize = 9,
            Font = Enum.Font.GothamBold, BorderSizePixel = 0, ZIndex = 5,
        }, subBar)
        round(b, 6)
        subButtons[name] = b
        b.MouseButton1Click:Connect(function() showSub(name) end)
    end

    -- ===================== SCRIPT LIBRARY =====================
    local filterBar = new("Frame", {Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.input, BorderSizePixel = 0, ZIndex = 4}, libPane)
    round(filterBar, 8)
    local fStroke = stroke(filterBar, C.stroke, 1.2, 0.5)
    local filterBox = new("TextBox", {
        Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1, Text = "",
        PlaceholderText = "Cari script (door, teleport, gui...)", TextColor3 = C.text, PlaceholderColor3 = C.dim,
        TextSize = 10, Font = Enum.Font.Code, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, filterBar)
    filterBox.Focused:Connect(function() fStroke.Color = C.accent; fStroke.Transparency = 0 end)
    filterBox.FocusLost:Connect(function() fStroke.Color = C.stroke; fStroke.Transparency = 0.5 end)

    local libList = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 4,
    }, libPane)
    new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, libList)
    new("UIPadding", {PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6)}, libList)

    -- popup lihat kode
    local popup = new("Frame", {Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = C.header, BorderSizePixel = 0, Visible = false, ZIndex = 20}, host)
    round(popup, 10)
    stroke(popup, C.accent, 1.5)
    local popTitle = new("TextLabel", {Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 6), BackgroundTransparency = 1, Text = "", TextColor3 = C.accent2, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 21}, popup)
    local codeScroll = new("ScrollingFrame", {
        Size = UDim2.new(1, -16, 1, -72), Position = UDim2.fromOffset(8, 28), BackgroundColor3 = C.input, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 21,
    }, popup)
    round(codeScroll, 6)
    local codeBox = new("TextBox", {
        Size = UDim2.new(1, -8, 0, 0), Position = UDim2.fromOffset(4, 4), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        Text = "", TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 10, TextWrapped = true, MultiLine = true,
        ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 22,
    }, codeScroll)
    local popButtons = new("Frame", {Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0, 8, 1, -34), BackgroundTransparency = 1, ZIndex = 21}, popup)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, popButtons)
    local currentSnip

    local function makeBtn(parent, text, order, color, textColor, z)
        local b = new("TextButton", {
            LayoutOrder = order, Size = UDim2.new(1 / 3, -3, 1, 0), BackgroundColor3 = color or C.input, Text = text,
            TextColor3 = textColor or C.accent2, TextSize = 9, Font = Enum.Font.GothamBold, BorderSizePixel = 0, ZIndex = z or 6,
        }, parent)
        round(b, 5)
        return b
    end

    -- pasang script ke tempat yang sesuai
    local function resolveParent(snip)
        if snip.target == "sss" then
            return game:GetService("ServerScriptService")
        elseif snip.target == "player" then
            local sp = game:GetService("StarterPlayer")
            return sp:FindFirstChild("StarterPlayerScripts") or sp
        end
        local ok, sel = pcall(function() return Selection:Get() end)
        if ok and sel and sel[1] and sel[1]:IsA("BasePart") then return sel[1] end
        local part = new(snip.partClass or "Part", {Name = snip.name, Anchored = true, Size = snip.partSize or Vector3.new(6, 1, 6), CFrame = ctx.spawnCFrame()}, workspace)
        return part
    end

    local function insertSnippet(snip)
        local s = Instance.new(snip.class)
        s.Name = snip.name
        local okSrc = pcall(function() s.Source = snip.code end)
        if not okSrc then
            s:Destroy()
            local copied = copyText(snip.code)
            setStatus(copied and "Source tidak bisa ditulis, kode dicopy ke clipboard" or "Source tidak bisa ditulis, pakai LIHAT lalu salin manual", C.yellow)
            ctx.log("Script " .. snip.name .. ": tidak bisa di-insert langsung", C.yellow)
            return
        end
        local okP, parent = pcall(resolveParent, snip)
        if not okP or not parent then
            s:Destroy()
            setStatus("Gagal menentukan lokasi script", C.red)
            return
        end
        local okSet = pcall(function() s.Parent = parent end)
        if not okSet then
            s:Destroy()
            local copied = copyText(snip.code)
            setStatus(copied and "Lokasi tidak bisa diakses, kode dicopy" or "Lokasi tidak bisa diakses", C.yellow)
            return
        end
        ctx.selectObj(s)
        setStatus("OK " .. snip.name .. " > " .. parent.Name, C.green)
        ctx.log("OK Script " .. snip.name .. " > " .. parent.Name, C.green)
    end

    local function doCopy(snip)
        if copyText(snip.code) then
            setStatus("Kode " .. snip.name .. " dicopy", C.green)
        else
            setStatus("Executor tanpa clipboard: pakai LIHAT lalu salin manual", C.yellow)
        end
    end

    local function openPopup(snip)
        currentSnip = snip
        popTitle.Text = snip.name .. "  [" .. snip.class .. "]"
        codeBox.Text = snip.code
        codeScroll.CanvasPosition = Vector2.new(0, 0)
        popup.Visible = true
    end
    local pIns = makeBtn(popButtons, "INSERT", 1, C.accent, C.ink, 22)
    local pCopy = makeBtn(popButtons, "COPY", 2, C.input, C.accent2, 22)
    local pClose = makeBtn(popButtons, "TUTUP", 3, C.red, C.white, 22)
    pIns.MouseButton1Click:Connect(function() if currentSnip then task.spawn(insertSnippet, currentSnip) end end)
    pCopy.MouseButton1Click:Connect(function() if currentSnip then doCopy(currentSnip) end end)
    pClose.MouseButton1Click:Connect(function() popup.Visible = false end)

    local libCards = {}
    for i, snip in ipairs(SCRIPT_LIB) do
        local card = new("Frame", {Size = UDim2.new(1, 0, 0, 78), BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = i, ZIndex = 5}, libList)
        round(card, 8)
        stroke(card, C.stroke, 1, 0.5)
        new("TextLabel", {Size = UDim2.new(1, -112, 0, 14), Position = UDim2.fromOffset(8, 5), BackgroundTransparency = 1, Text = snip.name, TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6}, card)
        new("TextLabel", {Size = UDim2.fromOffset(96, 14), Position = UDim2.new(1, -102, 0, 5), BackgroundTransparency = 1, Text = snip.class, TextColor3 = C.accent, Font = Enum.Font.Code, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6}, card)
        new("TextLabel", {Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 21), BackgroundTransparency = 1, Text = snip.desc, TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 9, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 6}, card)
        local row = new("Frame", {Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 51), BackgroundTransparency = 1, ZIndex = 6}, card)
        new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, row)
        local ins = makeBtn(row, "INSERT", 1, C.accent, C.ink, 7)
        local cp = makeBtn(row, "COPY", 2, C.input, C.accent2, 7)
        local vw = makeBtn(row, "LIHAT", 3, C.input, C.accent2, 7)
        ins.MouseButton1Click:Connect(function() task.spawn(insertSnippet, snip) end)
        cp.MouseButton1Click:Connect(function() doCopy(snip) end)
        vw.MouseButton1Click:Connect(function() openPopup(snip) end)
        libCards[i] = {frame = card, key = (snip.name .. " " .. snip.desc .. " " .. snip.class):lower()}
    end
    local function applyFilter()
        local q = filterBox.Text:lower():match("^%s*(.-)%s*$")
        local shown = 0
        for _, c in ipairs(libCards) do
            local vis = (q == "") or (c.key:find(q, 1, true) ~= nil)
            c.frame.Visible = vis
            if vis then shown += 1 end
        end
        setStatus(shown .. " dari " .. #libCards .. " script", C.sub)
    end
    filterBox:GetPropertyChangedSignal("Text"):Connect(applyFilter)

    -- ===================== SCANNER =====================
    local LEVEL = {
        HIGH = {text = "BAHAYA", color = C.red},
        MED = {text = "CURIGA", color = C.cyan},
        LOW = {text = "CEK", color = C.yellow},
        UNKNOWN = {text = "?", color = C.dim},
    }
    local scanMode = "WORKSPACE"
    local scanning = false

    local row1 = new("Frame", {Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, ZIndex = 4}, scanPane)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, row1)
    local modeBtns = {}
    local function setScanMode(m)
        scanMode = m
        for n, b in pairs(modeBtns) do
            b.BackgroundColor3 = (n == m) and C.stroke or C.input
            b.TextColor3 = (n == m) and C.text or C.sub
        end
    end
    local modeDefs = {{"WORKSPACE", "WORKSPACE", 0.28}, {"SELECTED", "TERPILIH", 0.24}, {"ALL", "SEMUA", 0.2}}
    for i, d in ipairs(modeDefs) do
        local b = new("TextButton", {
            LayoutOrder = i, Size = UDim2.new(d[3], -3, 1, 0), BackgroundColor3 = C.input, Text = d[2], TextColor3 = C.sub,
            TextSize = 8.5, Font = Enum.Font.GothamBold, BorderSizePixel = 0, ZIndex = 5,
        }, row1)
        round(b, 6)
        modeBtns[d[1]] = b
        b.MouseButton1Click:Connect(function() setScanMode(d[1]) end)
    end
    local scanBtn = new("TextButton", {
        LayoutOrder = 4, Size = UDim2.new(0.28, -3, 1, 0), BackgroundColor3 = C.accent, Text = "SCAN", TextColor3 = C.ink,
        TextSize = 10, Font = Enum.Font.GothamBold, BorderSizePixel = 0, ZIndex = 5,
    }, row1)
    round(scanBtn, 6)

    local row2 = new("Frame", {Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 30), BackgroundTransparency = 1, ZIndex = 4}, scanPane)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, row2)
    local autoBtn = new("TextButton", {
        LayoutOrder = 1, Size = UDim2.new(0.5, -2, 1, 0), BackgroundColor3 = C.input, Text = "", TextSize = 8.5,
        Font = Enum.Font.GothamBold, BorderSizePixel = 0, ZIndex = 5,
    }, row2)
    round(autoBtn, 6)
    local function paintAuto()
        autoBtn.Text = Scanner.autoScan and "AUTO-SCAN INSERT: ON" or "AUTO-SCAN INSERT: OFF"
        autoBtn.TextColor3 = Scanner.autoScan and C.green or C.dim
    end
    paintAuto()
    autoBtn.MouseButton1Click:Connect(function() Scanner.autoScan = not Scanner.autoScan; paintAuto() end)
    local delBtn = new("TextButton", {
        LayoutOrder = 2, Size = UDim2.new(0.5, -2, 1, 0), BackgroundColor3 = C.input, Text = "HAPUS SEMUA BAHAYA", TextColor3 = C.red,
        TextSize = 8.5, Font = Enum.Font.GothamBold, BorderSizePixel = 0, ZIndex = 5,
    }, row2)
    round(delBtn, 6)

    local summary = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 58), BackgroundTransparency = 1,
        Text = "Belum ada hasil. Tekan SCAN.", TextColor3 = C.sub, Font = Enum.Font.GothamBold, TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4,
    }, scanPane)
    local scanList = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -78), Position = UDim2.fromOffset(0, 78), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 4,
    }, scanPane)
    new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, scanList)
    new("UIPadding", {PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6)}, scanList)

    local currentRes
    local function clearList()
        for _, c in ipairs(scanList:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
    end
    local function paintSummary(res)
        if not res then return end
        local alive = {high = 0, med = 0}
        for _, it in ipairs(res.items) do
            if it.obj and it.obj.Parent then
                if it.level == "HIGH" then alive.high += 1 elseif it.level == "MED" then alive.med += 1 end
            end
        end
        summary.Text = ("%d script dipindai | %d bahaya | %d curiga | %d tak terbaca"):format(res.total, alive.high, alive.med, res.unknown)
        summary.TextColor3 = (alive.high > 0 and C.red) or (alive.med > 0 and C.cyan) or C.green
    end

    local function render(res)
        currentRes = res
        clearList()
        paintSummary(res)
        if #res.items == 0 then
            new("TextLabel", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Text = "Bersih: tidak ada pola berbahaya ditemukan.", TextColor3 = C.green, Font = Enum.Font.Gotham, TextSize = 10, TextWrapped = true, ZIndex = 5}, scanList)
            return
        end
        for i, it in ipairs(res.items) do
            if i > 120 then
                new("TextLabel", {Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = i, Text = "... dan " .. (#res.items - 120) .. " temuan lain (tidak ditampilkan)", TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 9, ZIndex = 5}, scanList)
                break
            end
            local lv = LEVEL[it.level]
            local obj = it.obj
            local card = new("Frame", {Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = i, ZIndex = 5}, scanList)
            round(card, 8)
            stroke(card, lv.color, 1, 0.45)
            local badge = new("TextLabel", {Size = UDim2.fromOffset(50, 16), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = lv.color, Text = lv.text, TextColor3 = C.ink, Font = Enum.Font.GothamBold, TextSize = 8.5, BorderSizePixel = 0, ZIndex = 6}, card)
            round(badge, 4)
            local pname = obj.Parent and obj.Parent.Name or "?"
            new("TextLabel", {Size = UDim2.new(1, -68, 0, 16), Position = UDim2.fromOffset(62, 6), BackgroundTransparency = 1, Text = ("%s (%s) < %s"):format(obj.Name, obj.ClassName, pname), TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6}, card)
            new("TextLabel", {Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, 24), BackgroundTransparency = 1, Text = table.concat(it.reasons, "; "), TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 9, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 6}, card)
            local brow = new("Frame", {Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(6, 49), BackgroundTransparency = 1, ZIndex = 6}, card)
            new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, brow)
            local sel = new("TextButton", {LayoutOrder = 1, Size = UDim2.new(0.5, -2, 1, 0), BackgroundColor3 = C.input, Text = "PILIH", TextColor3 = C.accent2, TextSize = 9, Font = Enum.Font.GothamBold, BorderSizePixel = 0, ZIndex = 7}, brow)
            round(sel, 5)
            local del = new("TextButton", {LayoutOrder = 2, Size = UDim2.new(0.5, -2, 1, 0), BackgroundColor3 = C.input, Text = "HAPUS", TextColor3 = C.red, TextSize = 9, Font = Enum.Font.GothamBold, BorderSizePixel = 0, ZIndex = 7}, brow)
            round(del, 5)
            sel.MouseButton1Click:Connect(function()
                if obj.Parent then
                    ctx.selectObj(obj)
                    setStatus(obj:GetFullName(), C.sub)
                else
                    setStatus("Script sudah tidak ada", C.dim)
                end
            end)
            del.MouseButton1Click:Connect(function()
                if pcall(function() obj:Destroy() end) then
                    card:Destroy()
                    paintSummary(currentRes)
                    setStatus("Script dihapus: " .. obj.Name, C.green)
                else
                    setStatus("Gagal menghapus script", C.red)
                end
            end)
        end
    end

    local function getRoots(m)
        if m == "WORKSPACE" then return {workspace} end
        if m == "SELECTED" then
            local ok, sel = pcall(function() return Selection:Get() end)
            return (ok and sel) or {}
        end
        local roots = {}
        for _, name in ipairs({"Workspace", "Lighting", "ReplicatedFirst", "ReplicatedStorage", "StarterGui", "StarterPack", "StarterPlayer", "ServerScriptService", "ServerStorage"}) do
            local ok, svc = pcall(function() return game:GetService(name) end)
            if ok and svc then roots[#roots + 1] = svc end
        end
        return roots
    end

    local function runScan()
        if scanning then return end
        local roots = getRoots(scanMode)
        if #roots == 0 then
            setStatus("Tidak ada objek terpilih. Pilih model dulu.", C.yellow)
            return
        end
        scanning = true
        scanBtn.Text = "..."
        setStatus("Memindai script...", C.text)
        local ok, res = pcall(Scanner.scan, roots, ctx.gui, function(i, n)
            setStatus(("Memindai %d / %d script..."):format(i, n), C.text)
        end)
        scanning = false
        scanBtn.Text = "SCAN"
        if not ok then
            setStatus("Scan gagal: " .. tostring(res):sub(1, 60), C.red)
            return
        end
        render(res)
        setStatus(res.high > 0 and "Ditemukan script berbahaya!" or "Scan selesai", res.high > 0 and C.red or C.green)
    end
    scanBtn.MouseButton1Click:Connect(function() task.spawn(runScan) end)

    local armed = false
    delBtn.MouseButton1Click:Connect(function()
        if not currentRes then return setStatus("Belum ada hasil scan", C.yellow) end
        if not armed then
            armed = true
            delBtn.Text = "YAKIN? TAP LAGI"
            task.delay(3, function()
                armed = false
                delBtn.Text = "HAPUS SEMUA BAHAYA"
            end)
            return
        end
        armed = false
        delBtn.Text = "HAPUS SEMUA BAHAYA"
        local n = 0
        for _, it in ipairs(currentRes.items) do
            if it.level == "HIGH" and it.obj and it.obj.Parent then
                if pcall(function() it.obj:Destroy() end) then n += 1 end
            end
        end
        render(currentRes)
        setStatus(n .. " script berbahaya dihapus", C.green)
    end)

    setScanMode("WORKSPACE")
    showSub("Scripts")
    applyFilter()

    return {
        -- dipanggil otomatis setelah insert model (hasil auto-scan)
        render = function(res)
            render(res)
            showSub("Scanner")
        end,
        setStatus = setStatus,
    }
end

-- =========================================================
-- IMPORT FILE (panel kedua) + tampilkan
-- =========================================================
local okImp, impApi = pcall(buildImporter, impView, {
    player = player, gui = gui, top = 50 + TB_OFF, colors = C, accessInfo = accessInfo,
})
if okImp and type(impApi) == "table" then
    onImportOpen = impApi.refresh
else
    log("X Panel import gagal dimuat: " .. tostring(impApi):sub(1, 60), C.red)
    new("TextLabel", {
        Size = UDim2.new(1, -24, 0, 70), Position = UDim2.fromOffset(12, 50 + TB_OFF), BackgroundTransparency = 1,
        Text = "Panel import gagal dimuat.\n" .. tostring(impApi):sub(1, 140), TextColor3 = C.red,
        Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
    }, impView)
end

-- TAB TOOLS (Script Library + Scanner)
local okTools, toolsApi = pcall(buildTools, toolsView, {
    colors = C, scanner = Scanner, gui = gui, top = 50 + TB_OFF,
    log = log, selectObj = selectObj, spawnCFrame = spawnCFrame,
})
if okTools and type(toolsApi) == "table" then
    Scanner.onResult = function(res)
        toolsApi.render(res)
        if res.high > 0 and not toolsView.Visible and modeButtons.Tools then
            modeButtons.Tools.Text = "TOOLS !"
        end
    end
else
    log("X Panel tools gagal dimuat: " .. tostring(toolsApi):sub(1, 60), C.red)
    new("TextLabel", {
        Size = UDim2.new(1, -24, 0, 70), Position = UDim2.fromOffset(12, 50 + TB_OFF), BackgroundTransparency = 1,
        Text = "Panel tools gagal dimuat.\n" .. tostring(toolsApi):sub(1, 140), TextColor3 = C.red,
        Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
    }, toolsView)
end

setMode("Toolbox")

UIS.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightShift then toggleMain() end
end)

main.Visible = false
openMain()

log("BALEREOT COMMUNITY READY", C.green)
log("Klik BC (atau RightShift) untuk show/hide", C.sub)
log(accessInfo ~= "" and accessInfo or "Akses aktif", C.yellow)
if accessTag == "TRIAL" then
    log("Setelah trial habis, wajib pakai key (GET KEY di Discord)", C.sub)
end

-- akses berbatas waktu: panel ditutup otomatis saat habis
if accessExpiry then
    task.delay(math.max(1, accessExpiry - nowTs()), function() gui:Destroy() end)
end

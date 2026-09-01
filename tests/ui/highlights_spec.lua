local highlights = require "if.db.ui.highlights"

local function bg_of(name)
  local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
  return hl.bg and string.format("#%06x", hl.bg) or nil
end

local function channels(hex)
  hex = hex:gsub("^#", "")
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

local function luminance(hex)
  local r, g, b = channels(hex)
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

---@return number|nil hue in degrees, nil when the colour is grey
local function hue(hex)
  local r, g, b = channels(hex)
  r, g, b = r / 255, g / 255, b / 255
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  local c = mx - mn
  if c < 1e-9 then
    return nil
  end
  local h
  if mx == r then
    h = ((g - b) / c) % 6
  elseif mx == g then
    h = (b - r) / c + 2
  else
    h = (r - g) / c + 4
  end
  return h * 60
end

---Smallest angle between two hues, or 0 when either is grey.
local function hue_drift(a, b)
  local ha, hb = hue(a), hue(b)
  if not ha or not hb then
    return 0
  end
  local d = math.abs(ha - hb) % 360
  return math.min(d, 360 - d)
end

---@param bg string
local function stripes_for(bg)
  vim.api.nvim_set_hl(0, "Normal", { bg = bg })
  highlights.setup()
  return bg_of "IfDbRowOdd", bg_of "IfDbRowEven"
end

describe("highlights", function()
  describe("row stripes", function()
    local WARM = {
      ["solarized light"] = "#fdf6e3",
      ["gruvbox light"] = "#fbf1c7",
      ["rose-pine dawn"] = "#faf4ed",
      sepia = "#f4ecd8",
    }

    it("keeps a warm background warm", function()
      for name, bg in pairs(WARM) do
        local odd, even = stripes_for(bg)
        assert.is_true(hue_drift(bg, odd) < 8, name .. " odd drifted to " .. odd)
        assert.is_true(hue_drift(bg, even) < 8, name .. " even drifted to " .. even)
      end
    end)

    it("does not favour one channel over the others", function()
      -- The old implementation added an extra 15 to blue alone, which read
      -- as intended on a dark blue theme and as magenta on a cream one.
      for name, bg in pairs(WARM) do
        local _, even = stripes_for(bg)
        local br, bgc, bb = channels(bg)
        local er, eg, eb = channels(even)
        local deltas = { er - br, eg - bgc, eb - bb }
        table.sort(deltas)
        assert.is_true(deltas[3] - deltas[1] < 8, name .. " channels moved unevenly: " .. even)
      end
    end)

    it("gives every stripe somewhere to go", function()
      -- Both extremes used to clip: a white theme lost its stripe entirely.
      for _, bg in ipairs { "#ffffff", "#000000", "#fafafa", "#1e222a" } do
        local odd, even = stripes_for(bg)
        assert.is_not_nil(odd)
        assert.is_not_nil(even)
        assert.are_not.equal(bg, odd)
        assert.are_not.equal(bg, even)
        assert.are_not.equal(odd, even)
      end
    end)

    it("darkens on a light theme and lightens on a dark one", function()
      local odd = stripes_for "#fdf6e3"
      assert.is_true(luminance(odd) < luminance "#fdf6e3")

      odd = stripes_for "#1e222a"
      assert.is_true(luminance(odd) > luminance "#1e222a")
    end)

    it("keeps the two stripes far enough apart to read", function()
      for _, bg in ipairs { "#ffffff", "#000000", "#fdf6e3", "#1e222a" } do
        local odd, even = stripes_for(bg)
        assert.is_true(math.abs(luminance(even) - luminance(odd)) > 5, "gap too small on " .. bg)
      end
    end)

    it("falls back to CursorLine when Normal is transparent", function()
      vim.api.nvim_set_hl(0, "Normal", {})
      vim.api.nvim_set_hl(0, "CursorLine", { bg = "#2a2a2a" })
      highlights.setup()
      assert.is_not_nil(bg_of "IfDbRowOdd")
      assert.are_not.equal(bg_of "IfDbRowOdd", bg_of "IfDbRowEven")
    end)
  end)

  describe("colorscheme changes", function()
    it("reapplies every group, since :colorscheme clears them", function()
      vim.api.nvim_set_hl(0, "Normal", { bg = "#1e222a" })
      highlights.setup()
      assert.is_not_nil(bg_of "IfDbRowOdd")

      vim.cmd "colorscheme habamax"

      assert.is_not_nil(bg_of "IfDbRowOdd")
      assert.is_not_nil(bg_of "IfDbRowEven")
      assert.is_not_nil(bg_of "IfDbHeader")
      -- Linked groups go the same way and have to come back too.
      assert.is_false(vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = "IfDbNull", link = false })))
    end)

    it("registers exactly one autocmd however many times setup runs", function()
      highlights.setup()
      highlights.setup()
      highlights.setup()
      local autocmds = vim.api.nvim_get_autocmds { group = "IfDbHighlights", event = "ColorScheme" }
      assert.are.equal(1, #autocmds)
    end)
  end)

  describe("user overrides", function()
    it("wins over the computed value", function()
      require("if.db.config").setup { highlights = { IfDbRowOdd = { bg = "#ff6600" } } }
      vim.api.nvim_set_hl(0, "Normal", { bg = "#1e222a" })
      highlights.setup()
      assert.are.equal("#ff6600", bg_of "IfDbRowOdd")

      require("if.db.config").setup {}
    end)

    it("survives a colorscheme change", function()
      require("if.db.config").setup { highlights = { IfDbRowOdd = { bg = "#ff6600" } } }
      highlights.setup()
      vim.cmd "colorscheme habamax"
      assert.are.equal("#ff6600", bg_of "IfDbRowOdd")

      require("if.db.config").setup {}
    end)
  end)
end)

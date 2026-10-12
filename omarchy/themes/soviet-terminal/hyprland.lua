-- Soviet Terminal: bordas finas e sólidas, cantos retos, sem sombra nem blur.
local active_border_color = "rgb(718D58)"
local inactive_border_color = "rgb(444B42)"

hl.config({
  general = {
    border_size = 1,
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },
  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },
  decoration = {
    rounding = 0,
    shadow = { enabled = false },
    blur = { enabled = false },
  },
})

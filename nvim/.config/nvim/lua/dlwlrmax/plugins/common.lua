local hlslensSet, hlslens = pcall(require, 'hlslens')
if not hlslensSet then
    return
else
    hlslens.setup()
end

local transSet, translate = pcall(require, "translate")

if not transSet then
  return
else
    translate.setup({})
end

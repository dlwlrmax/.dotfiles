local setup, scrollbar = pcall(require, "scrollbar")
if not setup then
  return
end

scrollbar.setup()

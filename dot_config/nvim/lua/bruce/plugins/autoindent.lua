local setup, autoindent = pcall(require, "autoindent")
if not setup then
  return
end

autoindent.setup()


return {
  entry = function()
    local handle = io.popen("fd --type f | fzf --preview 'cat {}'", "r")
    if not handle then
      return
    end

    local result = handle:read("*a")
    handle:close()

    if not result then
      return
    end

    result = result:gsub("%s+$", "")
    if result == "" then
      return
    end

    ya.manager_emit("reveal", { result })
  end
}

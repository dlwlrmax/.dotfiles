local setup, peepsight = pcall(require, "peepsight")
if not setup then
  return
end

peepsight.setup({
  -- go
  "function_declaration",
  "method_declaration",
  "func_literal",

  -- typescript
  "class_declaration",
  "method_definition",
  "arrow_function",
  "function_declaration",
  "generator_function_declaration"
})

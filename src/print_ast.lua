local function tprint(t, k, indent)
  local heading = k and string.rep("  ", indent) .. tostring(k) .. ": "
  if type(t) == "table" then
    if heading then print(heading) end
    for k, v in ipairs(t) do
      tprint(v, k, (indent or 0) + 1)
    end
  else
    print((heading or "") .. tostring(t))
  end
end

return tprint

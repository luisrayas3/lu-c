local function tprint(t, k, indent)
  local indentstr = indent and string.rep("  ", indent) or ""
  local heading = indentstr .. ((k ~= nil) and tostring(k) .. " = " or "")
  if type(t) == "table" then
    print(heading .. "{")
    for k, v in pairs(t) do
      tprint(v, k, (indent or 0) + 1)
    end
    print(indentstr .. "}")
  else
    print(heading .. tostring(t))
  end
end

return tprint

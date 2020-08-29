local function tprint(t, indent, k)
  if not indent then indent = 0 end
  if k == nil then k = "" end
  heading = string.rep("  ", indent) .. k .. ": "
  if type(t) == "table" then
    print(heading)
    for k, v in ipairs(t) do
      tprint(v, indent + 1, k)
    end
  else
    print(heading .. t)
  end
end

return tprint

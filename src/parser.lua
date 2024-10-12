local lpeg = require "lpeg"

local P, S, V = lpeg.P, lpeg.S, lpeg.V
local C, Cc = lpeg.C, lpeg.Cc


local match_stats = {
  clear = function(self)
    self.furthest_match = 0
    self.furthest_match_subject = nil
  end;
}
local log = lpeg.Cmt(P(true), function(subject, pos, ...)
  if pos > match_stats.furthest_match then
    match_stats.furthest_match = pos
    match_stats.furthest_match_subject = subject
  end
  return true
end)
match_stats:clear()


-- Names
local locale = lpeg.locale()
local namechar = locale.alnum + P "_"
local nameinit = namechar - locale.digit
-- Whitespace
local w = locale.space ^ 0  -- optional whitespace
-- Strings
local quote = P '"'
local escapes
    = P "\\" * quote
    + P "\\" * S "\\nrt"
    + P "\\" * P "x" * S "01233456789ABCDEF"^-4  -- hex
    + P "\\" * P "o" * S "01234567"^-3  -- octal
    -- + P "\\" * unknown_escape

local function head(op, ...) return {op, ...} end
local function infix(lhs, op, ...) return {op, lhs, ...} end
local function list(...) return {...} end

local function left_to_right(lhs, op, rhs, ...)
  if op == nil then return lhs end
  return left_to_right({op, lhs, rhs}, ...)
end
local function un_right_to_left(token, next_token, ...)
  if next_token == nil then return token end
  return {token, un_right_to_left(next_token, ...)}
end

local function chain_binary_op(op, node, rnode)
  if rnode == nil then rnode = node end
  return node * (w * op * w * rnode) ^ 0 / left_to_right
end
local function single_binary_op(op, node)
  return node * (w * op * w * node) ^ -1 / left_to_right
end
local function chain_prefix_op(op, node)
  return (op * w) ^ 0 * node / un_right_to_left
end

local function optional(node)
  return node + C ""
end
local function comma_separated(node)
  -- Optional trailing comma
  return (w * node * (w * P "," * w * node) ^ 0 * (w * P ",") ^ -1) ^ -1 * w / list
end
local function semicolon_separated(node)
  return (w * node * w * P ";") ^ 0 * w / list
end

local keywords = P(-1)
local function K(k)
  keyword = k * -namechar
  keywords = keywords + keyword
  return C(keyword)
end

local if_kw, else_kw = K "if", K "else"
local function if_selected(node, if_selected_node)
  -- TODO: support leading ? or !
  local if_expr = P "(" * w * V "val_expr" * w * P ")";
  local else_block = else_kw * w * if_selected_node / head;
  return
      if_kw * w * if_expr * w * node * optional(w * else_block) / head
      + node
      ;
end

local where_kw = K "where"
local function with_where(node)
  local where_block = P "{" * semicolon_separated(V "chunk_stmt") * P "}";
  return
      node * w * where_kw * w * where_block / infix
      + node
      ;
end
local function atomic(node)
  return P "(" * w * with_where(node) * w * P ")"
end

local un_op = C "?" + C "!" + C "+" + C "-" * C "*" * C "/" * C "~"

-- Binary operators from highest to lowest precedence

-- local exp_op = C "^"  -- Just use `pow`
local mul_op = C "*" + C "//" + C "/" + C "%" + C "/%"
local add_op = C "+" + C "-"

local bit_and_op = C "&"
local bit_xor_op = C "^"  -- "~="?
local bit_or_op = C "|"

local lt_op = C "<" + C "<="  -- Same precedence as gt
local gt_op = C ">" + C ">="
local eq_op = C "=="
local neq_op = C "!="

local and_op = K "and"
local xor_op = K "xor"
local or_op = K "or"

local func_type_op = C "->" + C "=>"

local assg_op = C "=" + C "+=" + C "-=" + C "*=" + C "//=" + C "/=" + C "%="

local grammar = {
  semicolon_separated(V "chunk_stmt" * log) * -1 * log;  -- TODO: put this at leafs, not root

  -- Declarations --

  chunk_stmt  -- TODO: where in type literal and typed literal should not come after def body
      = V "name" * w * C "::" * w * with_where(V "type_expr") / infix
      + V "name" * w * Cc ":=" * P ":" * w * V "func_def" / infix
      + V "name" * w * Cc ":=" * P ":" * w * V "decl_def" / infix
      + V "pure_decl"
      ;
  decl_def = V "decl_typing" * w * P "=" * w * with_where(V "val_expr");
  decl_typing = optional(with_where(V "type_expr"));
  pure_decl = V "name" * w * C ":" * w * with_where(V "type_expr") / infix;

  -- Type expressions --

  type_expr = if_selected(V "type_term", V "type_expr");
  type_term
      = V "type_literal"
      + V "func_call"
      + V "type_atom"
      ;
  type_literal
      = V "func_type"
      + K "enum" * w * P "{" * semicolon_separated(V "enum_def") * P "}" / head
      + K "union" * w * P "{" * semicolon_separated(V "pure_decl") * P "}" / head
      + K "struct" * w * P "{" * semicolon_separated(V "pure_decl") * P "}" / head
      ;
  func_type = V "param_types" * w * func_type_op * w * V "type_expr" / infix;
  param_types = P "(" * comma_separated(V "param_type") * P ")";
  param_type = V "pure_decl" + V "unnamed_param_type";
  unnamed_param_type = Cc "" * Cc ":" * with_where(V "type_expr") / infix;
  enum_def = V "name" * w * C "=" * w * with_where(V "val_expr") / infix;
  type_atom
      = V "name"
      + atomic(V "type_expr")
      ;

  -- Value expressions --

  val_expr = if_selected(V "val_term", V "val_expr");
  -- TODO: Support prefixing and/xor/or
  val_term = chain_binary_op(or_op, V "or_term");
  or_term = chain_binary_op(xor_op, V "xor_term");
  xor_term = chain_binary_op(and_op, V "and_term");
  and_term
      = chain_binary_op(eq_op, V "eq_term")
      + single_binary_op(neq_op, V "eq_term");
  eq_term
      = chain_binary_op(lt_op, V "comp_term")
      + chain_binary_op(gt_op, V "comp_term");
  comp_term = chain_binary_op(bit_or_op, V "bit_or_term");
  bit_or_term = chain_binary_op(bit_xor_op, V "bit_xor_term");
  bit_xor_term = chain_binary_op(bit_and_op, V "bit_and_term");
  bit_and_term = chain_binary_op(add_op, V "add_term");
  add_term = chain_binary_op(mul_op, V "mul_term");
  mul_term = chain_prefix_op(un_op, V "un_term");
  un_term = V "func_call" + V "val_atom";
  func_call = V "callable_atom" * (w * Cc "()" * V "args") ^ 1 / left_to_right;
  args = P "(" * comma_separated(V "val_expr") * P ")";
  val_atom = V "callable_atom" + V "non_callable_atom";
  callable_atom
      = V "func_literal"
      + V "name"
      + atomic(V "val_expr")
      ;
  non_callable_atom
      = V "num_literal"
      -- + V "str_literal"
      ;

  -- Function definitions --

  func_def = with_where(V "func_def_type") * w * V "func_def_block";
  func_def_type = V "params" * w * func_type_op * w * V "type_expr" / infix;
  params = P "(" * comma_separated(V "param_decl") * P ")";
  param_decl = V "pure_decl" + V "untyped_param_decl";
  untyped_param_decl = V "name" * Cc ":" * Cc "" / infix;
  func_def_block
      = V "value_func_def"
      + V "stmt_block"
      ;
  value_func_def = C "==" * w * with_where(V "val_expr") / head;
  stmt_block = Cc "{}" * P "{" * semicolon_separated(V "inner_stmt") * P "}" / head;
  inner_stmt
      = V "chunk_stmt"
      + V "effect_stmt"
      ;
  effect_stmt = if_selected(V "effect_stmt_term", V "effect_stmt");
  effect_stmt_term
      = K "return" * optional(w * with_where(V "val_expr")) / head
      + K "do" * w * (V "stmt_block" + with_where(V "func_call")) / infix
      + V "lval_expr" * w * assg_op * w * with_where(V "val_expr") / infix
      ;
  lval_expr = V "name";  -- TODO: Pointers & indexes

  -- Value literals --

  func_literal = Cc "->{}" * V "func_def" / head;
  num_literal = locale.digit ^ 1 / tonumber; -- TODO: Hex, octal, etc.
  str_literal = Cc '""' * quote * C((escapes + P(1) - quote) ^ 0) * quote / head;
  -- array_literal = ;

  -- Must be the last pattern defined to use complete keywords pattern
  keyword = keywords;
  name = C(nameinit * namechar ^ 0 - V "keyword");
}

return function () return P(grammar), grammar, match_stats end

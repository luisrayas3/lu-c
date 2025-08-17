local table = require "table"


local function FunctionDef(t)
  return {
    node_type = "stmt";
    node_subtype = "FunctionDef";
    properties = t;
  }
end
local function ReturnStmt(t)
  return {
    node_type = "stmt";
    node_subtype = "ReturnStmt";
    properties = t;
  }
end
local function BuiltinOp(t)
  -- name: str, e.g. '+'
  -- args: {expr}
  return {
    node_type = "expr";
    node_subtype = "BuiltinOp";
    properties = t;
  }
end
local function FunctionCall(t)
  return {
    node_type = "expr";
    node_subtype = "FunctionCall";
    properties = t;
  }
end
local function VariableRef(t)
  return {
    node_type = "expr";
    node_subtype = "VariableRef";
    properties = t;
  }
end


local function traverse(ast)
  local node_type = ast[1]
  if node_type == "+" then
    return BuiltinOp {
      name = "+";
      args = {
        traverse(ast[2]),
        traverse(ast[3]),
      };
    }
  end
end


return {
  c_ast_from_luc_ast = traverse;
  FunctionDef = FunctionDef;
  ReturnStmt = ReturnStmt;
  BuiltinOp = BuiltinOp;
  FunctionCall = FunctionCall;
  VariableRef = VariableRef;
}

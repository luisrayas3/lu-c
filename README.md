# lu-c

## Installing

```sh
brew install lua
brew install luarocks
luarocks install lpeg
luarocks install busted  # tests only
```

## Running tests

```sh
busted tests/*_test.lua
```

## Core type hierarchy

```
type
 |- enum (parameterized by type)
 |- union (parameterized by type)
 |- struct
 |- function (->, =>, @>)
 |- numeric (int, float, ...)
 |- sequence ([], generators/[...]?)
 |- pointer (@)
```

Properties of a "type":

1. data specification
  a. alignment
  b. size
  c. deletion semantics?
2. interface specification
  a. class membership



## Grammar

### Doc comments

```
Point :: struct  #(
  Points represent a 3D location in cartesian space.
) {
  x: int  #( x-axis location );
  y: int  #(...);
  z: int  #(...);
};
```

### Generic manipulation of statements, types, and values

```
if (this ?= that) do {
  goSomewhere();
} else do {
  print("uneq");
};

x = if (this ?= that) "eq" else "uneq";

Number (integral: bool = false) :: if (integral) int else double;
```

### Options idiom

```
f: (x: int, y: int, opts: Options = {}) => int
where {
  Options :: struct {
    use_algorithm_z: bool = true;
  };
};
```

TODO: Why is the above better than many default args?

### Is != or xor better?

 - xor is more clearly a boolean operator
 - != is more consistent with words -> "lazy" mental shortcut
 - != results in one less operator

```
if (some_thing < 100 xor the_other_thing `hasQuality`) do {
  do createStuff();
}
```

### Type functions

```
Map (T) (max_itr :int) :(l :T) => T
where { T }
{ ... }
```

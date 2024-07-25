# Syntax reference

## Replacement fields

Tokens in the form `$(expr)` are replaced with the value of `expr`,
converted into a string.

`expr` can be any valid Lua expression that evaluates to something, like
a variable or a function call.

Multiple tokens can appear on a single line.

For example:

```
Hello $(whom) !
```
or
```
<div style="font-size:$(fsize())pt;color:$(color)">
```

The format of replacement fields can be changed to `«expr»` using the
option `xtendStyle`, as in

```Lua
engine.tload("Hello «whom»!", {xtendStyle=true}, {whom="world"})
```

### Conversion to string

Converting (the result of) any expression into text, is always delegated
to the `mytostring` function in the environment given to `tload`.

If the environment does not have such a key, then Lua's default
`tostring` is used.


## Table expansion

A token in the form `${expr}` is expanded with a new line for every item
in `expr`.

`expr` must evaluate to an array of strings, or to a function returning
an iterator factory (e.g. a function returning `ipairs(aTable)`).

The token must appear alone in the line of the template. Its indentation
is respected, and reproduced for each line of the expansion.

For example:

```
line 1
   ${aTable}
line N
```

will evaluate to something like

```
line 1
   table element 1
   table element 2
   ...
line N
```

## Template inclusion

Tokens in the form `$<name>` will attempt to include the template called
`name` at the location of the token.

As for table expansion, the token must be alone on the line and its
indentation is preserved.

```
First line
    $<include_me>
more text
$<include_me>
last line
```

Inclusion is similar to copy&paste of the text of the included template.

The referenced templates must be given as arguments when `tload`ing the
primary template, as in:

```Lua
tload(<template>, <options>, <environment>, {include_me=<another template>})
```

## Code statements

Lines starting with `@` (with any leading space) are considered Lua code,
and will be evaluated in the environment bound to the template, like all
the other tokens like replacement fields. Regular Lua syntax must
be respected (e.g. a `for` loop must be closed by an `end`).

For example:

```
Actual Lua code can be used in the template, starting the line with a '@':
@ for k,v in pairs( aTable ) do
key: $(k)    value: $(v)
@ end
```

## Quoting

All the special tokens described so far can be quoted, to prevent
expansion and have them appear verbatim in the evaluated template.



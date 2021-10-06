# ContentHashes

A generic object hashing implementation that hashes the exact content of
objects in *all* cases rather than using the (much faster) `objectid`. This can
be useful when you want to know whether two distinct objects do in fact contain
the same content without having to implement custom `Base.hash` methods that do
the comparisons manually. You may also not actually "own" the types which you
would need to implement `Base.hash` for, which would be type-piracy.

## Usage

Use the `ContentHashes.hash` function to hash any objects. This `hash` function
is not exported so that it won't conflict with the `Base.hash` function.

```
julia> using ContentHashes

julia> struct T
           x
       end

julia> a = T([]);

julia> b = T([]);

julia> hash(a) === hash(b)
false

julia> ContentHashes.hash(a) === ContentHashes.hash(b)
true

julia> f = x -> x + 1
#1 (generic function with 1 method)

julia> g = x -> x + 1
#3 (generic function with 1 method)

julia> hash(f) === hash(g)
false

julia> ContentHashes.hash(f) === ContentHashes.hash(g)
true
```


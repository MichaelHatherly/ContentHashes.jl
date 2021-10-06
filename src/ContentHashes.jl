module ContentHashes

# Imports:

import Serialization
import SHA


# Public interface:

"""
    hash(object, [seed])::SHA1

Return a `SHA1` hash of the *contents* of `object`, with an optional `seed`.

!!! warn

    This `hash` implementation is *much slower* that the default `Base.hash`
    provided for `object` and as such should only be used when a hash of the exact
    contents of an object is actually required.
"""
@noinline function hash(@nospecialize(object), seed::Integer = zero(UInt))
    ctx = SHA.SHA1_CTX()
    SHA.update!(ctx, reinterpret(UInt8, [convert(UInt, seed)]))
    Serialization.serialize(CustomSerializer{HashContext}(HashContext(ctx)), object)
    return Base.SHA1(SHA.digest!(ctx))
end


# Implementation:

# A special type of IO that is actually a hash accumulator for use in the
# Serialization implementation found below.
struct HashContext <: IO
    ctx::SHA.SHA1_CTX
end

function Base.unsafe_write(io::HashContext, ptr::Ptr{UInt8}, nb::UInt)
    for _ in 1:nb
        SHA.update!(io.ctx, (unsafe_load(ptr),))
        ptr += 1
    end
    return nb
end
Base.write(io::HashContext, u::UInt8) = SHA.update!(io.ctx, (u,))

# The custom serializer used to produce a hash of an object by traversing it in
# the same way the Julia's Serialization would do, but outputting only a
# singular hash value rather than serialized data.
mutable struct CustomSerializer{I<:IO} <: Serialization.AbstractSerializer
    io::I
    counter::Int
    table::IdDict{Any,Any}
    pending_refs::Vector{Int}
    known_object_data::Dict{UInt64,Any}
    CustomSerializer{I}(io::I) where I<:IO = new(io, 0, IdDict(), Int[], Dict{UInt64,Any}())
end

function Serialization.serialize(cs::CustomSerializer, tn::Core.TypeName)
    if !Serialization.serialize_cycle(cs, tn)
        if startswith(String(tn.name), '#')
            obj = getfield(tn.module, tn.name)
            if isdefined(obj, :instance)
                for ci in code_lowered(obj.instance)
                    Serialization.serialize(cs, ci.code)
                end
                return nothing
            end
        end
        Serialization.writetag(cs.io, Serialization.TYPENAME_TAG)
        Serialization.write(cs.io, Serialization.object_number(cs, tn))
        Serialization.serialize_typename(cs, tn)
    end
    return nothing
end

# Drop line number information.
Serialization.serialize(::CustomSerializer, ::Core.LineInfoNode) = nothing
Serialization.serialize(::CustomSerializer, ::LineNumberNode) = nothing

# Remove gensym counter information.
function Serialization.serialize(cs::CustomSerializer, s::Symbol)
    str = String(s)
    s = contains(str, '#') ? Symbol(rstrip(isdigit, str)) : s # Global counter isn't needed for hashing here.
    return invoke(Serialization.serialize, Tuple{Serialization.AbstractSerializer, Symbol}, cs, s)
end
function Serialization.serialize(cs::CustomSerializer, s::Module)
    is_pluto_workspace = isdefined(s, :PlutoRunner) && isa(s.PlutoRunner, Module)
    s = is_pluto_workspace ? Main : s # Emulate `Main` in REPLS, roughly equivalent to Pluto workspace.
    return invoke(Serialization.serialize, Tuple{Serialization.AbstractSerializer, Module}, cs, s)
end
function Serialization.serialize(cs::CustomSerializer, a::A) where A<:Array
    if !Serialization.serialize_cycle(cs, a)
        Serialization.serialize(cs, A)
        for I in eachindex(a)
            Serialization.serialize(cs, isassigned(a, I) ? a[I] : undef)
        end
    end
    return nothing
end

end


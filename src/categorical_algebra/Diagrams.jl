""" Diagrams in a category and their morphisms.
"""
module Diagrams
export Diagram, SimpleDiagram, QueryDiagram, DiagramHom, id, op, co,
  shape, diagram, shape_map, diagram_map, get_params

using StructEquality

using ...GATs
import ...Theories: dom, codom, id, compose, ⋅, ∘, munit
using ...Theories: ThCategory, composeH, FreeSchema
import ..Categories: ob_map, hom_map, op, co
using ..FinCats, ..FreeDiagrams, ..FinSets
using ..FinCats: mapvals,FinDomFunctorMap,FinCatPresentation
import ..FinCats: force, collect_ob, collect_hom
import ..Limits: limit, colimit, universal
import ..FinSets: FinDomFunction
import Base.haskey
# Data types
############

""" Diagram in a category.

Recall that a *diagram* in a category ``C`` is a functor ``D: J → C``, where for
us the *shape category* ``J`` is finitely presented. Although such a diagram is
captured perfectly well by a `FinDomFunctor`, there are several different
notions of morphism between diagrams. The first type parameter `T` in this
wrapper type distinguishes which diagram category the diagram belongs to. See
[`DiagramHom`](@ref) for more about the possible choices. The parameter `T` may
also be `Any` to indicate that no choice has (yet) been made.
"""
abstract type Diagram{T,C<:Cat,D<:FinDomFunctor} end
Diagram(args...) = Diagram{Any}(args...)

# The first type parameter is considered part of the data!
Base.hash(d::Diagram{T}, h::UInt) where T = hash(T, struct_hash(d, h))
Base.:(==)(d1::Diagram{T}, d2::Diagram{S}) where {T,S} =
  T == S && struct_equal(d1, d2)

""" Default concrete type for diagram in a category.
"""
struct SimpleDiagram{T,C<:Cat,D<:Functor{<:FinCat,C}} <: Diagram{T,C,D}
  diagram::D
end
SimpleDiagram{T}(F::D) where {T,C<:Cat,D<:Functor{<:FinCat,C}} =
  SimpleDiagram{T,C,D}(F)
SimpleDiagram{T}(d::SimpleDiagram) where T = SimpleDiagram{T}(d.diagram)

Diagram{T}(F::Union{Functor,SimpleDiagram}) where T = SimpleDiagram{T}(F)

function Base.show(io::IO, d::SimpleDiagram{T}) where T
  print(io, "Diagram{$T}(")
  show(io, diagram(d))
  print(io, ")")
end

"""
Force-evaluate the functor in a diagram.
"""
force(d::SimpleDiagram{T}, args...) where T =
  SimpleDiagram{T}(force(diagram(d), args...))

""" Diagram representing a (conjunctive or gluing) query.

Besides the diagram functor itself, a query diagram contains a dictionary of
query parameters.
"""
struct QueryDiagram{T,C<:Cat,D<:Functor{<:FinCat,C},
                    Params<:AbstractDict} <: Diagram{T,C,D}
  diagram::D
  params::Params
end
QueryDiagram{T}(F::D, params::P) where {T,C<:Cat,D<:Functor{<:FinCat,C},P} =
  QueryDiagram{T,C,D,P}(F, params)
"""
  Force-evaluate the functor in a query diagram,
  including putting the parameters into the hom-map 
  explicitly.
"""
force(d::QueryDiagram{T},args...) where T =
  SimpleDiagram{T}(force(diagram(d),args...;params=d.params))
  

""" Functor underlying a diagram object.
"""
diagram(d::Diagram) = d.diagram

""" The *shape* or *indexing category* of a diagram.

This is the domain of the underlying functor.
"""
shape(d::Diagram) = dom(diagram(d))

ob_map(d::Diagram, x) = ob_map(diagram(d), x)
hom_map(d::Diagram, f) = hom_map(diagram(d), f)

collect_ob(d::Diagram) = collect_ob(diagram(d))
collect_hom(d::Diagram) = collect_hom(diagram(d))

""" Morphism of diagrams in a category.

In fact, this type encompasses several different kinds of morphisms from a
diagram ``D: J → C`` to another diagram ``D′: J′ → C``:

1. `DiagramHom{id}`: a functor ``F: J → J′`` together with a natural
   transformation ``ϕ: D ⇒ F⋅D′``
2. `DiagramHom{op}`: a functor ``F: J′ → J`` together with a natural
   transformation ``ϕ: F⋅D ⇒ D′``
3. `DiagramHom{co}`: a functor ``F: J → J′`` together with a natural
   transformation ``ϕ: F⋅D′ ⇒ D``.

Note that `Diagram{op}` is *not* the opposite category of `Diagram{id}`, but
`Diagram{op}` and `Diagram{co}` are opposites of each other. Explicit support is
included for both because they are useful for different purposes: morphisms of
type `DiagramHom{id}` and `DiagramHom{op}` induce morphisms between colimits and
between limits of the diagrams, respectively, whereas morphisms of type
`DiagramHom{co}` generalize morphisms of polynomial functors.
"""
abstract type DiagramHom{T,C<:Cat} end

struct SimpleDiagramHom{T,C<:Cat,F<:FinFunctor,Φ<:FinTransformation,D<:Functor{<:FinCat,C}}<:DiagramHom{T,C}
  shape_map::F
  diagram_map::Φ # bug: Φ should be type constrained to be a FinTransformation  
  precomposed_diagram::D
end
struct QueryDiagramHom{T,C<:Cat,F<:FinFunctor,Φ<:FinTransformation,D<:Functor{<:FinCat,C},Params<:AbstractDict}<:DiagramHom{T,C}
  shape_map::F
  diagram_map::Φ
  precomposed_diagram::D
  params::Params
end

DiagramHom{T}(shape_map::F, diagram_map::Φ, precomposed_diagram::D;params::Params=nothing) where
    {T,C,F<:FinFunctor,Φ<:FinTransformation,D<:Functor{<:FinCat,C},Params<:Union{AbstractDict,Nothing}} =
  isnothing(params) ?   
    SimpleDiagramHom{T,C,F,Φ,D}(shape_map, diagram_map, precomposed_diagram) :
    QueryDiagramHom{T,C,F,Φ,D,Params}(shape_map, diagram_map, precomposed_diagram,params)
"""Convert the diagram category in which a diagram hom is being viewed."""
DiagramHom{T}(f::DiagramHom) where T =
  DiagramHom{T}(f.shape_map, f.diagram_map, f.precomposed_diagram,params=get_params(f))

DiagramHom{T}(ob_maps, hom_map, D::Diagram{T}, D′::Diagram{T};kw...) where T =
  DiagramHom{T}(ob_maps, hom_map, diagram(D), diagram(D′);kw...)
DiagramHom{T}(ob_maps, D::Union{Diagram{T},FinDomFunctor},
              D′::Union{Diagram{T},FinDomFunctor};kw...) where T =
  DiagramHom{T}(ob_maps, nothing, D, D′;kw...)

function DiagramHom{T}(ob_maps, hom_map, D::FinDomFunctor, D′::FinDomFunctor;kw...) where T
  f = FinFunctor(mapvals(cell1, ob_maps), hom_map, dom(D), dom(D′))
  DiagramHom{T}(f, mapvals(x -> cell2(D′,x), ob_maps), D, D′;kw...)
end
function DiagramHom{op}(ob_maps, hom_map, D::FinDomFunctor, D′::FinDomFunctor;kw...)
  f = FinDomFunctor(mapvals(cell1, ob_maps), hom_map, dom(D′), dom(D))
  DiagramHom{op}(f, mapvals(x -> cell2(D,x), ob_maps), D, D′;kw...)
end

function DiagramHom{id}(f::FinFunctor, components, D::FinDomFunctor, D′::FinDomFunctor;kw...)
  ϕ = FinTransformation(components, D, f⋅D′)
  DiagramHom{id}(f, ϕ, D′;kw...)
end
function DiagramHom{op}(f::FinFunctor, components, D::FinDomFunctor, D′::FinDomFunctor;kw...)
  ϕ = FinTransformation(components, f⋅D, D′)
  DiagramHom{op}(f, ϕ, D;kw...)
end
function DiagramHom{co}(f::FinFunctor, components, D::FinDomFunctor, D′::FinDomFunctor;kw...)
  ϕ = FinTransformation(components, f⋅D′, D)
  DiagramHom{co}(f, ϕ, D′;kw...)
end

cell1(pair::Union{Pair,Tuple{Any,Any}}) = first(pair)
cell1(x) = x
cell2(D::FinDomFunctor, pair::Union{Pair,Tuple{Any,Any}}) = last(pair)
cell2(D::FinDomFunctor, x) = id(codom(D), ob_map(D, x))

shape_map(f::DiagramHom) = f.shape_map
diagram_map(f::DiagramHom) = f.diagram_map

Base.hash(f::DiagramHom{T}, h::UInt) where {T} = hash(T, struct_hash(f, h))

Base.:(==)(f::DiagramHom{T}, g::DiagramHom{S}) where {T,S} =
  T == S && struct_equal(f, g)

ob_map(f::DiagramHom, x) = (ob_map(f.shape_map, x), component(f.diagram_map, x))
hom_map(f::DiagramHom, g) = hom_map(f.shape_map, g)

collect_ob(f::DiagramHom) =
  collect(zip(collect_ob(f.shape_map), components(f.diagram_map)))
collect_hom(f::DiagramHom) = collect_hom(f.shape_map)

get_params(f::QueryDiagramHom) = f.params
get_params(f::DiagramHom) = Dict()

function Base.show(io::IO, f::DiagramHom{T}) where T
  J = dom(shape_map(f))
  print(io, "DiagramHom{$T}([")
  join(io, mapvals(x -> ob_map(f,x), ob_generators(J), iter=true), ", ")
  print(io, "], [")
  join(io, mapvals(g -> hom_map(f,g), hom_generators(J), iter=true), ", ")
  print(io, "], ")
  show(IOContext(io, :compact=>true, :hide_domains=>true), diagram(dom(f)))
  print(io, ", ")
  show(IOContext(io, :compact=>true, :hide_domains=>true), diagram(codom(f)))
  print(io, ")")
end

# Categories of diagrams
########################

dom_diagram(f::DiagramHom{id}) = dom(diagram_map(f))
dom_diagram(f::DiagramHom{op}) = f.precomposed_diagram
dom_diagram(f::DiagramHom{co}) = codom(diagram_map(f))
codom_diagram(f::DiagramHom{id}) = f.precomposed_diagram
codom_diagram(f::DiagramHom{op}) = codom(diagram_map(f))
codom_diagram(f::DiagramHom{co}) = f.precomposed_diagram

dom(f::DiagramHom{T}) where T = Diagram{T}(dom_diagram(f))
codom(f::DiagramHom{T}) where T = Diagram{T}(codom_diagram(f))

function id(d::Diagram{T}) where T
  F = diagram(d)
  DiagramHom{T}(id(dom(F)), id(F), F)
end

#Note compose of diagramhoms throws away parameters, which is fine for current
#purposes
function compose(f::DiagramHom{id}, g::DiagramHom{id})
  DiagramHom{id}(
    shape_map(f) ⋅ shape_map(g),
    diagram_map(f) ⋅ (shape_map(f) * diagram_map(g)),
    codom_diagram(g))
end
function compose(f::DiagramHom{op}, g::DiagramHom{op})
  DiagramHom{op}(
    shape_map(g) ⋅ shape_map(f),
    (shape_map(g) * diagram_map(f)) ⋅ diagram_map(g),
    dom_diagram(f))
end
function compose(f::DiagramHom{co}, g::DiagramHom{co})
  DiagramHom{co}(
    shape_map(f) ⋅ shape_map(g),
    (shape_map(f) * diagram_map(g)) ⋅ diagram_map(f),
    codom_diagram(g))
end

# TODO: The diagrams in a category naturally form a 2-category, but for now we
# just implement the category struture.

@instance ThCategory{Diagram,DiagramHom} begin
  @import dom, codom, compose, id
end

# Oppositization 2-functor induces isomorphisms of diagram categories:
#    op(Diag{id}(C)) ≅ Diag{op}(op(C))
#    op(Diag{op}(C)) ≅ Diag{id}(op(C))

op(d::Diagram{Any}) = Diagram{Any}(op(diagram(d)))
op(d::Diagram{id}) = Diagram{op}(op(diagram(d)))
op(d::Diagram{op}) = Diagram{id}(op(diagram(d)))
op(f::DiagramHom{id}) = DiagramHom{op}(op(shape_map(f)), op(diagram_map(f)),
                                       op(f.precomposed_diagram))
op(f::DiagramHom{op}) = DiagramHom{id}(op(shape_map(f)), op(diagram_map(f)),
                                       op(f.precomposed_diagram))

# Any functor ``F: C → D`` induces a functor ``Diag(F): Diag(C) → Diag(D)`` by
# post-composition and post-whiskering.

function compose(d::Diagram{T}, F::Functor; kw...) where T
  Diagram{T}(compose(diagram(d), F; kw...))
end
function compose(f::DiagramHom{T}, F::Functor; params = [], kw...) where T
  whiskered = isempty(params) ? composeH(diagram_map(f), F; kw...) : param_compose(diagram_map(f),F;params=params)
  DiagramHom{T}(shape_map(f), whiskered,
                compose(f.precomposed_diagram, F; kw...))
end

"""Whisker a partially natural transformation with a functor ``H``,
given any needed parameters specifying the functions in ``H``'s codomain
which the whiskered result should map to. Currently assumes
the result will be a totally defined transformation.
"""
function param_compose(α::FinTransformation, H::Functor; params=Dict())
  F, G = dom(α), codom(α)
  new_components = mapvals(pairs(α.components);keys=true) do i,f
    compindex = ob(dom(F),i)
    #allow non-strictness because of possible pointedness
    s, t = ob_map(compose(F,H,strict=false),compindex), 
    ob_map(compose(G,H,strict=false),compindex)
    if head(f) == :zeromap
      func = params[i]
      FinDomFunction(func,s,t)
    #may need to population params with identities
    else
      func = haskey(params,i) ? SetFunction(params[i],t,t) : SetFunction(identity,t,t)
      hom_map(H,f)⋅func
    end
  end
  FinTransformation(new_components,compose(F, H, strict=false), compose(G, H, strict=false))
end


"""
Compose a diagram with parameters with a functor. 
The result is not evaluated, so the functor may remain
partially defined with parameters still to be filled in.
"""
function compose(d::QueryDiagram{T},F::Functor; kw...) where T
  D = diagram(d)
  partial = compose(D,F;strict=false) #cannot be evaluated on the keys of params yet
  #Get the FinDomFunctions in the range of F that must be plugged into
  #the Functions in params
  params = d.params
  mors = hom_generators(codom(D))
  morfuns = map(x->hom_map(F,x),mors)
  params_new = Dict{keytype(params),FinDomFunction}()
  for (n,f) in params #Calculate the intended value of the composition on n
    domain = ob_map(partial,dom(hom(dom(partial),n)))
    codomain = ob_map(partial,codom(hom(dom(partial),n)))
    params_new[n] =
      FinDomFunction(f(morfuns...),domain,codomain)
  end
  #This will now contain a composite functor which can't directly be hom-mapped; ready to be forced.
  QueryDiagram{T}(partial,params_new)
end
# Limits and colimits
#####################

# In a cocomplete category `C`, colimits define a functor `Diag{id,C} → C`.
# Dually, in a complete category `C`, limits define functor `Diag{op,C} → C`.

function limit(d::Union{Diagram{op},Diagram{Any}}; alg=nothing)
  limit(diagram(d), alg)
end
function colimit(d::Union{Diagram{id},Diagram{Any}}; alg=nothing)
  colimit(diagram(d), alg)
end

function universal(f::DiagramHom{op}, dom_lim, codom_lim)
  J′ = shape(codom(f))
  obs = Dict(reverse(p) for p in pairs(ob_generators(dom(diagram(dom(f))))))
  cone = Multispan(apex(dom_lim), map(ob_generators(J′)) do j′
    j, g = ob_map(f, j′)
    πⱼ = legs(dom_lim)[obs[j]]
    compose(πⱼ, g)
  end)
  universal(codom_lim, cone)
end

function universal(f::DiagramHom{id}, dom_colim, codom_colim)
  J = shape(dom(f))
  obs = Dict(reverse(p) for p in pairs(ob_generators(dom(diagram(codom(f))))))
  cocone = Multicospan(apex(codom_colim), map(ob_generators(J)) do j
    j′, g = ob_map(f, j)
    ιⱼ′ = legs(codom_colim)[obs[j′]]
    compose(g, ιⱼ′)
  end)
  universal(dom_colim, cocone)
end

# Monads of diagrams
####################

# TODO: Define monad multiplications that go along with the units.

#Sends an object of C to the diagram picking it out.
function munit(::Type{Diagram{T}}, C::Cat, x; shape=nothing) where T
  if isnothing(shape)
    shape = FinCat(1)
  else
    @assert is_discrete(shape) && length(ob_generators(shape)) == 1
  end
  shape isa FinCatPresentation && 
    return Diagram{T}(FinDomFunctor(Dict(nameof(a)=> x for a in ob_generators(shape)),shape,C))
  Diagram{T}(FinDomFunctor([x], shape, C))
end

function munit(::Type{DiagramHom{T}}, C::Cat, f;
               dom_shape=nothing, codom_shape=nothing) where T
  f = hom(C, f)
  d = munit(Diagram{T}, C, dom(C, f), shape=dom_shape)
  d′= munit(Diagram{T}, C, codom(C, f), shape=codom_shape)
  j = only(ob_generators(shape(d′)))
  isnothing(dom_shape) ? DiagramHom{T}([Pair(j, f)], d, d′) :
   DiagramHom{T}(Dict(only(ob_generators(dom(diagram(d)))) => Pair(j, f)),d,d′)
end
function munit(::Type{DiagramHom{op}}, C::Cat, f;
  dom_shape=nothing, codom_shape=nothing)
f = hom(C, f)
d = munit(Diagram{op}, C, dom(C, f), shape=dom_shape)
d′= munit(Diagram{op}, C, codom(C, f), shape=codom_shape)
j = only(ob_generators(shape(d)))
isnothing(dom_shape) ? DiagramHom{op}([Pair(j, f)], d, d′) :
   DiagramHom{op}(Dict(only(ob_generators(dom(diagram(d′)))) => Pair(j, f)),d,d′)
end

end
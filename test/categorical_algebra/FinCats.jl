module TestFinCats
using Test

using Catlab, Catlab.Theories, Catlab.CategoricalAlgebra, Catlab.Graphs
using Catlab.Graphs.BasicGraphs: TheoryGraph, TheoryReflexiveGraph

# Discrete categories
#####################

C = FinCat(FinSet(3))
@test C isa FinCat{Int,Int}
@test is_discrete(C)
@test collect(ob_generators(C)) == 1:3
@test isempty(hom_generators(C))
@test (dom(C, 1), codom(C, 1)) == (1, 1)
@test (id(C, 2), compose(C, 2, 2)) == (2, 2)

F = FinDomFunctor([FinSet(1), FinSet(3), FinSet(1)],
                  C, TypeCat(FinSet{Int}, FinFunction{Int}))
@test ob_map(F, 2) == FinSet(3)
@test hom_map(F, 2) == id(FinSet(3))

# Categories on graphs
######################

# Free categories
#----------------

g = parallel_arrows(Graph, 3)
C = FinCat(g)
@test graph(C) == g
@test Ob(C) == FinSet(2)
@test !is_discrete(C)
@test is_free(C)
@test hom(C, 1) == Path(g, 1)
@test ob_generators(C) == 1:2
@test hom_generators(C) == 1:3

h = Graph(4)
add_edges!(h, [1,1,2,3], [2,3,4,4])
D = FinCat(h)
f = id(D, 2)
@test (src(f), tgt(f)) == (2, 2)
@test isempty(edges(f))
f = compose(D, 1, 3)
@test edges(f) == [1,3]

# Functors between free categories.
C = FinCat(parallel_arrows(Graph, 2))
F = FinFunctor((V=[1,4], E=[[1,3], [2,4]]), C, D)
@test dom(F) == C
@test codom(F) == D
@test is_functorial(F)
@test Ob(F) == FinFunction([1,4], FinSet(4))

@test ob_map(F, 2) == 4
@test hom_map(F, 1) == Path(h, [1,3])
@test collect_ob(F) == [1,4]
@test collect_hom(F) == [Path(h, [1,3]), Path(h, [2,4])]

# Composition of functors.
g, h, k = path_graph(Graph, 2), path_graph(Graph, 3), path_graph(Graph, 5)
C, D, E = FinCat(g), FinCat(h), FinCat(k)
F = FinFunctor([1,3], [[1,2]], C, D)
G = FinFunctor([1,3,5], [[1,2],[3,4]], D, E)
@test is_functorial(G)
@test hom_map(G, Path(h, [1,2])) == Path(k, [1,2,3,4])
@test F⋅G == FinFunctor([1,5], [[1,2,3,4]], C, E)
@test id(C)⋅F == F
@test F⋅id(D) == F

# Free diagrams
#--------------

C = FinCat(parallel_arrows(Graph, 2))
f, g = FinFunction([1,3], 3), FinFunction([2,3], 3)
F = FinDomFunctor([FinSet(2), FinSet(3)], [f,g], C)
@test is_functorial(F)
@test dom(F) == C
@test codom(F) isa TypeCat{<:FinSet{Int},<:FinFunction{Int}}
@test ob_map(F, 1) == FinSet(2)
@test hom_map(F, 2) == g

# Diagram interface.
@test diagram_type(F) <: Tuple{FinSet{Int},FinFunction{Int}}
@test cone_objects(F) == [FinSet(2), FinSet(3)]
@test cocone_objects(F) == [FinSet(2), FinSet(3)]
@test ob(limit(F)) == FinSet(1)
@test ob(colimit(F)) == FinSet(2)

# `FreeDiagrams` interop.
diagram = FreeDiagram(ParallelPair(f, g))
@test FreeDiagram(F) == diagram
F = FinDomFunctor(diagram)
@test dom(F) isa FinCat
@test codom(F) isa TypeCat{<:FinSet{Int},<:FinFunction{Int}}
@test ob_map(F, 1) == FinSet(2)
@test hom_map(F, 2) == g
@test collect_ob(F) == [FinSet(2), FinSet(3)]
@test collect_hom(F) == [f, g]

# Commutative square as natural transformation.
C = FinCat(path_graph(Graph, 2))
F = FinDomFunctor([FinSet(4), FinSet(2)], [FinFunction([1,1,2,2])], C)
α₀, α₁ = FinFunction([3,4,1,2]), FinFunction([2,1])
α = FinTransformation([α₀, α₁], F, F)
@test is_natural(α)
@test (α[1], α[2]) == (α₀, α₁)
@test components(α) == [α₀, α₁]
@test α⋅α == FinTransformation([FinFunction(1:4), FinFunction(1:2)], F, F)

# Path equations
#---------------

# Simplex category truncated to one dimension.
Δ¹_graph = Graph(2)
add_edges!(Δ¹_graph, [1,1,2], [2,2,1])
Δ¹ = FinCat(Δ¹_graph, [ [1,3] => empty(Path, Δ¹_graph, 1),
                        [2,3] => empty(Path, Δ¹_graph, 1) ])
@test graph(Δ¹) == Δ¹_graph
@test length(equations(Δ¹)) == 2
@test !is_free(Δ¹)

# Symbolic categories
#####################

@present Simplex1D(FreeCategory) begin
  (V, E)::Ob
  (δ₀, δ₁)::Hom(V, E)
  σ₀::Hom(E, V)

  δ₀ ⋅ σ₀ == id(V)
  δ₁ ⋅ σ₀ == id(V)
end

Δ¹ = FinCat(Simplex1D)
@test Δ¹ isa FinCat{FreeCategory.Ob,FreeCategory.Hom}
@test ob(Δ¹, :V) isa FreeCategory.Ob
@test hom(Δ¹, :δ₀) isa FreeCategory.Hom
@test first.(ob_generators(Δ¹)) == [:V, :E]
@test first.(hom_generators(Δ¹)) == [:δ₀, :δ₁, :σ₀]
@test length(equations(Δ¹)) == 2
@test !is_free(Δ¹)

# Graph as set-valued functor on a free category.
F = FinDomFunctor(TheoryGraph, path_graph(Graph, 3))
C = dom(F)
@test is_functorial(F)
@test ob_map(F, :V) == FinSet(3)
@test hom_map(F, :src) == FinFunction([1,2], 3)
@test F(ob(C, :E)) == FinSet(2)
@test F(hom(C, :tgt)) == FinFunction([2,3], 3)
@test F(id(ob(C, :E))) == id(FinSet(2))

# Reflexive graph as set-valued functor on a category with equations.
G = FinDomFunctor(TheoryReflexiveGraph, path_graph(ReflexiveGraph, 3))
@test is_functorial(G)

# Graph homomorphisms as natural transformations.
g = parallel_arrows(Graph, 2)
add_edges!(g, [2,2], [2,2])
G = FinDomFunctor(TheoryGraph, g)
α = FinTransformation(F, G, V=FinFunction([1,2,2]), E=FinFunction([1,3],4))
@test dom_ob(α) == C
@test codom_ob(α) isa TypeCat{<:FinSet{Int},<:FinFunction{Int}}
@test is_natural(α)
@test α[:V](3) == 2
σ = FinTransformation(G, G, V=id(FinSet(2)), E=FinFunction([2,1,4,3]))
@test σ⋅σ == FinTransformation(G, G, V=id(FinSet(2)), E=FinFunction(1:4))
@test α⋅σ == FinTransformation(F, G, V=FinFunction([1,2,2]), E=FinFunction([2,4]))

# Pullback data migration by pre-whiskering.
ιV = FinFunctor([:V], FinCat(1), FinCat(TheoryGraph))
αV = ιV * α
@test ob_map(dom(αV), 1) == ob_map(F, :V)
@test ob_map(codom(αV), 1) == ob_map(G, :V)
@test component(αV, 1) == component(α, :V)

# Post-whiskering and horizontal composition.
ιE = FinFunctor([:E], FinCat(1), FinCat(TheoryGraph))
ϕ = FinTransformation([:src], ιE, ιV)
@test is_natural(ϕ)
@test component(ϕ*F, 1) == hom_map(F, :src)
@test component(ϕ*α, 1) == hom_map(F, :src) ⋅ α[:V]

end

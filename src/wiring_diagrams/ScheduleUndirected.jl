""" Scheduling and evaluation of undirected wiring diagrams.

In category-theoretic terms, this module is about evaluating arbitrary
composites of morphisms in hypergraph categories.
"""
module ScheduleUndirectedWiringDiagrams
export AbstractNestedUWD, AbstractUWDSchedule, NestedUWD, UWDSchedule,
  eval_nested_diagram, to_nested_diagram, sequential_schedule

using Compat: only
using DataStructures: IntDisjointSets, union!, in_same_set

using ...Present, ...CategoricalAlgebra.CSets, ..UndirectedWiringDiagrams
using ..UndirectedWiringDiagrams: TheoryUWD, flat

const AbstractUWD = UndirectedWiringDiagram

# Data types
############

@present TheoryUWDSchedule <: TheoryUWD begin
  Composite::Ob

  parent::Hom(Composite, Composite)
  box_parent::Hom(Box, Composite)

  # Po-category axiom enforcing that composites form a rooted forest.
  # parent <= id(Composite)
end

const AbstractUWDSchedule = AbstractACSetType(TheoryUWDSchedule)

""" TODO
"""
const UWDSchedule = CSetType(TheoryUWDSchedule,
  index=[:box, :junction, :outer_junction, :parent, :box_parent])

ncomposites(x::AbstractACSet) = nparts(x, :Composite)
composites(x::AbstractACSet) = parts(x, :Composite)
parent(x::AbstractACSet, args...) = subpart(x, args..., :parent)
children(x::AbstractACSet, c::Int) =
  filter(c′ -> c′ != c, incident(x, c, :parent))
box_parent(x::AbstractACSet, args...) = subpart(x, args..., :box_parent)
box_children(x::AbstractACSet, args...) = incident(x, args..., :box_parent)

@present TheoryNestedUWD <: TheoryUWDSchedule begin
  CompositePort::Ob

  composite::Hom(CompositePort, Composite)
  composite_junction::Hom(CompositePort, Junction)
end

const AbstractNestedUWD = AbstractACSetType(TheoryNestedUWD)

""" TODO
"""
const NestedUWD = CSetType(TheoryNestedUWD,
  index=[:box, :junction, :outer_junction,
         :composite, :composite_junction, :parent, :box_parent])

composite_ports(x::AbstractACSet, args...) = incident(x, args..., :composite)
composite_junction(x::AbstractACSet, args...) =
  subpart(x, args..., :composite_junction)
composite_ports_with_junction(x::AbstractACSet, args...) =
  incident(x, args..., :composite_junction)

# Evaluation
############

""" TODO
"""
function eval_nested_diagram(f, d::AbstractNestedUWD, generators::AbstractVector)
  function eval_composite(c::Int)
    bs, cs = box_children(d, c), children(d, c)
    values = [ generators[bs]; map(eval_composite, cs) ]
    js = [ [junction(d, ports(d, b)) for b in bs];
           [composite_junction(d, composite_ports(d, c′)) for c′ in cs] ]
    outgoing_js = composite_junction(d, composite_ports(d, c))
    f(values, js, outgoing_js)
  end

  roots = filter(c -> parent(d, c) == c, composites(d))
  eval_composite(only(roots))
end

""" TODO
"""
function to_nested_diagram(s::AbstractUWDSchedule)
  d = NestedUWD()
  copy_parts!(d, s)

  n = nboxes(s)
  sets = IntDisjointSets(n + ncomposites(s))

  function add_composite_ports!(c::Int)
    # Recursively add ports to all child composites.
    foreach(add_composite_ports!, children(d, c))

    # Get all junctions incident to any child box or child composite.
    js = unique!(flat([
      [ junction(d, ports(d, b)) for b in box_children(d, c) ];
      [ composite_junction(d, composite_ports(d, c′)) for c′ in children(d, c) ]
    ]))

    # Filter for "outgoing" junctions, having incident ports outside this node.
    c_rep = n+c
    for b in box_children(d, c)
      union!(sets, c_rep, b)
    end
    for c′ in children(d, c)
      union!(sets, c_rep, n+c′)
    end
    js = filter!(js) do j
      !(all(in_same_set(sets, c_rep, box(d, port))
            for port in ports_with_junction(d, j)) &&
        isempty(ports_with_junction(d, j, outer=true)))
    end

    # Add port for each outgoing junction.
    add_parts!(d, :CompositePort, length(js), composite=c, composite_junction=js)
  end

  # Add ports to each composite, starting at roots.
  roots = filter(c -> parent(d, c) == c, composites(d))
  foreach(add_composite_ports!, roots)

  return d
end

# Scheduling
############

""" Schedule UWD as a sequential chain of binary composites.

This is the simplest possible scheduling algorithm, the equivalent of `foldl`
for undirected wiring diagrams. Unless otherwise specified, the box order is
that of the box IDs in the diagram.
"""
sequential_schedule(d::AbstractUWD) = sequential_schedule(d, boxes(d))

function sequential_schedule(d::AbstractUWD, boxes::AbstractVector{Int})
  nb = nboxes(d)
  @assert length(boxes) == nb
  nc = max(1, nb-1)

  schedule = UWDSchedule()
  copy_parts!(schedule, d)
  add_parts!(schedule, :Composite, nc, parent=[2:nc; nc])
  set_subpart!(schedule, boxes[1:min(2,nb)], :box_parent, 1)
  set_subpart!(schedule, boxes[3:nb], :box_parent, 2:nc)
  schedule
end

end

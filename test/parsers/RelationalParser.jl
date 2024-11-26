# __precompile__(false) #REMOVE
# ## Testing our parser
module ParserTests

using Test
using Catlab.ADTs.RelationTerm
using Catlab.Parsers.RelationalParser
using Catlab.WiringDiagrams.RelationDiagrams


# Now we write some unit tests. This is how I wrote this code, by writing the tests from the bottom up.
@testset "Parens" begin
  @test lparen("(")[1] == "("
  @test rparen(")")[1] == ")"
  @test ident("R(a)")[1] == "R"
end

@testset "Arg" begin
  @test arg("x")[1] == Untyped(:x)
  @test arg("tgt=x")[1] == Kwarg(:tgt, Untyped(:x))
end

@testset "Args" begin
  @test args("x,y,z")[1] == [Untyped(:x), Untyped(:y), Untyped(:z)]
  @test args("tgt=x,src=y")[1] == [Kwarg(:tgt, Untyped(:x)), Kwarg(:src, Untyped(:y))]
  @test args("")[1] == []
end

@testset "Judgement" begin
  @test judgement("a:A,")[1] == Typed(:a, :A)
  @test judgement("ab:AB,")[1] == Typed(:ab, :AB)

  @test judgement("a")[1] == Untyped(:a)
end

@testset "judgements" begin
  @test judgements("a:A, b:B, c:C")[1] == [Typed(:a, :A), Typed(:b, :B), Typed(:c, :C)]
  @test judgements("a, b, c")[1] == [Untyped(:a), Untyped(:b), Untyped(:c)]
  @test judgements("")[1] == []
end

# DEBUG
PEG.setdebug!(false)

@testset "Outer Ports" begin
  @test outerPorts("(A)")[1] == [Untyped(:A)]
  @test outerPorts("(A,B)")[1] == [Untyped(:A), Untyped(:B)]
  @test outerPorts("(src=A, tgt=B)")[1] == [Kwarg(:src, Untyped(:A)), Kwarg(:tgt, Untyped(:B))]
  @test outerPorts("()")[1] == []
end

@testset "Contexts" begin
  @test RelationalParser.context("(a:A,b:B)")[1] == [Typed(:a, :A), Typed(:b, :B)]
  @test RelationalParser.context("(a:A,  b:B)")[1] == [Typed(:a, :A), Typed(:b, :B)]
  @test RelationalParser.context("( a:A,  b:B )")[1] == [Typed(:a, :A), Typed(:b, :B)]
  @test RelationalParser.context("(x,y)")[1] == [Untyped(:x), Untyped(:y)]
  @test RelationalParser.context("()")[1] == []
end

@testset "Statements" begin
  @test [Untyped(:u)] == [Untyped(:u)]
  @test statement("R(a,b)")[1] == Statement(:R, [Untyped(:a),Untyped(:b)])
  @test statement("S(u,b)")[1] == Statement(:S, [Untyped(:u),Untyped(:b)])
  @test statement("S(u,b,x)")[1].relation == Statement(:S, [Untyped(:u), Untyped(:b), Untyped(:x)]).relation
  @test statement("S(u,b,x)")[1].variables == Statement(:S, [Untyped(:u), Untyped(:b), Untyped(:x)]).variables
  @test statement("S(u)")[1].relation == Statement(:S, [Untyped(:u)]).relation
  @test statement("S(u)")[1].variables == Statement(:S, Var[Untyped(:u)]).variables
  @test statement("S(  a,    b  )")[1] == Statement(:S, [Untyped(:a),Untyped(:b)])
  @test statement("R(src=a, tgt=b)")[1] == Statement(:R, [Kwarg(:src, Untyped(:a)), Kwarg(:tgt, Untyped(:b))])
end

@testset "Body" begin
  @test body("""{
  R(a,b);}""")[1][1] isa Statement

  @test body("""{
  R(a,b);
  }""")[1][1] isa Statement

  @test body("""{
    R(a,b);
  }""")[1][1] isa Statement

  @test length(body("""{
  R(a,b);
    S(u,b);
  }""")[1]) == 2

  @test body("""{ R(a,b)\n S(u,b)\n}""")[1] == [Statement(:R, [Untyped(:a), Untyped(:b)]), Statement(:S, [Untyped(:u), Untyped(:b)])]
end

# Our final test shows that we can parse what we expect to be able to parse:
@testset "UWD" begin
  @test uwd("""(x,z) where (x,y,z) {R(x,y); S(y,z);}""")[1].context == [Untyped(:x), Untyped(:y), Untyped(:z)]
  @test uwd("""(x,z) where (x,y,z)
    {R(x,y); S(y,z);}""")[1].statements == [Statement(:R, [Untyped(:x), Untyped(:y)]),
    Statement(:S, [Untyped(:y), Untyped(:z)])]
  @test uwd("""(x,z) where (x,y,z) {R(x,y); S(y,z);}""")[1] isa RelationTerm.UWDExpr
end

# Test Error Handling:

#Taken from "PEG.jl/blob/master/test/misc.jl" to test parsing exception handling
function parse_fails_at(rule, input)
  try
    parse_whole(rule, input)
    "parse succeeded!"
  catch err
    isa(err, Meta.ParseError) || rethrow()
    m = match(r"^On line \d+, at column \d+ \(byte (\d+)\):", err.msg)
    m == nothing && rethrow()
    parse(Int, m.captures[1])
  end
end

@testset "judgement_handling" begin
  @test parse_fails_at(judgement, "a:") == 3
  @test parse_fails_at(judgement, ":a") == 1
end

@testset "context_handling" begin
  @test parse_fails_at(RelationalParser.context, "(a:A,b:B") == 9
  @test parse_fails_at(RelationalParser.context, "(a:A,b:B,") == 10
  @test parse_fails_at(RelationalParser.context, "(a:A,b:B,)") == 10
end

@testset "statement_handling" begin
  @test parse_fails_at(statement, "R(a,b") == 6
  @test parse_fails_at(statement, "R(a,b,") == 7
  @test parse_fails_at(statement, "R(a,b,)") == 7
  @test parse_fails_at(statement, "(a,b)") == 1
end

@testset "Line Handling" begin
  @test parse_fails_at(line, "R(a,b)") == 7
end

@testset "Body Handling" begin
  @test parse_fails_at(body, "{R(a,b)") == 8
  @test parse_fails_at(body, "R(a,b)}") == 1
end

# End-To-End Test Cases illustrating full on use of string macro
@testset "End-To-End" begin

  #Test "{R(x,y); S(y,z);}" where {x:X,y:Y,z:Z}
  parsed_result = relation"() where (x:X,y:Y,z:Z) {R(x,y); S(y,z);}"
  
  v1 = Typed(:x, :X)
  v2 = Typed(:y, :Y)
  v3 = Typed(:z, :Z)
  op = []
  c = [v1, v2, v3]
  s = [Statement(:R, [v1,v2]),
    Statement(:S, [v2,v3])]
  u = UWDExpr(op, c, s)
  uwd_result = RelationTerm.construct(RelationDiagram, u)
  
  @test parsed_result == uwd_result

  # Test error handling
  
  parsed_result = relation"""
  (x, z) where (x:X, y:Y, z:Z)
  {
    R(x, y);
    S(y, z);
    T(z, y, u);
  }"""

  v1 = Typed(:x, :X)
  v2 = Typed(:y, :Y)
  v3 = Typed(:z, :Z)
  v4 = Untyped(:u)
  op = [v1, v3]
  c = [v1, v2, v3]
  s = [Statement(:R, [v1,v2]),
    Statement(:S, [v2,v3]),
    Statement(:T, [v3,v2, v4])]
  u = UWDExpr(op, c, s)
  uwd_result = RelationTerm.construct(RelationDiagram, u)

  @test parsed_result == uwd_result

end

end
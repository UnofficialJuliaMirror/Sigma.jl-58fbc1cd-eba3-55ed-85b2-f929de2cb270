## Constant Random Variable
## ========================
@doc "A constant value. A constant function which 'ignores' input, e.g. ω->5" ->
immutable ConstantRandVar{T} <: RandVar{T}
  val::T
end

args(X::ConstantRandVar) = Set{RandVar}()
dims(X::ConstantRandVar) = Set{Int}()
# QUESTION: Would this ever be called? Do we need to overload functiosn for all constants?
(==)(X::ConstantRandVar, Y::ConstantRandVar) = ConstantRandVar{Bool}(X.val == Y.val)
isequal(X::ConstantRandVar, Y::ConstantRandVar) = isequal(X.val,Y.val)

## Omega Random Variable
## =====================
@doc "Simplest RandVar: ω->ω[dim] - extracts dim component of omega" ->
immutable OmegaRandVar{T} <: RandVar{T}
  dim::Int
end

args(X::OmegaRandVar) = Set{RandVar}()
dims(X::OmegaRandVar) = Set(X.dim)
omega_component{T<:Real}(i,OmegaType::Type{T}=Float64) = OmegaRandVar{OmegaType}(i)
isequal(X::OmegaRandVar,Y::OmegaRandVar) = isequal(X.dim,Y.dim)

## Types and Arithmetic
## ====================
# Create types for each functional expression and overload primitive functions such
# randvar1 + randvar2 creates a PlusRandVar value with args [randvar1, randvar2]

## Real × Real -> Real ##
real_real_real = ((:PlusRandVar,:+),(:MinusRandVar,:-),(:TimesRandVar,:*),(:DivideRandVar,:/), (:PowRandVar,:(^)))
for (name,op) in real_real_real
  eval(
  quote
  immutable $name{T<:Real,A1<:Real,A2<:Real} <: RandVar{T}
    args::Tuple{RandVar{A1},RandVar{A2}}
  end
  # (^) Fixes ambiguities. Redefined here in each loop iteration but shouldn't matter
  (^){T1<:Real,T2<:Integer}(X::RandVar{T1},c::T2) = PowRandVar{promote_type(T1, T2),T1,T2}((X,c))
  ($op){T1<:Real, T2<:Real}(X::RandVar{T1}, Y::RandVar{T2}) = $name{promote_type(T1, T2),T1,T2}((X,Y))
  ($op){T1<:Real, T2<:Real}(X::RandVar{T1}, c::T2) = $name{promote_type(T1, T2),T1,T2}((X,ConstantRandVar(c)))
  ($op){T1<:Real, T2<:Real}(c::T1, X::RandVar{T2}) = $name{promote_type(T1, T2),T1,T2}((ConstantRandVar(c),X))
  end)
end

# Real -> Real
for (name,op) in ((:UnaryPlusRandVar,:+),(:UnaryMinusRandVar,:-),(:AbsRandVar,:*))
  eval(
  quote
  immutable $name{T<:Real,A1<:Real} <: RandVar{T}
    args::Tuple{RandVar{A1}}
  end
  ($op){T<:Real}(X::RandVar{T}) = $name{T,T}((X,))
  end)
end

# Real -> _<:Floating
for (name,op) in ((:ExpRandVar,:exp), (:LogRandVar,:log), (:SinRandVar,:sin),
          (:CosRandVar,:cos), (:TanRandVar,:tan), (:AsinRandVar,:asin),
          (:AcosRandVar,:acos), (:AtanRandVar,:atan), (:SinhRandVar,:sinh),
          (:CoshRandVar,:cosh), (:TanhRandVar,:tanh), (:Atan2RandVar,:atan2))
  eval(
  quote
  immutable $name{T<:Real,A1<:Real} <: RandVar{T}
    args::Tuple{RandVar{A1}}
  end
  ($op){T<:Real}(X::RandVar{T}, returntype::DataType = Float64) = $name{returntype,T}((X,))
  end)
end

# Real × Real -> Bool
real_real_bool = ((:GTRandVar, :>), (:GTERandVar,:>=), (:LTERandVar,:<=), (:LTRandVar,:<),
                  (:EqRandVar, :(==)), (:NeqRandVar, :!=))

for (name,op) in real_real_bool
  eval(
  quote
  immutable $name{T<:Real,A1<:Real,A2<:Real} <: RandVar{T}
    args::Tuple{RandVar{A1},RandVar{A2}}
  end
  ($op){T1<:Real, T2<:Real}(X::RandVar{T1}, Y::RandVar{T2}) = $name{Bool,T1,T2}((X,Y))
  ($op){T1<:Real, T2<:Real}(X::RandVar{T1}, c::T2) = $name{Bool,T1,T2}((X,ConstantRandVar(c)))
  ($op){T1<:Real, T2<:Real}(c::T1, X::RandVar{T2}) = $name{Bool,T1,T2}((ConstantRandVar(c),X))
  end)
end

## Real × Real -> Bool ##
for (name,op) in ((:OrRandVar, :|), (:AndRandVar,:&))
  eval(
  quote
  immutable $name{T,A1,A2} <: RandVar{Bool}
    args::Tuple{RandVar{A1},RandVar{A2}}
  end
  ($op)(X::RandVar{Bool}, Y::RandVar{Bool}) = $name{Bool,Bool,Bool}((X,Y))
  ($op)(X::RandVar{Bool}, c::Bool) = $name{Bool,Bool,Bool}((X,ConstantRandVar(c)))
  ($op)(c::Bool, X::RandVar{Bool}) = $name{Bool,Bool,Bool}((ConstantRandVar(c),X))
  end)
end

## Bool -> Bool ##
immutable NotRandVar{T,A1} <: RandVar{Bool}
  args::Tuple{RandVar{A1}}
end
!(X::RandVar{Bool})= NotRandVar{Bool,Bool}(X)

immutable IfElseRandVar{T,A1,A2,A3} <: RandVar{T}
  args::Tuple{RandVar{A1},RandVar{A2},RandVar{A3}}
end

## ifelse
ifelse{T}(A::RandVar{Bool}, B::RandVar{T}, C::RandVar{T}) = IfElseRandVar{T,Bool,T,T}((A,B,C))
ifelse{T<:Real}(A::RandVar{Bool}, B::T, C::T) = IfElseRandVar{T,Bool,T,T}((A,ConstantRandVar(B),ConstantRandVar(C)))
ifelse{T<:Real}(A::RandVar{Bool}, B::RandVar{T}, C::T) = IfElseRandVar{T,Bool,T,T}((A,B,ConstantRandVar(C)))
ifelse{T<:Real}(A::RandVar{Bool}, B::T, C::RandVar{T}) = IfElseRandVar{T,Bool,T,T}((A,ContantRandVar(B),C))

# Unions
BinaryRealExpr = Union(PlusRandVar, MinusRandVar, TimesRandVar,DivideRandVar,PowRandVar)
UnaryRealExpr = Union(UnaryPlusRandVar,UnaryMinusRandVar,AbsRandVar)
TrigExpr = Union(ExpRandVar,LogRandVar,SinRandVar,CosRandVar,TanRandVar,AsinRandVar,
                 AcosRandVar,AtanRandVar,SinhRandVar,CoshRandVar,TanhRandVar,Atan2RandVar)
IneqExpr = Union(GTRandVar,GTERandVar,LTERandVar, LTRandVar,EqRandVar,NeqRandVar)
LogicalExpr = Union(OrRandVar,AndRandVar)

# All Functional expressions
FuncionalExpr = Union(BinaryRealExpr, UnaryRealExpr, TrigExpr, IneqExpr, LogicalExpr, IfElseRandVar)

args{T<:FuncionalExpr}(X::T) = X.args

## IBEX
## ====

typealias VarSet Set{IBEX.ExprSymbol}
typealias Visited Dict{RandVar,Any}
# Maps a variable to its interval domain
typealias DomainMap Dict{IBEX.ExprSymbol, Interval}


@doc "Maps between Boolean Variable to a constraint: e.g. X => a+b>c" ->
typealias ConstraintMap Dict{Tuple{IBEX.ExprCtr,VarSet}, BoolVar}

type BoolCounter
  x::Int
end
inc!(x::BoolCounter) = x.x += 1
nextvar!(x::BoolCounter) = (y = x.x; inc!(x); y)

@doc "Maps a predicate RandVar `X` to a ConstraintMap and a CMCNF of boolean structure" ->
function analyze(X::RandVar{Bool})
  ω = IBEX.ExprSymbol(maximum(dims(X))+1) # Ibex representation of sample space
  cmap = ConstraintMap() # map from ibex constraints to boolean variables
  cnf = CMCNF() # boolean cnf extracted
  aux_vars = Set{IBEX.ExprSymbol}() # Auxilary Variables
  next_boolvar = BoolCounter(0)
  visited = Dict{RandVar,Any}() # Visited Rand Vars and what they return

  result::BoolVar = expand(cmap,cnf,ω,aux_vars,visited,next_boolvar,X,args(X)...)

  push!(cnf,CMClause([CMLit(result,false)])) # Assert that the random variables should be true
  cmap, cnf, ω, aux_vars
end

#Default dict behaviour for constraint map
function add!(cmap::ConstraintMap, ctr::IBEX.ExprCtr, varset::VarSet, bc::BoolCounter)
  # Don't recreate if the constraint already exists
  if haskey(cmap,(ctr,varset))
    cmap[(ctr,varset)]
  else
    boolvar = nextvar!(bc)
    cmap[(ctr,varset)] = boolvar
    boolvar
  end
end

function expand(cmap::ConstraintMap, cnf::CMCNF, ω::IBEX.ExprSymbol, varset::VarSet, visited, bc::BoolCounter, X::OmegaRandVar)
  retvarset = union(VarSet([ω]), varset)
  ω[X.dim], retvarset
end

function expand(cmap::ConstraintMap, cnf::CMCNF, ω::IBEX.ExprSymbol, varset::VarSet, visited, bc::BoolCounter, X::ConstantRandVar)
  retvalue = IBEX.ExprConstant(X.val)
  retvalue, varset
end

## TODO, GENERIC RandVar Unary(not bool)
## TODO, GENERIC RANDVAR Unary trig

# Generic Randvar expamd
function expand(cmap::ConstraintMap, cnf::CMCNF, ω::IBEX.ExprSymbol, varset::VarSet, visited, bc::BoolCounter, X::RandVar, a::RandVar, b::RandVar)
  op_a, varset_a = haskey(visited,a) ? visited[a] : (visited[a] = expand(cmap, cnf, ω, varset, visited, bc, a, args(a)...))
  op_b, varset_b = haskey(visited,b) ? visited[b] : (visited[b] = expand(cmap, cnf, ω, varset, visited, bc, b, args(b)...))
  expand(cmap, cnf, ω, union(varset_a,varset_b),visited, bc, X, op_a, op_b)
end

# Generic Randvar{Bool} expand
function expand(cmap::ConstraintMap, cnf::CMCNF, ω::IBEX.ExprSymbol, varset::VarSet, visited, bc::BoolCounter, X::RandVar{Bool}, a::RandVar{Bool}, b::RandVar)
  op_a = haskey(visited,a) ? visited[a] : (visited[a] = expand(cmap, cnf, ω, varset, visited, bc, a, args(a)...))
  op_b = haskey(visited,b) ? visited[b] : (visited[b] = expand(cmap, cnf, ω, varset, visited, bc, b, args(b)...))
  expand(cmap, cnf, ω, varset, visited, bc, X, op_a, op_b)
end

for (name,op) in real_real_bool
  eval(
  quote
  function expand(cmap::ConstraintMap, cnf::CMCNF, ω::IBEX.ExprSymbol, varset::VarSet, visited, bc::BoolCounter, X::$name, a::IBEX.ExprNode, b::IBEX.ExprNode)
    constraint::IBEX.ExprCtr = $op(a,b)
    boolvar = add!(cmap, constraint, varset, bc)
    boolvar
  end
  end)
end

## Tseitin Transformation
## ======================

# Or
function expand(cmap::ConstraintMap, cnf::CMCNF, ω::IBEX.ExprSymbol, varset::VarSet, visited, bc::BoolCounter, X::OrRandVar, A::BoolVar, B::BoolVar)
  C = nextvar!(bc)
   # auxilary variable C = A | B
  # (A ∨ B ∨ !C) ∧ (!A ∨ C) ∧ (!B ∨ C)
  or_subcnf = CMCNF([CMClause([CMLit(A,false),CMLit(B,false),CMLit(C,true)]),
                     CMClause([CMLit(A,true),CMLit(C,false)]),
                     CMClause([CMLit(B,true),CMLit(C,false)])])
  push!(cnf, or_subcnf)
  C
end

# And
function expand(cmap::ConstraintMap, cnf::CMCNF, ω::IBEX.ExprSymbol, varset::VarSet, visited, bc::BoolCounter, X::AndRandVar, A::BoolVar, B::BoolVar)
  C = nextvar!(bc)
   # auxilary variable C = A & B
  # (\overline{A} \vee \overline{B} \vee C) \wedge (A \vee \overline{C}) \wedge (B \vee \overline{C})
  and_subcnf = CMCNF([CMClause([CMLit(A,true),CMLit(B,true),CMLit(C,false)]),
                      CMClause([CMLit(A,false),CMLit(C,true)]),
                      CMClause([CMLit(B,false),CMLit(C,true)])])
  push!(cnf, and_subcnf)
  C
end

# Not
function expand(cmap::ConstraintMap, cnf::CMCNF, ω::IBEX.ExprSymbol, varset::VarSet, visited, bc::BoolCounter, X::AndRandVar, A::BoolVar)
  C = nextvar!(bc)
   # auxilary variable C = !A
  # (\overline{A} \vee \overline{C}) \wedge (A \vee C)
  not_subcnf = CMCNF([CMClause([CMLit(A,true),CMLit(C,true)]),
                     CMClause([CMLit(A,false),CMLit(C,false)])])
  push!(cnf, not_subcnf)
  C
end

# Real * Real -> Real
for (name,op) in real_real_real
  eval(
  quote
  # Real
  function expand(cmap::ConstraintMap, cnf::CMCNF, ω::IBEX.ExprSymbol, varset::VarSet, visited, bc::BoolCounter, X::$name, a::IBEX.ExprNode, b::IBEX.ExprNode)
    result = ($op)(a,b)
    result, varset
  end
  end)
end

# Maps Literal to Equation
type LiteralMap
  cxx
end

# Reverse direction and adds negation
function to_cxx_lmap(cmap::ConstraintMap)
  lmap = icxx"std::map<CMSat::Lit,ibex::ExprCtr>();"
  reverse_map = Dict(zip(values(cmap),keys(cmap)))

  for ((constraint, varset), boolvar) in cmap
    @show constraint
    @show varset
    negconstraint = !constraint
    pair = icxx"std::pair<CMSat::Lit, ibex::ExprCtr>(CMSat::Lit($boolvar,false), $(constraint.cxx));"
    negpair = icxx"std::pair<CMSat::Lit, ibex::ExprCtr>(CMSat::Lit($boolvar,false), $(negconstraint.cxx));"
    @cxx lmap->insert(pair)
    @cxx lmap->insert(negpair)
  end
  LiteralMap(lmap)
end
  #     icxx"$lmap[CMSat::Lit($boolvar,false).toInt()] = $(ctr.cxx);"


  #   for ((ctr,varset), boolvar) in cmap
  #     # if haskey(lmap, Lit(boolvar,false))
  #     #   error("cmap maps multiple constraints to same Boolean variable")
  #     # else
  #     icxx"$lmap[CMSat::Lit($boolvar,false).toInt()] = $(ctr.cxx);"
  # #     icxx"$lmap[CMSat::Lit($boolvar,true).toInt()] = IBEX.ExprCtr($(ctr.cxx).e,!($(ctr.cxx).op));"
  #     # end
  #   end
  #   LiteralMap(lmap)
  # end

# ## Preprocessing
# ## =============

function analyzefully(cmap::ConstraintMap, cnf::CMCNF, ω, aux_vars)
  lmap = to_cxx_lmap(LiteralMap, cmap)
  lmap, cnf
end

# Main Loop of darkness
function pre_tlmh(lmap::LiteralMap, cnf::CMCNF, ω::IBEX.ExprSymbol, box, nsamples::Int)
  @cxx sigma::pre_tlmh(lmap.cxx, cnf.cxx, ω.cxx, box, nsamples)
end

function build_init_box(Y::RandVar{Bool})
  numdims = maximum(dims(Y))+1
  box = @cxx ibex::IntervalVector(numdims)
  for i = 0:(numdims-1)
    @show i
    icxx"$box[$i] = Interval(0,1);"
  end
  box
end

function pre_tlmh(Y::RandVar{Bool}, nsamples::Int)
  cmap, cnf, ω, aux_vars = analyze(Y)
  lmap = to_cxx_lmap(cmap)
  pre_tlmh(lmap, cnf, ω, build_init_box(Y), nsamples)
end

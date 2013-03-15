{-# LANGUAGE PatternGuards, FlexibleContexts, GADTs #-}
-- (c) Dan Rosén 2012
module Halo.FOL.Abstract
    ( Term', Formula', Clause'
    , StrTerm, StrFormula, StrClause

    , apply, con

    , fun, fun0
    , ctor, ctor0

    , bottom

    , app , apps
    , proj
    , qvar
    , skolem
    , ptr
    , prim
    , litInteger

    , splitFormula, splitFormulae

    , (===), (=/=)
    , (<=>), (<==>)
    , (==>), (===>)
    , (/\), ands
    , (\/), ors
    , neg
    , forall', exists'
    , foralls

    , total

    , Formula
    , Term
    , Prim(..)
    , ClType
    , Clause
    , clause
    , comment
    , numberedClause
    , clauseSplit
    , TyThing(..)
    , typeSig
    , typeSig'
    , sortSig
    , totalSig

    , axiom, lemma, hypothesis, definition
    , conjecture, negatedConjecture, question

    , axioms, definitions
    ) where

import Var

import Halo.FOL.Internals.Internals
import Halo.FOL.Operations

import Halo.MonoType

import Halo.Shared (isDataConId)

import Data.Generics.Geniplate

import Control.Monad

type Term'    = Term    Var Var MonoType'
type Formula' = Formula Var Var MonoType'
type Clause'  = Clause  Var Var MonoType'

type StrTerm    = Term    String String (MonoType String)
type StrFormula = Formula String String (MonoType String)
type StrClause  = Clause  String String (MonoType String)

comment :: String -> Clause q v t
comment = Comment

clause :: ClType -> Formula q v t -> Clause q v t
clause = Clause Nothing

numberedClause :: Int -> ClType -> Formula q v t -> Clause q v t
numberedClause = Clause . Just

clauseSplit :: ClType -> Formula q v t -> [Clause q v t]
clauseSplit cl_type = map (clause cl_type) . splitFormula

typeSig :: TyThing v t -> [t] -> t -> Clause q v t
typeSig = TypeSig

typeSig' :: TyThing v (MonoType t) -> MonoType t -> Clause q v (MonoType t)
typeSig' x = uncurry (TypeSig x) . splitType

sortSig :: t -> Clause q v t
sortSig = SortSig

totalSig :: t -> Clause q v t
totalSig = TotalSig

-- | Figure out if this var is one of the primitive constants, or if
--   it is a data constructor or a function, and make a term accordingly.
apply :: Var -> [Term q Var t] -> Term q Var t
apply x as
    | isDataConId x = Ctor x as
    | otherwise     = Fun x as

-- | Make a term of this primitive constant, constructor or CAF.
con :: Var -> Term q Var t
con x = apply x []

fun :: v -> [Term q v t] -> Term q v t
fun = Fun

fun0 :: v -> Term q v t
fun0 a = Fun a []

ctor :: v -> [Term q v t] -> Term q v t
ctor = Ctor

ctor0 :: v -> Term q v t
ctor0 a = Ctor a []

app :: t -> Term q v t -> Term q v t -> Term q v t
app = App

apps :: (Monad m,t ~ MonoType t') =>
        t -> Term q v t -> [Term q v t] -> m (Term q v t)
apps _ty            tm []     = return tm
apps ty@(TArr _ tr) tm (a:as) = apps tr (app ty tm a) as
apps _              _  _      = fail "apps: not on TArr! :("

proj :: Int -> v -> Term q v t -> Term q v t
proj = Proj

qvar :: q -> Term q v t
qvar = QVar

skolem :: v -> t -> Term q v t
skolem = Skolem

bottom :: t -> Term q v t
bottom = Bottom

ptr :: v -> t -> Term q v t
ptr = Ptr

prim :: Prim -> [Term q v t] -> Term q v t
prim = Prim

litInteger :: Integer -> Term q v t
litInteger = Lit

infix 4 ===
infix 4 =/=

(===),(=/=) :: Term q v t -> Term q v t -> Formula q v t
(===) = Equal
(=/=) = Unequal

infix 0 <=>

(<=>) :: Formula q v t -> Formula q v t -> Formula q v t
(<=>) = Equiv

(<==>) :: [Formula q v t] -> Formula q v t -> Formula q v t
[] <==> f = f
fs <==> f = ands fs <=> f

infixl 1 ==>
infixl 1 ===>

-- | Implication
(==>) :: Formula q v t -> Formula q v t -> Formula q v t
(==>) = Implies

-- | [l1,..,ln] ===> r means
--   l1 /\ .. /\ ln ==> r1
(===>) :: [Formula q v t] -> Formula q v t -> Formula q v t
[]  ===> f = f
phi ===> f = ands phi ==> f

infixr 2 \/
infixr 3 /\

(\/),(/\) :: Formula q v t -> Formula q v t -> Formula q v t
a \/ b = ors [a,b]
a /\ b = ands [a,b]

ands :: [Formula q v t] -> Formula q v t
ands []  = error "ands: Empty list"
ands [f] = f
ands fs  = And (concatMap flattenAnd fs)

flattenAnd :: Formula q v t -> [Formula q v t]
flattenAnd (And fs) = concatMap flattenAnd fs
flattenAnd f        = [f]

ors :: [Formula q v t] -> Formula q v t
ors []  = error "ors: Empty list"
ors [f] = f
ors fs  = Or (concatMap flattenOr fs)

flattenOr :: Formula q v t -> [Formula q v t]
flattenOr (Or fs) = concatMap flattenOr fs
flattenOr f       = [f]

neg :: Formula q v t -> Formula q v t
neg (Neg f)         = f
neg (Equal t1 t2)   = Unequal t1 t2
neg (Unequal t1 t2) = Equal t1 t2
neg (And fs)        = Or (map neg fs)
neg (Or fs)         = And (map neg fs)
neg (Implies f1 f2) = f1 /\ neg f2
neg (Equiv f1 f2)   = f1 `Equiv` neg f2
neg (Forall as f)   = Exists as (neg f)
neg (Exists as f)   = Forall as (neg f)
neg f               = Neg f

forall' :: [(q,t)] -> Formula q v t -> Formula q v t
forall' [] f = f
forall' as (Forall bs f) = Forall (as ++ bs) f
forall' as f             = Forall as f

exists' :: [(q,t)] -> Formula q v t -> Formula q v t
exists' [] f = f
exists' as (Exists bs f) = Exists (as ++ bs) f
exists' as f             = Exists as f

foralls :: (UniverseBi (Formula q v t) (Formula q v t)
           ,UniverseBi (Formula q v t) (Term q v t)
           ,Monad m,Ord q)
        => (q -> m t) -> Formula q v t -> m (Formula q v t)
foralls get_type f = do
    quant_list <- sequence [ (,) q `liftM` get_type q | q <- allQuant f ]
    return $ forall' quant_list f

total :: t -> Term q v t -> Formula q v t
total = Total

-- | Split the conjuncts of a formula over many formulae,
--   distributing any foralls over them
splitFormula :: Formula q v t -> [Formula q v t]
splitFormula (Forall vs fs) = map (forall' vs) (splitFormula fs)
splitFormula (And fs)       = concatMap splitFormula fs
splitFormula f              = [f]

-- | Split conjuncts in many formulae at once
splitFormulae :: [Formula q v t] -> [Formula q v t]
splitFormulae = concatMap splitFormula


-- Clause types

lemma :: ClType
lemma = Lemma

axiom :: Formula q v t -> Clause q v t
axiom = clause Axiom

hypothesis :: Formula q v t -> Clause q v t
hypothesis = clause Hypothesis

definition :: Formula q v t -> Clause q v t
definition = clause Definition

conjecture :: Formula q v t -> Clause q v t
conjecture = clause Conjecture

negatedConjecture :: Formula q v t -> Clause q v t
negatedConjecture = clause NegatedConjecture

question :: ClType
question = Question

-- Making many clauses

axioms :: [Formula q v t] -> [Clause q v t]
axioms = map axiom

definitions :: [Formula q v t] -> [Clause q v t]
definitions = map definition


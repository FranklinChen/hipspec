-- Linearises (pretty prints) our FOL representation into SMT
-- TODO: add abstract types (newtypes): to be declared with declare-sort
module Halo.FOL.LineariseSMT (linSMT,addUnsatCores,linClause,sexpr) where


import Var
import TyCon

import Halo.MonoType
import Halo.Shared
import Halo.FOL.Internals.Internals
import Halo.FOL.Abstract (Clause',Formula',Term',neg)

import qualified Data.Map as M
import Data.Map (Map)
import Data.Maybe
import Data.List
import Data.Ord

sexpr :: Int -> SExpr -> String
sexpr i se = case se of
    Atom s     -> s
    SComment s -> intercalate newline (map ("; " ++) (lines s))
    List ses   -> "(" ++ intercalate newline (map (sexpr (i + 2)) ses) ++ ")"
    Named e s  -> "(!" ++ newline ++ sexpr (i + 2) e ++ newline ++ " :named " ++ s ++ ")"
  where
    newline = "\n" ++ replicate i ' '

data SExpr
    = Atom String
    | List [SExpr]
    | Named SExpr String
    | SComment String

apply :: String -> [SExpr] -> SExpr
apply s args = List (Atom s:args)

addUnsatCores :: String -> String
addUnsatCores s =
    "(set-option :produce-unsat-cores true)\n" ++ s ++
    "\n(get-unsat-core)\n"

linSMT :: [Clause'] -> String
linSMT = unlines . map (sexpr 2) . (++ [apply "check-sat" []]) . map linClause . sortBy (comparing inj)
  where
    inj SortSig{}  = 0 :: Int
    inj TotalSig{} = 1
    inj TypeSig{}  = 1
    inj _          = 2

-- signatures
linSig :: TyThing Var MonoType' -> [MonoType'] -> MonoType' -> SExpr
linSig th args res = case args of
    [] -> apply "declare-const" [Atom s , Atom (monotype res)]
    _ -> apply "declare-fun"
        [ Atom s
        , List (map (Atom . monotype) args)
        , Atom (monotype res)
        ]
  where
    s = linThing th

linThing :: TyThing Var MonoType' -> String
linThing th = case th of
    AFun v    -> fun v
    ACtor v   -> con v
    AnApp t   -> app t
    ASkolem v -> skolem v
    AProj i v -> proj i v
    APtr v    -> ptr v
    ABottom t -> bottom t

linTotalSig :: MonoType' -> SExpr
linTotalSig t = apply "declare-fun"
    [ Atom (total t) , List [Atom (monotype t)] , Atom bool ]

linSort :: MonoType' -> SExpr
linSort t = apply "declare-sort" [Atom (monotype t)]

-- Clauses
linClause :: Clause' -> SExpr
linClause cl = case cl of
    Comment s -> SComment s
    TypeSig th ts t -> linSig th ts t
    SortSig t       -> linSort t
    TotalSig t      -> linTotalSig t
    Clause cl_name cl_type f -> apply "assert"
        [maybe_name (linForm (maybe_neg f))]
      where
        maybe_neg = case cl_type of
            Conjecture -> neg
            _          -> id

        maybe_name = case cl_name of
            Nothing -> id
            Just i  -> flip Named ("lemma_" ++ show i ++ "_")

-- Formulae
linForm :: Formula' -> SExpr
linForm form = case form of
    Equal   t1 t2    -> apply "=" (map linTerm [t1,t2])
    Unequal t1 t2    -> apply "distinct" (map linTerm [t1,t2])
    And fs           -> apply "and" (map linForm fs)
    Or  fs           -> apply "or" (map linForm fs)
    Implies f1 f2    -> apply "=>" (map linForm [f1,f2])
    Equiv f1 f2      -> apply "=" (map linForm [f1,f2])
    Forall qs f      -> apply "forall" [linQList qs,linForm f]
    Exists qs f      -> apply "exists" [linQList qs,linForm f]
    Total t tm       -> apply "=" [Atom true,apply (total t) [linTerm tm]]
    Neg (Total t tm) -> apply "=" [Atom false,apply (total t) [linTerm tm]]
    Neg f            -> apply "not" [linForm f]

linQList :: [(Var,MonoType')] -> SExpr
linQList qs = List [ apply (qvar q) [Atom $ monotype t] | (q,t) <- qs ]

-- Terms
linTerm :: Term' -> SExpr
linTerm tm = case tm of
    Fun a []     -> Atom (fun a)
    Fun a tms    -> apply (fun a) (map linTerm tms)
    Ctor a []    -> Atom (con a)
    Ctor a tms   -> apply (con a) (map linTerm tms)
    Skolem a _   -> Atom (skolem a)
    App t t1 t2  -> apply (app t) (map linTerm [t1,t2])
    Proj i c t   -> apply (proj i c) [linTerm t]
    Ptr a _      -> Atom (ptr a)
    Bottom t     -> Atom (bottom t)
    QVar a       -> Atom (qvar a)
    Lit i        -> Atom (show i)
    Prim _p _tms -> error "prim"

-- Utilities
monotype :: MonoType' -> String
monotype (TCon tc)    = tcon tc
monotype (TArr t1 t2) = "from_" ++ monotype t1 ++ "_to_" ++ monotype t2

showVar :: Var -> String
showVar v = (\ s -> show (varUnique v) ++ "_" ++ s) . escape . idToStr $ v

bottom :: MonoType' -> String
bottom = ("bot_" ++) . monotype

total :: MonoType' -> String
total = ("total_" ++) . monotype

app :: MonoType' -> String
app = ("app_" ++) . monotype

fun :: Var -> String
fun = ("f_" ++) . showVar

ptr :: Var -> String
ptr = ("p_" ++) . showVar

con :: Var -> String
con = ("c_" ++) . showVar

proj :: Int -> Var -> String
proj i v = "p_" ++ show i ++ "_" ++ showVar v

tcon :: TyCon -> String
tcon tc = "t_" ++ show (tyConUnique tc) ++ "_" ++ escape (showOutputable (tyConName tc))

skolem :: Var -> String
skolem = ("sk_" ++) . showVar

qvar :: Var -> String
qvar = ("q_" ++) . showVar

bool :: String
bool = "Bool"

true :: String
true = "true"

false :: String
false = "false"

-- | Escaping
escape :: String -> String
escape = concatMap (\c -> fromMaybe [c] (M.lookup c escapes))

-- | Some kind of z-encoding escaping
escapes :: Map Char String
escapes = M.fromList $ map (uncurry (flip (,)))
    [ ("z_",'\'')
    , ("z1",'(')
    , ("z2",')')
    , ("za",'@')
    , ("zb",'!')
    , ("zB",'}')
    , ("zc",':')
    , ("zC",'%')
    , ("zd",'$')
    , ("ze",'=')
    , ("zG",'>')
    , ("zh",'-')
    , ("zH",'#')
    , ("zi",'|')
    , ("zl",']')
    , ("zL",'<')
    , ("zm",',')
    , ("zn",'&')
    , ("zo",'.')
    , ("zp",'+')
    , ("zq",'?')
    , ("zr",'[')
    , ("zR",'{')
    , ("zs",'*')
    , ("zS",' ')
    , ("zt",'~')
    , ("zT",'^')
    , ("zv",'/')
    , ("zV",'\\')
    , ("zz",'z')
    ]


{-

linPrim :: Prim -> SDoc
linPrim p = case p of
    Add -> char '+'
    Sub -> char '-'
    Mul -> char '*'
    Eq  -> char '='
    Ne  -> text "!=" -- will this work?
    Lt  -> char '<'
    Le  -> text "<="
    Ge  -> text ">="
    Gt  -> char '>'
    LiftBool -> linLiftBool

linLiftBool :: SDoc
linLiftBool = text "lift_bool"

linLiftBoolDefn :: SDoc
linLiftBoolDefn = vcat $
    linDeclFun linLiftBool [linBool] linDomain :
    [ parens $ text "assert" <+>
        parens (equals <+> parens (linLiftBool <+> text in_bool)
                       <+> in_domain)
    | (in_bool,in_domain) <-
        [("true",linCtor (dataConWorkId trueDataCon))
        ,("false",linCtor (dataConWorkId falseDataCon))
        ]
    ]

primType :: Prim -> ([SDoc],SDoc)
primType p = case p of
    Add      -> int_int_int
    Sub      -> int_int_int
    Mul      -> int_int_int
    Eq       -> int_int_bool
    Ne       -> int_int_bool
    Lt       -> int_int_bool
    Le       -> int_int_bool
    Ge       -> int_int_bool
    Gt       -> int_int_bool
    LiftBool -> ([linBool],linDomain)
  where
    int_int_int  = ([linInt,linInt],linInt)
    int_int_bool = ([linInt,linInt],linBool)
 -}
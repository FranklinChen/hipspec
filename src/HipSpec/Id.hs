{-# LANGUAGE CPP #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE PatternGuards #-}
module HipSpec.Id where

import Name hiding (varName)
-- import BasicTypes (TupleSort(..))
import PrelNames
import HipSpec.GHC.Utils
import Var (Var,varName,idDetails,TyVar,tyVarName)
import IdInfo (IdDetails(..))
import TyCon (tyConName,TyCon)
import DataCon (dataConName,DataCon)
import Data.Char (toUpper)

import qualified QuickSpec.Term as QS
import qualified QuickSpec.Type as QS
import qualified QuickSpec.Base as QS -- (prettyShow)

idFromName :: Name -> Id
idFromName = GHCOrigin

idFromDataCon :: DataCon -> Id
idFromDataCon = idFromName . dataConName

idFromVar :: Var -> Id
idFromVar i = case idDetails i of
    DataConWorkId dc -> idFromDataCon dc
    DataConWrapId dc -> idFromDataCon dc
    _                -> idFromName (varName i)

idFromTyVar :: TyVar -> Id
idFromTyVar = idFromName . tyVarName

idFromTyCon :: TyCon -> Id
idFromTyCon = idFromName . tyConName

tryGetGHCName :: Id -> Maybe Name
tryGetGHCName (GHCOrigin nm) = Just nm
tryGetGHCName _              = Nothing

data Id
    = GHCOrigin Name
    | QSVariable QS.Variable
    | QSTyVar QS.TyVar
    | QSPropId Integer
    | Derived Derived Integer
    | Const Int Int
  deriving (Eq,Ord,Show)

instance Show Name where
    show nm = show (showOutputable nm)

data Derived
    = Id `LetFrom` Id
    | Lambda Id
    | Case Id
    | Eta
    | Skolem Id
    | TvSkolem Id
    | Unknown
    | GenTyVar
    | Id `Fix` BW
  deriving (Eq,Ord,Show)

-- we turn {f = .. f ..}
-- into    {fB = .. fW ..}
data BW = B | W
  deriving (Eq,Ord,Show)

mkLetFrom :: Id -> Integer -> Id -> Id
mkLetFrom x _ (Derived Unknown _) = x
mkLetFrom x i y                   = Derived (x `LetFrom` y) i

originalId :: Id -> String
originalId i = case i of
    GHCOrigin nm  -> getOccString nm
    QSVariable v  -> QS.prettyShow v
    QSTyVar tv    -> QS.prettyShow tv
    Const 0 2     -> "const"
    Const i j     -> "const_" ++ show i ++ "_" ++ show j
    Derived d _   -> case d of
        _ `LetFrom` b -> originalId b ++ "_"
        Lambda a      -> originalId a ++ "_lambda"
        Case a        -> originalId a ++ "_case"
        Skolem a      -> originalId a
        TvSkolem a    -> map toUpper (originalId a)
        Eta           -> "x"
        Unknown       -> "u"
        GenTyVar      -> "a"
        f `Fix` _bw   -> "{" ++ originalId f ++ "}"

-- | Pretty prints an Id.
--   Not necessarily to a unique String, the Renamer takes care of proper
--   disabiguation.
ppId :: Id -> String
ppId i = case i of
    GHCOrigin nm  -> ppName nm
    QSVariable v  -> QS.prettyShow v
    QSTyVar tv    -> QS.prettyShow tv
    Derived d x   -> ppDerived x d
    Const 0 2     -> "const"
    Const i j     -> "const_" ++ show i ++ "_" ++ show j

ppDerived :: Integer -> Derived -> String
ppDerived i d = case d of
    f `LetFrom` g -> (case ppId g of { [] -> ""; s -> s ++ "_" }) ++ ppId f
    Lambda f      -> "lam_" ++ ppId f
    Case f        -> "case_" ++ ppId f
    Eta           -> "eta"
    Skolem x      -> ppId x
    TvSkolem x    -> map toUpper (ppId x)
    GenTyVar      -> [['a'..'z'] !! (fromInteger i `mod` 26)]
    Unknown       -> "unknown"
    f `Fix` bw    -> ppId f ++ show bw

ppName :: Name -> String
ppName nm -- = getOccString nm {- ++ '_': showOutputable (getUnique nm) -}
    | k == listTyConKey      = "List"
    | k == nilDataConKey     = "Nil"
    | k == consDataConKey    = "Cons"
    | k == unitTyConKey      = "UnitTyCon"
    | k == genUnitDataConKey = "Unit"
    | otherwise = case getOccString nm of
        "+"   -> "plus"
        "-"   -> "minus"
        "/"   -> "div"
        "*"   -> "mult"
        "^"   -> "pow"
        "++"  -> "append"
        ">>=" -> "bind"
        "=<<" -> "dnib"
        ">=>" -> "dot_monadic"
        "<=<" -> "monadic_dot"
        "<*>" -> "ap"
        "<$>" -> "fmap"
        ">>"  -> "then"
        "||"  -> "or"
        "&&"  -> "and"
        "."   -> "dot"
        "=="  -> "equal"
        "/="  -> "unequal"
        ">"   -> "gt"
        ">="  -> "ge"
        "<"   -> "lt"
        "<="  -> "le"
        "$"   -> "apply"
        "!!"  -> "index"
        "\\\\" -> "difference"
        s     -> s
  where
    k = getUnique nm


{-

    An attempt to handle class dictionaries

-}
module Halo.Class ( classBinds , dictDeps ) where

import Class
import CoreFVs
import CoreSyn
import DataCon
import GHC (dataConType)
import Id
import Type
import Var
import VarSet
import TyCon

import Halo.Names
import Halo.Subtheory
import Halo.Util

import Data.Maybe

classBinds :: [TyCon] -> [CoreBind]
classBinds ty_cons =
    [ NonRec method_id $
        flip (foldr Lam) (classTyVars cls ++ [v']) $
            Case (Var v') w' (varType v')
                [(DataAlt dc,ty_vars ++ xs',Var (xs' !! i))]
    | cls <- classes
    , DataTyCon [dc] _ <- [algTyConRhs (classTyCon cls)]
    , let v:w:xs  = varNames
          [v',w'] = map (`setVarType` (snd . splitFunTys . dropForAlls $ dataConType dc)) [v,w]
          ty_vars = dataConAllTyVars dc
          xs'     = zipWith (\u m -> setVarType u (varType m)) xs (classMethods cls)
    , (i,method_id) <- zip [0..] (classMethods cls)
    ]
  where
    classes = nubSorted (mapMaybe tyConClass_maybe ty_cons)

dictDeps :: CoreExpr -> [Content s]
dictDeps = functions . varSetElems
         . exprSomeFreeVars (\v -> isId v && isJust (isClassOpId_maybe v))

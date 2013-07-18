{-# LANGUAGE RecordWildCards, DisambiguateRecordFields, NamedFieldPuns #-}
module HipSpec.Init (processFile) where

import Control.Monad


import Data.List (partition)
import Data.Void

import HipSpec.Calls
import HipSpec.Monad
import HipSpec.ParseDSL
import HipSpec.Property
import HipSpec.Read
import HipSpec.Theory
import HipSpec.Translate
import HipSpec.Params

import Lang.FreeTyCons
import Lang.RemoveDefault
import Lang.Unfoldings
import Lang.Uniquify

import qualified Lang.RichToSimple as S
import qualified Lang.Simple as S

import TyCon (isAlgTyCon)
import UniqSupply

import System.Exit

processFile :: ([Property Void] -> HS a) -> IO a
processFile cont = do

    params@Params{..} <- fmap sanitizeParams (cmdArgs defParams)

    var_props <- execute file

    us0 <- mkSplitUniqSupply 'h'

    let not_dsl x = not $ any ($x) [isEquals, isGiven, isGivenBool, isProveBool]

        vars = filterVarSet not_dsl $
               unionVarSets (map transCalls var_props)

        (binds,_us1) = initUs us0 $ sequence
            [ fmap ((,) v) (runUQ . uqExpr <=< rmdExpr $ e)
            | v <- varSetElems vars
            , Just e <- [maybeUnfolding v]
            ]

        tcs = filter (\ x -> isAlgTyCon x && not (typeIsProp x))
                     (exprsTyCons (map snd binds))

        (am_tcs,data_thy,ty_env') = trTyCons tcs

        -- Now, split these into properties and non-properties

        simp_fns = toSimp binds

        is_prop (S.Function (_ S.::: t) _ _) =
            case res of
                S.TyCon (S.Old p) _ -> typeIsProp p
                _                   -> False

          where
            (_tvs,t')   = S.collectForalls t
            (_args,res) = S.collectArrTy t'

        (props,fns) = partition is_prop simp_fns

        am_fin = am_fns `combineArityMap` am_tcs
        (am_fns,binds_thy) = trSimpFuns am_fin fns

        thy = appThy : data_thy ++ binds_thy

        cls = sortClauses (concatMap clauses thy)

        tr_props = either (error . show) (map etaExpandProp) (trProperties props)

        env = Env { theory = thy, arity_map = am_fin, ty_env = ty_env' }

    runHS params env $ do

        debugWhen PrintSimple $ "\nSimple Definitions\n" ++ unlines (map showSimp fns)

        debugWhen PrintPolyFOL $ "\nPoly FOL Definitions\n" ++ ppAltErgo cls

        debugWhen PrintProps $
            "\nProperties in Simple Definitions:\n" ++ unlines (map showSimp props) ++
            "\nProperties:\n" ++ unlines (map show tr_props)

        when (TranslateOnly `elem` debug_flags) (liftIO exitSuccess)

        cont tr_props

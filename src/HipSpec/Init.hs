{-# LANGUAGE RecordWildCards, DisambiguateRecordFields, NamedFieldPuns #-}
module HipSpec.Init (processFile,SigInfo(..)) where

import Control.Monad

import Data.List (partition,union)

import HipSpec.GHC.Calls
import HipSpec.Monad
import HipSpec.ParseDSL
import HipSpec.Property
import HipSpec.Read
import HipSpec.Theory
import HipSpec.Translate
import HipSpec.Params
import HipSpec.Lint
import HipSpec.Utils
import HipSpec.Id

import HipSpec.FixpointInduction

import HipSpec.GHC.Utils
import HipSpec.GHC.FreeTyCons
import HipSpec.Lang.RemoveDefault
import HipSpec.GHC.Unfoldings
import HipSpec.GHC.Dicts (inlineDicts)
import HipSpec.Lang.Uniquify

import HipSpec.Heuristics.CallGraph

import qualified HipSpec.Lang.SimplifyRich as S
import qualified HipSpec.Lang.Simple as S

import TyCon (isAlgTyCon)
import TysWiredIn (boolTyCon)
import UniqSupply

import System.Exit
import System.Process
import System.FilePath
import System.Directory

import qualified Id as GHC
import qualified CoreSubst as GHC
import Var (Var)
import Data.Map (Map)

import Data.Maybe (isNothing)

processFile :: (Map Var [Var] -> [SigInfo] -> [Property] -> HS a) -> IO a
processFile cont = do

    params@Params{..} <- fmap sanitizeParams (cmdArgs defParams)

    whenFlag params PrintParams $ putStrLn (ppShow params)

    maybe (return ()) setCurrentDirectory directory

    EntryResult{..} <- execute params

    let vars = filterVarSet (not . varFromPrelude) $
               unionVarSets (map (transCalls Without) prop_ids)

        callg = idCallGraph (varSetElems vars)

    us0 <- mkSplitUniqSupply 'h'

    let (binds,_us1) = initUs us0 $ sequence
            [ fmap ((,) v) (runUQ . uqExpr <=< rmdExpr $ inlineDicts e)
            | v <- varSetElems vars
            , isNothing (GHC.isClassOpId_maybe v)
            , Just e <- [maybeUnfolding v]
            ]

        tcs = filter (\ x -> isAlgTyCon x && not (isPropTyCon x))
                     (bindsTyCons' binds `union` extra_tcs `union` [boolTyCon])

        (am_tcs,data_thy,ty_env') = trTyCons tcs

        rich_fns = toRich binds ++ [S.fromProverBoolDefn]

    let rich_fns_opt = S.unTagToEnum (S.integerToInt (S.unpackStrings (S.simpFuns (map S.etaExpand rich_fns))))

        simp_fns :: [S.Function Id]
        simp_fns = toSimp rich_fns_opt

        -- Now, split these into properties and non-properties
        is_prop (S.Function _ (S.Forall _ t) _ _) = isPropType t

        (props,fns0) = partition is_prop simp_fns

        fns_fix = fixFunctions fns0
        fns = fns0 ++ fns_fix

        is_recursive x = case [ fn | fn <- fns, S.fn_name fn == x ] of
            f:_ -> isRecursive f
            []  -> False

        (am_fns,binds_thy) = trSimpFuns am_fin fns
        am_fin = am_fns `combineArityMap` am_tcs `combineArityMap` primOpArities

        cls = sortClauses False (concatMap clauses thy)

        thy = appThy : data_thy ++ binds_thy

        tr_props
            = sortOn prop_name
            $ either (error . show)
                     (map (etaExpandProp{- . generaliseProp-}))
                     (trProperties props)

        env = Env
            { theory = thy, arity_map = am_fin, ty_env = ty_env'
            , is_recursive = is_recursive
            }

    runHS params env $ do

        debugWhen PrintCore $ "\nInit prop_ids\n" ++ showOutputable prop_ids
        debugWhen PrintCore $ "\nInit vars\n" ++ showOutputable vars

        debugWhen PrintCore $ "\nGHC Core\n" ++ showOutputable
            [ (v,GHC.idType v, GHC.idDetails v, e)
            | (v,e) <- binds
            ]

        debugWhen PrintRich $ "\nRich Definitions\n" ++ unlines (map showRich rich_fns)

        debugWhen PrintOptRich $ "\nOptimised Rich Definitions\n" ++ unlines (map showRich rich_fns_opt)

        debugWhen PrintSimple $ "\nSimple Definitions\n" ++ unlines (map showSimp fns)

        debugWhen PrintPolyFOL $ "\nPoly FOL Definitions\n" ++ ppAltErgo cls

        debugWhen PrintProps $
            "\nProperties in Simple Definitions:\n" ++ unlines (map showSimp props) ++
            "\nProperties:\n" ++ unlines (map show tr_props)

        checkLint (lintSimple simp_fns)
        mapM_ (checkLint . lintProperty) tr_props

        whenFlag params LintPolyFOL $ liftIO $ do
            let mlw = replaceExtension file ".mlw"
            writeFile mlw (ppAltErgo cls)
            exc <- system $ "alt-ergo -type-only " ++ mlw
            case exc of
                ExitSuccess -> return ()
                ExitFailure n -> error $ "PolyFOL-linting by alt-ergo exited with exit code" ++ show n

        when (TranslateOnly `elem` debug_flags) (liftIO exitSuccess)

        cont callg sig_infos tr_props


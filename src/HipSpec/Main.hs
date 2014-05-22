{-# LANGUAGE RecordWildCards, NamedFieldPuns, DoAndIfThenElse, ViewPatterns, CPP, PatternGuards #-}
module Main where

import Test.QuickSpec.Main (prune)
import Test.QuickSpec.Term (totalGen,Term,Expr,term,funs,Symbol)
import Test.QuickSpec.Equation (Equation(..), equations, TypedEquation(..), eraseEquation)
import Test.QuickSpec.Generate
import Test.QuickSpec.Signature
import Test.QuickSpec.Utils.Typed
-- import Test.QuickSpec.TestTotality
import qualified Test.QuickSpec.Utils.TypeMap as TypeMap
import qualified Test.QuickSpec.TestTree as TestTree

import qualified Test.QuickSpec.Reasoning.NaiveEquationalReasoning as NER
-- import qualified Test.QuickSpec.Reasoning.PartialEquationalReasoning as PER

import HipSpec.Reasoning

import Data.Void

import HipSpec.Params (SuccessOpt(..))

import HipSpec.ThmLib
import HipSpec.Property hiding (Literal(..))
import HipSpec.Sig.QSTerm
import HipSpec.Init
import HipSpec.Monad hiding (equations)
import HipSpec.MainLoop

import HipSpec.Heuristics.Associativity
import HipSpec.Heuristics.CallGraph
import HipSpec.Utils

import HipSpec.Sig.Definitions

import Prelude hiding (read)

import qualified Data.Map as M

import Data.List
import Data.List.Split
import Data.Maybe
import Data.Ord
import Data.Function

import Control.Monad

#ifdef SUPPORT_JSON
import Data.Aeson (encode)
import qualified Data.ByteString.Lazy as B
#endif

import System.Exit (exitSuccess,exitFailure)

main :: IO ()
main = processFile $ \ callg m_sig_info user_props -> do
    writeMsg FileProcessed

    exit_act <- case m_sig_info of

        [] -> snd <$> runMainLoop NoCC user_props []

        sig_info@SigInfo{..}:sig_infos -> do

            Params{explore_theory,user_stated_first,call_graph,isabelle_mode} <- getParams

            (init_qsconjs,reps,classes) <- runQuickSpec sig_info

            extra_conjs <- concatMapM (fmap (\ (q,_,_) -> q) . runQuickSpec) sig_infos

            let drop_precond s = case splitOn " ==> " s of
                    [_,post] -> post
                    _        -> s

                qsconjs = callg_sort
                    $ nubBy ((==) `on` drop_precond . prop_repr)
                    $ init_qsconjs ++
                      [ p { prop_origin = UserStated }
                      | p <- extra_conjs, not (null (prop_assums p))
                      ]

                callg_sort = if call_graph then cgSortProps callg else id

                (~+) | user_stated_first = flip (++)
                     | otherwise         = (++)

            let ctx_init = NER.initial (maxDepth sig) (symbols sig) reps

            Env{theory} <- getEnv

            let def_eqs = definitions theory symbol_map

                ctx_with_def = execEQR ctx_init (mapM_ unify def_eqs)

            when isabelle_mode $ do
                liftIO $ do
                    mapM_ putStrLn
                        $ map prop_repr
                        $ filter (maybe True (not . evalEQR ctx_with_def . equal) . propEquation)
                        $ qsconjs
                    exitSuccess

            mapM_ (checkLint . lintProperty) qsconjs

            debugWhen PrintProps $ "\nQuickSpec Properties:\n" ++
                unlines (map show qsconjs)

            debugWhen PrintDefinitions $ "\nDefinitions as QuickSpec Equations:\n" ++
                unlines (map show def_eqs)


            (ctx_final,exit_act) <- runMainLoop ctx_with_def
                                     (qsconjs ~+ map vacuous user_props)
                                     []

            when explore_theory $ do
                let pruner   = prune ctx_init (map erase reps) id
                    provable = evalEQR ctx_final . equal
                    explored_theory
                        = filter (not . evalEQR ctx_with_def . equal)
                        $ pruner $ filter provable
                        $ map (some eraseEquation) (equations classes)
                writeMsg $ ExploredTheory $ map (showEquation sig) explored_theory

            return exit_act

#ifdef SUPPORT_JSON
    Params{json} <- getParams

    case json of
        Just json_file -> do
            msgs <- getMsgs
            liftIO $ B.writeFile json_file (encode msgs)
        Nothing -> return ()
#endif

    vacuous exit_act

runMainLoop :: EQR eq ctx cc => ctx -> [Property eq] -> [Theorem eq] -> HS (ctx,HS Void)
runMainLoop ctx_init initial_props initial_thms = do

    params@Params{only_user_stated,success,file} <- getParams

    whenFlag params QuickSpecOnly (liftIO exitSuccess)

    (theorems,conjectures,ctx_final) <- mainLoop ctx_init initial_props initial_thms

    let showProperties ps = [ (prop_name p,maybePropRepr p) | p <- ps ]
        theorems' = map thm_prop
                  . filter (\ t -> not (definitionalTheorem t) || isUserStated (thm_prop t))
                  $ theorems
        notQS  = filter (not . isFromQS)
        fromQS = filter isFromQS

    writeMsg Finished
        { proved      = showProperties $ notQS theorems'
        , unproved    = showProperties $ notQS conjectures
        , qs_proved   = showProperties $ fromQS theorems'
        , qs_unproved =
            if only_user_stated then [] else showProperties $ fromQS conjectures
        }

    let exit_act = liftIO $ case success of
            NothingUnproved -> do
                putStr (file ++ ", " ++ show success ++ ":")
                if null conjectures
                    then putStrLn "ok" >> exitSuccess
                    else putStrLn "fail" >> exitFailure
            ProvesUserStated -> do
                putStr (show success ++ ":")
                if null (notQS conjectures)
                    then putStrLn "ok" >> exitSuccess
                    else putStrLn "fail" >> exitFailure
            CleanRun -> exitSuccess

    return (ctx_final,exit_act)

runQuickSpec :: SigInfo -> HS ([Property Equation],[Tagged Term],[Several Expr])
runQuickSpec sig_info@SigInfo{..} = do

    params@Params{..} <- getParams

    let callg = transitiveCallGraph resolve_map

    debugWhen PrintCallGraph $ "\nCall Graph:\n" ++ unlines
        [ show s ++ " calls " ++ show ss
        | (s,ss) <- M.toList callg
        ]

    r <- liftIO $ generate isabelle_mode (const totalGen) sig
                        -- shut up if we're on isabelle mode

    let classes = concatMap (some2 (map (Some . O) . TestTree.classes)) (TypeMap.toList r)
        eq_order eq = (assoc_important && not (eqIsAssoc eq), eq)
        swapEq (t :=: u) = u :=: t

        equations' :: [Several Expr] -> [Some TypedEquation]
        equations' = concatMap (several (map Some . toEquations))

        -- all the symbols this term calls, transitively
        term_calls :: Expr a -> [Symbol]
        term_calls e
            = nubSorted
            . concat
            . mapMaybe (`M.lookup` callg)
            . funs . term $ e

        eq_calls :: TypedEquation a -> [Symbol]
        eq_calls (e1 :==: e2) = nubSorted (term_calls e1 ++ term_calls e2)

        -- Nick says that we added this when translating the equivalence
        -- classes to equations. For each non-representative, we try to
        -- pick a representative that calls only functions called by the
        -- non-representative, otherwise at least try to minimize the
        -- set of extra functions it calls.
        toEquations :: [Expr a] -> [TypedEquation a]
        toEquations es@(x:xs)
            | call_graph = [ toEquation y (reverse ys)
                           | y:ys <- tails (reverse es)
                           , not (null ys)
                           ]
            | otherwise = [ y :==: x | y <- xs ]
        toEquations [] = error "HipSpec.toEquations internal error"

        toEquation :: Expr a -> [Expr a] -> TypedEquation a
        toEquation e rcs = foldr1 best (map (e :==:) rcs)
          where
            -- invariant: eq1 < eq2 wrt equation size
            best eq1 eq2
                -- eq1 is clearly the right representative,
                -- no new functions called by representative
                | eq_calls eq1 == term_calls e             = eq1
                | eq_calls eq2 `isSupersetOf` eq_calls eq1 = eq1
                | otherwise                                = eq2

        cmp = comparing (eq_order . (swap_repr ? swapEq))

        classToEqs :: [Several Expr] -> [Some TypedEquation]
        classToEqs
            | quadratic = concatMap ( several (map (Some . uncurry (:==:))
                                    . uniqueCartesian))
            | otherwise = equations'

        ctx_init  = NER.initial (maxDepth sig) (symbols sig) reps

        reps = map (some2 (tagged term . head)) classes

        pruner    = prune ctx_init (map erase reps) (some eraseEquation)
        prunedEqs = pruner (equations classes)
        eqs       = prepend_pruned ? (prunedEqs ++)
                  $ sortBy (cmp `on` some eraseEquation)
                  $ classToEqs classes

    debugWhen PrintEqClasses $ "\nEquivalence classes:\n" ++ unlines
        (map (show . several (map term)) classes)

    writeMsg $ QuickSpecDone (length classes) (length eqs)

{-
    when isabelle_mode $ do
        Env{theory} <- getEnv
        let def_eqs  = definitions theory symbol_map
            ctx_defs = execEQR ctx_init (mapM_ unify def_eqs)
--            pruner'  = prune ctx_init (map erase reps) (some eraseEquation)
        debugWhen PrintDefinitions $ "\nDefinitions as QuickSpec Equations:\n" ++
            unlines (map show def_eqs)
        liftIO $ do
            mapM_ putStrLn
                $ nub
                $ map isabelleShowPrecondition
                $ filter (\(pre, _) -> length pre == cond_count)
                $ concatMap isabelleFilterEquations
                $ groupBy ((==) `on` snd)
                $ sortBy (comparing snd)
                $ map (isabelleShowEquation cond_name sig)
      --          $ map show
                $ filter (not . evalEQR ctx_defs . equal)
                $ map (some eraseEquation) eqs -- prunedEqs
            exitSuccess
            -}

    let conjs =
            [ (etaExpandProp . generaliseProp . eqToProp params sig_info i) eq
            | (eq0,i) <- zip eqs [0..]
            , let eq = some eraseEquation eq0
            ]


    return (conjs,reps,classes)


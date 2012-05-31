{-# LANGUAGE DeriveDataTypeable,RecordWildCards #-}
module Hip.Params where

import System.Console.CmdArgs

data Params = Params { files           :: [FilePath]
                     , output          :: Maybe FilePath
                     , warnings        :: Bool

                     , processes       :: Int
                     , batchsize       :: Int
                     , timeout         :: Int
                     , provers         :: String
                     , methods         :: String
                     , consistency     :: Bool
                     , isolate         :: Bool
                     , cnf             :: Bool

                     , swap_repr      :: Bool
                     , prepend_pruned :: Bool
                     , quadratic      :: Bool

                     , inddepth        :: Int
                     , indvars         :: Int
                     , indhyps         :: Int
                     , indparts        :: Int
                     }
  deriving (Show,Data,Typeable)

defVal    x = x &= opt x

defInt :: Int -> Int
defInt x = x &= opt x

defParams :: Params
defParams = Params
  { files          = []      &= args   &= typFile
  , warnings       = False   &= help "Show warnings from translation"
  , output         = Nothing &= opt "proving/" &= typDir &= help "Save tptp files in a directory (default proving/)"

  , processes      = 2       &= groupname "\nProving settings"
                             &= name "p" &= help "Prover processes (default 2)"
  , batchsize      = 2       &= name "b" &= help "Equations to process simultaneously (default 2)"
  , timeout        = 1       &= name "t" &= help "Timeout of provers in seconds (default 1)"
  , provers        = "e"     &= help "Provers to use (e)prover (v)ampire (V)ampire 64-bit (s)pass equino(x) (z)3 (default e)"
  , methods        = "pi"    &= help "Methods to use (p)lain definition equality, (i)nduction (default pi)"
  , consistency    = False   &= help "Add a consistency axiom"
  , isolate        = False   &= help "Isolate user props, i.e. do not use user stated properties as lemmas"
  , cnf            = False   &= help "Write clauses in cnf"

  , swap_repr      = False &= groupname "\nEquation ordering"
                           &= help "Swap equations with their representative"
  , prepend_pruned = False &= help "Add nice pruned equations from in front"
  , quadratic      = False &= help "All pairs of equations"

  , inddepth       = 1     &= groupname "\nStructural induction"
                           &= help "Maximum depth                   (default 1)"
  , indvars        = 1     &= help "Maximum variables               (default 1)"
  , indhyps        = 200   &= help "Maximum hypotheses              (default 200)"
  , indparts       = 10    &= help "Maximum parts (bases and steps) (default 10)"
  }
  &= summary ("\n\nHipSpec v0.1 Dan Rosén danr@student.gu.se" ++
              "\nQuickSpec by Nicholas Smallbone nicsma@chalmers.se" ++
              "\n             and Koen Claessen koen@chalmers.se")
  &= program "hipspec"


module Main where

import Prelude(undefined,Bool(..),IO,flip,($))

import HipSpec.Prelude
import HipSpec
import Definitions
import Properties

main :: IO ()
main = hipSpec "Part66.hs"
    [ vars ["x", "y", "z"] (undefined :: Nat)
    , vars ["xs", "ys", "zs"] (undefined :: [Nat])
    , vars ["p", "q"] (undefined :: Nat -> Bool)
    -- Constructors
    , "Z" `fun0` Z
    , "S" `fun1` S
    , "[]" `fun0` ([] :: [Nat])
    , ":"  `fun2` ((:) :: Nat -> [Nat] -> [Nat])
    -- Functions
    , "filter" `fun2` ((filter) :: (Nat -> Bool) -> [Nat] -> [Nat])
    , "<=" `fun2` (<=)
    , "len" `fun1` ((len) :: [Nat] -> Nat)
    -- Observers
    , observer2 (flip ($) :: Nat -> (Nat -> Bool) -> Bool)
    ]

to_show = (prop_66)
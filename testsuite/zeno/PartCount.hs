{-# LANGUAGE TemplateHaskell #-}
module Main where

import Prelude(undefined,Bool(..), IO)

import HipSpec.Prelude
import HipSpec
import Definitions
import Properties

main :: IO ()
main = hipSpec $(fileName)
    [ vars ["x", "y", "z"] (undefined :: Nat)
    , vars ["xs", "ys", "zs"] (undefined :: [Nat])
    -- Constructors
    , "[]"     `fun0` ([]  :: [Nat])
    , ":"      `fun2` ((:) :: Nat -> [Nat] -> [Nat])
    , "Z"      `fun0` Z
    , "S"      `fun1` S
    -- Functions
    , "count"  `fun2`  count
    , "=="     `fun2`  (==) -- count calls (==)
    ]

-- The properties needs to be mentioned here to be included
to_show = (prop_04, prop_05)

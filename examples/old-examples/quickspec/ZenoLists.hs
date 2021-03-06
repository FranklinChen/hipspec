{-# LANGUAGE TypeFamilies, DeriveDataTypeable #-}

-- Lists and functions, many properties come from QuickSpec
module Main where

import Prelude (Eq,Ord,Show,iterate,(!!),fmap,Bool(..),undefined,Int,return)
-- import AutoPrelude
import Hip.HipSpec
import Data.Typeable
import Test.QuickCheck hiding (Prop)

type Prop a = a

proveBool = proveBool

otherwise = True

data Nat = Z | S Nat deriving (Eq,Ord,Show,Typeable)

instance Arbitrary Nat where
  arbitrary =
    let nats = iterate S Z
    in  (nats !!) `fmap` choose (0,25)

instance CoArbitrary Nat where
  coarbitrary Z = variant 0
  coarbitrary (S x) = variant 1 >< coarbitrary x

Z     == Z     = True
Z     == _     = False
(S _) == Z     = False
(S x) == (S y) = x == y

Z     <= _     = True
_     <= Z     = False
(S x) <= (S y) = x <= y

_     < Z     = False
Z     < _     = True
(S x) < (S y) = x < y

Z     + y = y
(S x) + y = S (x + y)

Z     - _     = Z
x     - Z     = x
(S x) - (S y) = x - y

True  && a = a
False && _ = False

not True  = False
not False = True

null :: [a] -> Bool
null [] = True
null _  = False

(++) :: [a] -> [a] -> [a]
[] ++ ys = ys
(x:xs) ++ ys = x : (xs ++ ys)

rev :: [a] -> [a]
rev [] = []
rev (x:xs) = rev xs ++ [x]

zip :: [a] -> [b] -> [(a, b)]
zip [] _ = []
zip _ [] = []
zip (x:xs) (y:ys) = (x, y) : (zip xs ys)

delete :: Nat -> [Nat] -> [Nat]
delete _ [] = []
delete n (x:xs) =
  case n == x of
    True -> delete n xs
    False -> x : (delete n xs)

len :: [a] -> Nat
len [] = Z
len (_:xs) = S (len xs)

elem :: Nat -> [Nat] -> Bool
elem _ [] = False
elem n (x:xs) =
  case n == x of
    True -> True
    False -> elem n xs

drop :: Nat -> [a] -> [a]
drop Z xs = xs
drop _ [] = []
drop (S x) (_:xs) = drop x xs

take :: Nat -> [a] -> [a]
take Z _ = []
take _ [] = []
take (S x) (y:ys) = y : (take x ys)

(.) :: (b -> c) -> (a -> b) -> a -> c
(f . g) x = f (g x)

count :: Nat -> [Nat] -> Nat
count x [] = Z
count x (y:ys) =
  case x == y of
    True -> S (count x ys)
    False -> count x ys

map :: (a -> b) -> [a] -> [b]
map f [] = []
map f (x:xs) = (f x) : (map f xs)

takeWhile :: (a -> Bool) -> [a] -> [a]
takeWhile _ [] = []
takeWhile p (x:xs) =
  case p x of
    True -> x : (takeWhile p xs)
    False -> []

dropWhile :: (a -> Bool) -> [a] -> [a]
dropWhile _ [] = []
dropWhile p (x:xs) =
  case p x of
    True -> dropWhile p xs
    False -> x:xs

filter :: (a -> Bool) -> [a] -> [a]
filter _ [] = []
filter p (x:xs) =
  case p x of
    True -> x : (filter p xs)
    False -> filter p xs

butlast :: [a] -> [a]
butlast [] = []
butlast [x] = []
butlast (x:xs) = x:(butlast xs)

last :: [Nat] -> Nat
last [] = Z
last [x] = x
last (x:xs) = last xs

sorted :: [Nat] -> Bool
sorted [] = True
sorted [x] = True
sorted (x:y:ys) = (x <= y) && sorted (y:ys)

insort :: Nat -> [Nat] -> [Nat]
insort n [] = [n]
insort n (x:xs) =
  case n <= x of
    True -> n : x : xs
    False -> x : (insort n xs)

ins :: Nat -> [Nat] -> [Nat]
ins n [] = [n]
ins n (x:xs) =
  case n < x of
    True -> n : x : xs
    False -> x : (ins n xs)

ins1 :: Nat -> [Nat] -> [Nat]
ins1 n [] = [n]
ins1 n (x:xs) =
  case n == x of
    True -> x : xs
    False -> x : (ins1 n xs)

sort :: [Nat] -> [Nat]
sort [] = []
sort (x:xs) = insort x (sort xs)

butlastConcat :: [a] -> [a] -> [a]
butlastConcat xs [] = butlast xs
butlastConcat xs ys = xs ++ butlast ys

lastOfTwo :: [Nat] -> [Nat] -> Nat
lastOfTwo xs [] = last xs
lastOfTwo _ ys = last ys

zipConcat :: a -> [a] -> [b] -> [(a, b)]
zipConcat _ _ [] = []
zipConcat x xs (y:ys) = (x, y) : zip xs ys

enumFromTo :: Nat -> Nat -> [Nat]
enumFromTo x y | y < x     = []
               | otherwise = x : enumFromTo (S x) y

prop_00 :: (a -> b) -> [a] -> Nat -> Prop [b]
prop_00 f xs n = take n (map f xs) =:= map f (take n xs)

prop_01 :: Nat -> [a] -> Prop [a]
prop_01 n xs
  = take n xs ++ drop n xs =:= xs

prop_02 :: Nat -> [Nat] -> [Nat] -> Prop Nat
prop_02 n xs ys
  = count n xs + count n ys =:= count n (xs ++ ys)

prop_03 :: Nat -> [Nat] -> [Nat] -> Prop Bool
prop_03 n xs ys
  = proveBool (count n xs <= count n (xs ++ ys))

prop_04 :: Nat -> [Nat] -> Prop Nat
prop_04 n xs
  = S (count n xs) =:= count n (n : xs)

prop_11 :: [a] -> Prop [a]
prop_11 xs
  = drop Z xs =:= xs

prop_12 :: Nat -> (a -> b) -> [a] -> Prop [b]
prop_12 n f xs
  = drop n (map f xs) =:= map f (drop n xs)

prop_13 :: Nat -> a -> [a] -> Prop [a]
prop_13 n x xs
  = drop (S n) (x : xs) =:= drop n xs

prop_14 :: (a -> Bool) -> [a] -> [a] -> Prop [a]
prop_14 p xs ys
  = filter p (xs ++ ys) =:= (filter p xs) ++ (filter p ys)

prop_15 :: Nat -> [Nat] -> Prop Nat
prop_15 x xs
  = len (ins x xs) =:= S (len xs)

prop_19 :: Nat -> [Nat] -> Prop Nat
prop_19 n xs
  = len (drop n xs) =:= len xs - n

--prop_20 :: [Nat] -> Prop Nat
--prop_20 xs
--  = len (sort xs) =:= len xs

{-
prop_26 x xs ys
  = givenBool (x `elem` xs)
  $ proveBool (x `elem` (xs ++ ys))

prop_27 x xs ys
  = givenBool (x `elem` ys)
  $ proveBool (x `elem` (xs ++ ys))
-}

prop_28 :: Nat -> [Nat] -> Prop Bool
prop_28 x xs
  = proveBool (x `elem` (xs ++ [x]))

prop_29 :: Nat -> [Nat] -> Prop Bool
prop_29 x xs
  = proveBool (x `elem` ins1 x xs)

prop_30 :: Nat -> [Nat] -> Prop Bool
prop_30 x xs
  = proveBool (x `elem` ins x xs)

prop_35 :: [a] -> Prop [a]
prop_35 xs
  = dropWhile (\_ -> False) xs =:= xs

prop_36 :: [a] -> Prop [a]
prop_36 xs
  = takeWhile (\_ -> True) xs =:= xs

prop_37 :: Nat -> [Nat] -> Prop Bool
prop_37 x xs
  = proveBool (not (x `elem` delete x xs))

prop_38 :: Nat -> [Nat] -> Prop Nat
prop_38 n xs
  = count n (xs ++ [n]) =:= S (count n xs)

prop_39 :: Nat -> Nat -> [Nat] -> Prop Nat
prop_39 n x xs
  = count n [x] + count n xs =:= count n (x:xs)

prop_40 :: [a] -> Prop [a]
prop_40 xs
  = take Z xs =:= []

prop_41 :: Nat -> (a -> b) -> [a] -> Prop [b]
prop_41 n f xs
  = take n (map f xs) =:= map f (take n xs)

prop_42 :: Nat -> a -> [a] -> Prop [a]
prop_42 n x xs
  = take (S n) (x:xs) =:= x : (take n xs)

prop_43 :: (a -> Bool) -> [a] -> Prop [a]
prop_43 p xs
  = takeWhile p xs ++ dropWhile p xs =:= xs

prop_44 :: a -> [a] -> [b] -> Prop [(a,b)]
prop_44 x xs ys
  = zip (x:xs) ys =:= zipConcat x xs ys

prop_45 :: a -> b -> [a] -> [b] -> Prop [(a,b)]
prop_45 x y xs ys
  = zip (x:xs) (y:ys) =:= (x, y) : zip xs ys

prop_46 :: [a] -> Prop [(b,a)]
prop_46 xs
  = zip [] xs =:= []

{-
prop_48 xs
  = given (xs == [] =:= False)
  $ butlast xs ++ [last xs] =:= xs
-}

prop_49 :: [a] -> [a] -> Prop [a]
prop_49 xs ys
  = butlast (xs ++ ys) =:= butlastConcat xs ys

prop_50 :: [a] -> Prop [a]
prop_50 xs
  = butlast xs =:= take (len xs - S Z) xs

prop_51 :: [a] -> a -> Prop [a]
prop_51 xs x
  = butlast (xs ++ [x]) =:= xs

prop_52 :: Nat -> [Nat] -> Prop Nat
prop_52 n xs
  = count n xs =:= count n (rev xs)

--prop_53 :: Nat -> [Nat] -> Prop Nat
--prop_53 n xs
--  = count n xs =:= count n (sort xs)

prop_55 :: Nat -> [a] -> [a] -> Prop [a]
prop_55 n xs ys
  = drop n (xs ++ ys) =:= drop n xs ++ drop (n - len xs) ys

prop_56 :: Nat -> Nat -> [a] -> Prop [a]
prop_56 n m xs
  = drop n (drop m xs) =:= drop (n + m) xs

prop_57 :: Nat -> Nat -> [a] -> Prop [a]
prop_57 n m xs
  = drop n (take m xs) =:= take (m - n) (drop n xs)

prop_58 :: Nat -> [a] -> [b] -> Prop [(a,b)]
prop_58 n xs ys
  = drop n (zip xs ys) =:= zip (drop n xs) (drop n ys)

{-
prop_59 xs ys
  = givenBool (ys == [])
  $ last (xs ++ ys) =:= last xs

prop_60 xs ys
  = given (ys == [] =:= False)
  $ last (xs ++ ys) =:= last ys
-}

prop_61 :: [Nat] -> [Nat] -> Prop Nat
prop_61 xs ys
  = last (xs ++ ys) =:= lastOfTwo xs ys

{-
prop_62 xs x
  = given (xs == [] =:= False)
  $ last (x:xs) =:= last xs
-}

{-
prop_63 (n :: Nat) xs
  = givenBool (n < len xs)
  $ last (drop n xs) =:= last xs
-}

prop_64 :: Nat -> [Nat] -> Prop Nat
prop_64 x xs
  = last (xs ++ [x]) =:= x

prop_66 :: (a -> Bool) -> [a] -> Prop Bool
prop_66 p xs
  = proveBool (len (filter p xs) <= len xs)


prop_67 :: [a] -> Prop Nat
prop_67 xs
  = len (butlast xs) =:= len xs - S Z

prop_68 :: Nat -> [Nat] -> Prop Bool
prop_68 n xs
  = proveBool (len (delete n xs) <= len xs)

{-
prop_71 x y xs
  = given (x == y =:= False)
  $ elem x (ins y xs) =:= elem x xs
-}

prop_72 :: Nat -> [a] -> Prop [a]
prop_72 i xs
  = rev (drop i xs) =:= take (len xs - i) (rev xs)

prop_73 :: (a -> Bool) -> [a] -> Prop [a]
prop_73 p xs
  = rev (filter p xs) =:= filter p (rev xs)

prop_74 :: Nat -> [a] -> Prop [a]
prop_74 i xs
  = rev (take i xs) =:= drop (len xs - i) (rev xs)

prop_75 :: Nat -> Nat -> [Nat] -> Prop Nat
prop_75 n m xs
  = count n xs + count n [m] =:= count n (m : xs)

{-
prop_76 n m xs
  = given (n == m =:= False)
  $ count n (xs ++ [m]) =:= count n xs

prop_77 x xs
  = givenBool (sorted xs)
  $ proveBool (sorted (insort x xs))
-}

--prop_78 :: [Nat] -> Prop Bool
--prop_78 xs
--  = proveBool (sorted (sort xs))

prop_80 :: Nat -> [a] -> [a] -> Prop [a]
prop_80 n xs ys
  = take n (xs ++ ys) =:= take n xs ++ take (n - len xs) ys

prop_81 :: Nat -> Nat -> [a] -> Prop [a]
prop_81 n m xs
  = take n (drop m xs) =:= drop m (take (n + m) xs)

prop_82 :: Nat -> [a] -> [b] -> Prop [(a,b)]
prop_82 n xs ys
  = take n (zip xs ys) =:= zip (take n xs) (take n ys)

prop_83 :: [a] -> [a] -> [b] -> Prop [(a,b)]
prop_83 xs ys zs
  = zip (xs ++ ys) zs =:=
           zip xs (take (len xs) zs) ++ zip ys (drop (len xs) zs)

prop_84 :: [a] -> [b] -> [b] -> Prop [(a,b)]
prop_84 xs ys zs
  = zip xs (ys ++ zs) =:=
           zip (take (len ys) xs) ys ++ zip (drop (len ys) xs) zs

-- This was originally stated
-- zip (rev xs) (rev ys) =:= rev (zip xs ys)
-- but that it obviously not true =/
prop_85 :: [a] -> Prop [(a,a)]
prop_85 xs
  = zip (rev xs) (rev xs) =:= rev (zip xs xs)

prop_map_compose :: (b -> c) -> (a -> b) -> [a] -> Prop [c]
prop_map_compose f g xs = map (f . g) xs =:= map f (map g xs)

prop_filter_double_pred :: (a -> Bool) -> (a -> Bool) -> [a] -> Prop [a]
prop_filter_double_pred p q xs = filter p (filter q xs) =:=
                                        filter (\x -> p x && q x) xs

prop_len_plus_list_homomorphism :: [a] -> [a] -> Prop Nat
prop_len_plus_list_homomorphism xs ys =
  len (xs ++ ys) =:= len xs + len ys

main = hipSpec "ZenoLists.hs" conf 3
  where conf = describe "Lists"
                [ var "x"  natType
                , var "y"  natType
                , var "z"  natType
                -- , var "a"  boolType
                -- , var "b"  boolType
                -- , var "c"  boolType
                , var "xs" listNatType
                , var "ys" listNatType
                , var "zs" listNatType
                -- , con "==" (==)
                -- , con "<=" (<=)
                -- , con "<" (<)
                , con "+" (+)
                -- , con "-" (-)
                , con "[]" ([] :: [Nat])
                -- , con "[]" ([] :: [(Nat, Nat)])
                , con ":" (nat (:))
                -- , con ":" (pair (:))
                -- , con "&&" (&&)
                -- , con "not" not
                , con "null" (nat null)
                , con "++" (nat (++))
                -- , con "++" (pair (++))
                , con "rev" (nat rev)
                -- , con "rev" (pair rev)
                , con "delete" (nat . delete)
                , con "len" (nat len)
                -- , con "len" (pair len)
                , con "elem" (nat . elem)
                , con "drop" (nat . drop)
                -- , con "drop" (pair . drop)
                , con "take" (nat . take)
                -- , con "take" (pair . take)
                -- , con "count" (nat . count)
                -- , con "map" (map :: (Nat -> Nat) -> [Nat] -> [Nat])
                -- , con "takeWhile" (nat . takeWhile)
                -- , con "dropWhile" (nat . dropWhile)
                -- , con "filter" (nat . filter)
                , con "butlast" (nat butlast)
                , con "last" (nat last)
                , con "sorted" (nat sorted)
                , con "insort" (nat . insort)
                , con "ins" (nat . ins)
                , con "ins1" (nat . ins1)
                , con "sort" (nat sort)
                -- , con "butlastConcat" (nat butlastConcat)
                -- , con "lastOfTwo" (nat lastOfTwo)
                -- , con "zipConcat" (zipConcat :: Nat -> [Nat] -> [Nat] -> [(Nat, Nat)])
                -- , con "enumFromTo" (enumFromTo :: Nat -> Nat -> [Nat])
                , con "Z" Z
                , con "S" S
                -- , con "True" True
                -- , con "False" False
                ]
                   where
                     natType      = undefined :: Nat
                     boolType     = undefined :: Bool
                     listNatType  = undefined :: [Nat]
                     nat :: ([Nat] -> a) -> [Nat] -> a
                     nat x        = x
                     -- pair :: ([(Nat, Nat)] -> a) -> [(Nat, Nat)] -> a
                     -- pair x       = x

instance Classify Nat where
  type Value Nat = Nat
  evaluate = return

-- The tiny Hip Prelude
(=:=) = (=:=)
{-# LANGUAGE RecordWildCards, NamedFieldPuns #-}
module Language.Plover.Simplify
  (simplify, Expr(..))
where
import qualified Data.Map.Strict as M
import Control.Monad (foldM)

-- TODO add rebuild to atom
data Expr e num
  = Sum [(Expr e num)]
  | Mul [(Expr e num)]
  | Atom e
  | Prim num
  | Zero
  | One
 deriving (Show, Eq, Ord)

data Term e n
  = Term n (M.Map e Int)
  | Z
  deriving (Show, Eq)
term1 :: Num n => Term atom n
term1 = Term 1 M.empty

-- Main simplification function
reduce :: (Ord e, Num num) => Term e num -> Expr e num
       -> [Term e num]
reduce Z _ = return Z
reduce term x = step x
 where
  -- Distribute
  step (Sum as) = concatMap (reduce term) as
  -- Sequence
  step (Mul as) = foldM reduce term as
  -- Increment
  step (Atom e) =
    let Term coefficient m = term in
    return $ Term coefficient (M.insertWith (+) e 1 m)
  -- Numeric simplify
  step (Prim n) =
    let Term coefficient m = term in
    return $ Term (n * coefficient) m
  step Zero = return $ Z
  step One = return $ term

rebuildTerm :: Num expr => [(expr, Int)] -> expr
rebuildTerm [] = 1
rebuildTerm (e : es) = foldl (\acc pair -> acc * fix pair) (fix e) es
 where
  fix = uncurry (^)

sum' :: (Num a) => [a] -> a
sum' [] = 0
sum' xs = foldr1 (+) xs

rebuild :: (Num expr, Num num) => (num -> expr -> expr) -> Polynomial expr num -> expr
rebuild scale poly = sum' $ map (\(term, coef) -> scale coef (rebuildTerm term)) (M.toList poly)

type Polynomial expr num = M.Map [(expr, Int)] num
poly0 :: Polynomial expr num
poly0 = M.empty

addTerm :: (Ord expr, Num num)
        => Term expr num -> Polynomial expr num -> Polynomial expr num
addTerm Z p = p
addTerm (Term coefficient m) p =
  M.insertWith (+) (M.toList m) coefficient p

(.>) :: (a -> b) -> (b -> c) -> a -> c
(.>) = flip (.)

simplify :: (Ord expr, Num expr, Num num)
         => (num -> expr -> expr) -> Expr expr num -> expr
         -- => (expr -> Expr expr num) -> (num -> expr -> expr) -> expr -> expr
simplify scale = reduce term1 .> foldr addTerm poly0 .> rebuild scale


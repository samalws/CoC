module CoC.DeBruijn where

import Data.Maybe

type Var = Int
data Term = Star | Pi Term Term | Lm Term Term | Called Term Term | VarTerm Var deriving (Eq, Read, Show)
type Env = [Term]

safeIndex :: Int -> [a] -> Maybe a
safeIndex _ [] = Nothing
safeIndex 0 (h:r) = Just h
safeIndex n (h:r) = safeIndex (n-1) r

assert :: Bool -> Maybe ()
assert True = Just ()
assert False = Nothing

-- DOES NOT check validity or simplify
incTerm :: Term -> Term
incTerm = incTerm' 0

incTerm' :: Int -> Term -> Term
incTerm' _ Star = Star
incTerm' thr (Pi a b) = Pi (incTerm' thr a) (incTerm' (thr+1) b)
incTerm' thr (Lm a b) = Lm (incTerm' thr a) (incTerm' (thr+1) b)
incTerm' thr (Called a b) = Called (incTerm' thr a) (incTerm' thr b)
incTerm' thr (VarTerm n)
  | n >= thr = VarTerm (n+1)
  | otherwise = VarTerm n

validTerm :: Env -> Term -> Bool
validTerm _ Star = True
validTerm e a = isJust $ typeOf e a

-- checks validity and simplifies
appendEnv :: Env -> Term -> Maybe Env
appendEnv e a = do
  sa <- simpl e a
  return $ map incTerm (a:e)

hasType :: Env -> Term -> Term -> Bool
hasType e a b = m == Just True where
  m = do
    ta <- typeOf e a
    sb <- simpl e b
    return $ ta == sb

-- DOES NOT check validity or simplify
replace :: Var -> Term -> Term -> Term
replace _ _ Star = Star
replace n x (Pi a b) = Pi (replace n x a) (replace (n+1) (incTerm x) b)
replace n x (Lm a b) = Lm (replace n x a) (replace (n+1) (incTerm x) b)
replace n x (Called a b) = Called (replace n x a) (replace n x b)
replace n x (VarTerm m)
  | n == m = x
  | n < m = VarTerm (m-1)
  | otherwise = VarTerm m

-- checks validity and simplifies
call :: Env -> Term -> Term -> Maybe Term
call e (Lm a b) c = do
  sa <- simpl e a
  tc <- typeOf e c
  assert $ sa == tc
  simpl e $ replace 0 c b
call e (Called a b) d = do
  c <- call e a b
  if c /= (Called a b) then call e c d else return $ Called c d
call e a@(VarTerm _) b = do
  sb <- simpl e b
  c <- return $ Called a sb
  assert $ validTerm e c
  return c
called _ _ _ = Nothing

-- checks validity and simplifies
simpl :: Env -> Term -> Maybe Term
simpl _ Star = Just Star
simpl e (Pi a b) = do
  sa <- simpl e a
  ae <- appendEnv e sa
  sb <- simpl ae b
  return $ Pi sa sb
simpl e (Lm a b) = do
  sa <- simpl e a
  ae <- appendEnv e sa
  sb <- simpl ae b
  return $ Lm sa sb
simpl e (Called a b) = call e a b
simpl e (VarTerm a) = do
  safeIndex a e
  return $ VarTerm a

-- checks validity and simplifies
typeOf :: Env -> Term -> Maybe Term
typeOf _ Star = Nothing
typeOf e (Pi a b) = do
  ae <- appendEnv e a
  assert $ validTerm ae b
  return Star
typeOf e (Lm a b) = do
  sa <- simpl e a
  ae <- appendEnv e sa
  tb <- typeOf ae b
  return (Pi sa tb)
typeOf e (Called a b) = case (simpl e a) of
  Just sa@(Lm _ _) -> call e sa b >>= typeOf e
  Just sa -> do
    ta <- typeOf e sa
    case ta of
      (Pi c d) -> do
        sb <- simpl e b
        tb <- typeOf e sb
        assert $ tb == c
        simpl e $ replace 0 sb d
      _ -> Nothing
  _ -> Nothing
typeOf e (VarTerm n) = safeIndex n e

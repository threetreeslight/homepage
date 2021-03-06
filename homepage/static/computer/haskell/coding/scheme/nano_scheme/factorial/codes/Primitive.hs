{-# LANGUAGE TupleSections #-}

module Primitive (env0) where

import Control.Applicative ((<$>), (<*>))
import Data.List (foldl')

import Eval (eval)
import Environment (
	Env, fromList, set,
	Value(..), showValue, Error(..), ErrorMessage)

syntaxErr, prpLstErr, notNumErr, lstOneErr :: ErrorMessage
syntaxErr = "*** ERROR: Compile Error: syntax-error: "
prpLstErr = "*** ERROR: Compile Error: proper list required: "
notNumErr = "*** ERROR: Not Number: "
lstOneErr = "*** ERROR: Compile Error: procedure requires at least one argument"

env0 :: Env
env0 = fromList [
	("exit", DoExit),
	("define", Syntax "define" define),
	("lambda", Syntax "lambda" lambda),
	("if", Syntax "if" ifs),
	("list", Subroutine "list" $ (Right .) . (,)),
	("+", Subroutine "+" add),
	("*", Subroutine "*" mul),
	("-", Subroutine "-" sub),
	("<", Subroutine "<" ltt)
	]

define, lambda, ifs :: Value -> Env -> Either Error (Value, Env)
define (Cons sm@(Symbol s) (Cons v Nil)) e = do
	(v', e') <- eval v e
	Right (sm, set s v' e')
define (Cons (Cons f@(Symbol n) as) bd) e = Right (f, set n (Lambda n as bd) e)
define v _ = Left . Error $ syntaxErr ++ showValue (Symbol "define" `Cons` v)

lambda (Cons as bd) e = Right (Lambda "#f" as bd, e)
lambda v _ = Left . Error $ syntaxErr ++ showValue (Symbol "lambda" `Cons` v)

ifs (Cons p (Cons th (Cons el Nil))) e = eval p e >>= \(b, e') ->
	case b of Bool False -> eval el e'; _ -> eval th e'
ifs v _ = Left . Error $ syntaxErr ++ showValue (Symbol "if" `Cons` v)

consToList :: Value -> Either Error [Value]
consToList Nil = Right []
consToList (v `Cons` vs) = (v :) <$> consToList vs
consToList v = Left . Error $ prpLstErr ++ showValue v

toInt :: Value -> Either Error Integer
toInt (Integer i) = Right i
toInt v = Left . Error $ notNumErr ++ showValue v

add, mul, sub :: Value -> Env -> Either Error (Value, Env)
add v e = (, e) . Integer . sum <$> (mapM toInt =<< consToList v)
mul v e = (, e) . Integer . product <$> (mapM toInt =<< consToList v)
sub v e = (, e) . Integer . sb <$> (chk =<< mapM toInt =<< consToList v)
	where
	chk [] = Left $ Error lstOneErr
	chk vs = Right vs
	sb [x] = negate x
	sb (x : xs) = foldl' (-) x xs
	sb _ = error "never occur"

ltt :: Value -> Env -> Either Error (Value, Env)
ltt v e = (, e) . Bool . and . (zipWith (<) <$> id <*> tail)
	<$> (mapM toInt =<< consToList v)

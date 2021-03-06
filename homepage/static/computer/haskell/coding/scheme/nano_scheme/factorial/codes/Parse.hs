module Parse (Token, tokens, parse) where

import Control.Applicative ((<$>))
import Data.Char (isDigit, isAlpha, isSpace)

import Environment(Value(..), Symbol, Error(..), ErrorMessage)

data Token
	= TkSymbol Symbol
	| TkTrue | TkFalse
	| TkInteger Integer
	| OParen | CParen
	deriving Show

syntaxErr, tokenErr, parseErr :: ErrorMessage
syntaxErr = "*** SYNTAX-ERROR: "
tokenErr = "Can't tokenize: "
parseErr = "Parse error: "

tokens :: String -> Either Error [Token]
tokens ('(' : s) = (OParen :) <$> tokens s
tokens (')' : s) = (CParen :) <$> tokens s
tokens ('#' : 'f' : s) = (TkFalse :) <$> tokens s
tokens ('#' : 't' : s) = (TkTrue :) <$> tokens s
tokens str@(c : s)
	| isSymbolChar c = do
		let (sm, s') = span isSymbolChar s
		ts <- tokens s'
		return $ TkSymbol (c : sm) : ts
	| isDigit c = do
		let (ds, s') = span isDigit s
		ts <- tokens s'
		return $ TkInteger (read $ c : ds) : ts
	| isSpace c = tokens s
	| otherwise = Left . Error $ syntaxErr ++ tokenErr ++ show str
tokens _ = return []

isSymbolChar :: Char -> Bool
isSymbolChar c = any ($ c) [isAlpha, (`elem` "+-*/<=>")]

parse :: [Token] -> Either Error [Value]
parse [] = return []
parse ts = do
	(v, ts') <- parse1 ts
	(v :) <$> parse ts'

parse1, parseList :: [Token] -> Either Error (Value, [Token])
parse1 (TkSymbol s : ts) = return (Symbol s, ts)
parse1 (TkFalse : ts) = return (Bool False, ts)
parse1 (TkTrue : ts) = return (Bool True, ts)
parse1 (TkInteger i : ts) = return (Integer i, ts)
parse1 (OParen : ts) = parseList ts
parse1 ts = Left . Error $ syntaxErr ++ parseErr ++ show ts

parseList (CParen : ts) = return (Nil, ts)
parseList ts = do
	(v, ts') <- parse1 ts
	(vs, ts'') <- parseList ts'
	return $ (v `Cons` vs, ts'')

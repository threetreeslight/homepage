module NmlParse (nml) where

import Data.List (unfoldr)
import Data.Tree (Tree(..))
import Data.Char (isSpace)

type Nml = Tree String

nml :: String -> Maybe Nml
nml s = case parse $ tokens s of (Just n, []) -> Just n; _ -> Nothing

parse :: [Token] -> (Maybe Nml, [Token])
parse (Text tx : ts) = (Just $ Node tx [], ts)
parse (Open tg : s) = case parses s of
	(ns, Close tg' : r) | tg == tg' -> (Just $ Node tg ns, r)
	(ns, r) -> (Just $ Node tg ns, r)
parse ts = (Nothing, ts)

parses :: [Token] -> ([Nml], [Token])
parses ts = case parse ts of
	(Just n, r) -> let (ns, r') = parses r in (n : ns, r')
	(_, r) -> ([], r)

data Token = Open String | Close String | Text String deriving Show

value :: Token -> String
value (Open tg) = tg
value (Close tg) = tg
value (Text tx) = tx

apply :: (String -> String) -> Token -> Token
apply f (Open tg) = Open $ f tg
apply f (Close tg) = Close $ f tg
apply f (Text tx) = Text $ f tx

tokens :: String -> [Token]
tokens = concatMap emptyTag . filter (not . null . value)
	. map (apply $ entity . spaces) . unfoldr token

emptyTag :: Token -> [Token]
emptyTag (Open tg) | last tg == '/' = map ($ init tg) [Open, Close]
emptyTag tg = [tg]

entity :: String -> String
entity ('&' : 'l' : 't' : ';' : s) = '<' : entity s
entity ('&' : 'g' : 't' : ';' : s) = '>' : entity s
entity ('&' : 'a' : 'm' : 'p' : ';' : s) = '&' : entity s
entity (c : s) = c : entity s
entity _ = ""

spaces :: String -> String
spaces = takeWhileR (not . isSpace) . dropWhile isSpace

takeWhileR :: (a -> Bool) -> [a] -> [a]
takeWhileR = twr [] where
	twr s p (x : xs)
		| p x = reverse s ++ [x] ++ twr [] p xs
		| otherwise = twr (x : s) p xs
	twr _ _ _ = []

token :: String -> Maybe (Token, String)
token "" = Nothing
token ('<' : s) = Just $ tag s
token s = Just $ let (tx, r) = span (/= '<') s in (Text tx, r)

tag :: String -> (Token, String)
tag ('/' : s) = case span (/= '>') s of
	(tg, _ : r) -> (Close tg, r)
	(tg, _) -> (Close tg, "")
tag s = case span (/= '>') s of
	(tg, _ : r) -> (Open tg, r)
	(tg, _) -> (Open tg, "")
module Parser where

import Control.Exception(assert)
import Control.Applicative ((<|>))
import Data.Maybe (fromJust)

-- "alice & bob | carol"
-- "x & ((¬y) | z)"

data Unary = Not deriving (Eq, Show)
data Binary = And | Or | Xor | Implies | Equivalent deriving (Eq, Show)
data Op = UnaryOp Unary | BinaryOp Binary deriving (Eq, Show)
data Token = OpToken Op | NameToken String | LeftParen | RightParen deriving (Eq, Show)
data SyntaxNode = UnaryNode Unary SyntaxNode | BinaryNode SyntaxNode Binary SyntaxNode | NameNode String deriving (Show)
data ParseElement = ParensElement [ParseElement] | UnaryOpElement Unary | BinaryOpElement Binary | NameElement String deriving (Show)

validNameChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
notChars = "!¬~"
andChars = "&*."
orChars = "|+"
xorChars = "^"
impliesChars = "⇒→"
equivalentChars = "≡⇔=⟷"
validChars = validNameChars ++ notChars ++ andChars ++ orChars ++ xorChars ++ impliesChars ++ equivalentChars ++ "() "
presetVals = [("true", True), ("false", False), ("1", True), ("0", False)]

eatWhitespace :: String -> String
eatWhitespace (' ':cs) = eatWhitespace cs
eatWhitespace x = x

eatParen :: String -> Maybe (Token, String)
eatParen ('(':cs) = Just (LeftParen, cs)
eatParen (')':cs) = Just (RightParen, cs)
eatParen x = Nothing

eatName :: String -> String -> Maybe (Token, String)
eatName [] [] = Nothing
eatName left [] = Just (NameToken left, "")
eatName left (c : right)
  | c `elem` validNameChars = eatName (left ++ [c]) right
  | left == "" = Nothing
  | otherwise = Just (NameToken left, c : right)

eatOp :: String -> Maybe (Token, String)
eatOp (c : cs)
  | c `elem` notChars = Just (OpToken $ UnaryOp Not, cs)
  | c `elem` andChars = Just (OpToken $ BinaryOp And, cs)
  | c `elem` orChars = Just (OpToken $ BinaryOp Or, cs)
  | c `elem` xorChars = Just (OpToken $ BinaryOp Xor, cs)
  | c `elem` impliesChars = Just (OpToken $ BinaryOp Implies, cs)
  | c `elem` equivalentChars = Just (OpToken $ BinaryOp Equivalent, cs)
eatOp x = Nothing

tokenise :: String -> [Token]
tokenise "" = []
tokenise x = let (token, cs) = fromJust $ eatParen x <|> eatName "" x <|> eatOp x in token : tokenise (eatWhitespace cs)

checkParens :: Integer -> [Token] -> Bool
checkParens x _ | x < 0 = False
checkParens level (LeftParen : ts) = checkParens (level + 1) ts
checkParens level (RightParen : ts) = checkParens (level - 1) ts
checkParens level (x : ts) = checkParens level ts
checkParens 0 [] = True
checkParens _ [] = False

wrangleParens :: [Token] -> ([ParseElement], [Token])
wrangleParens (LeftParen : ts) =
    let (inner, right) = wrangleParens ts in
        let (rightElements, rightRemaining) = wrangleParens right in
            (ParensElement inner : rightElements, rightRemaining)
wrangleParens (RightParen : ts) = ([], ts)
wrangleParens (OpToken (UnaryOp op) : ts) =
    let (elems, remaining) = wrangleParens ts in
        (UnaryOpElement op : elems, remaining)
wrangleParens (OpToken (BinaryOp op) : ts) =
    let (elems, remaining) = wrangleParens ts in
        (BinaryOpElement op : elems, remaining)
wrangleParens (NameToken name : ts) =
    let (elems, remaining) = wrangleParens ts in
        (NameElement name : elems, remaining)
wrangleParens [] = ([], [])

searchOps :: [ParseElement] -> [ParseElement] -> Binary -> Maybe ([ParseElement], Binary, [ParseElement])
searchOps left (BinaryOpElement op : es) needle | needle == op = Just (left, op, es)
searchOps left (e:right) needle = searchOps (left ++ [e]) right needle
searchOps left [] _ = Nothing

wrangleOps :: [ParseElement] -> SyntaxNode
wrangleOps [ParensElement inner] = wrangleOps inner
wrangleOps [NameElement name] = NameNode name
wrangleOps (BinaryOpElement _ : _) = undefined
wrangleOps list =
    let search = searchOps [] list in
        let result = search Equivalent <|> search Implies <|> search Xor <|> search Or <|> search And in
            case result of
                Just (left, op, right) -> BinaryNode (wrangleOps left) op (wrangleOps right)
                Nothing -> case list of
                    (UnaryOpElement Not : right) -> UnaryNode Not $ wrangleOps right
                    _ -> undefined

parse :: String -> SyntaxNode
parse s =
    let ts = tokenise s in
        wrangleOps $ fst $ wrangleParens $ assert (checkParens 0 ts) ts

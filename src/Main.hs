module Main where

import Eval
import Parser
import TruthTable
import System.Environment (getArgs)

main :: IO ()
main = do
    args <- getArgs
    putStr $ formattedMarkdownTable $ head args

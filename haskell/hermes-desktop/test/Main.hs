{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Monad (unless)
import Data.Aeson
import Hermes.Desktop.Protocol.PhoenixFrame
import Hermes.Desktop.Protocol.TableData
import System.Exit (exitFailure)

main :: IO ()
main = do
  frameRoundTrip
  legalMovePayload

frameRoundTrip :: IO ()
frameRoundTrip = do
  let frame = PhoenixFrame (Just "1") (Just "2") "games:test" "roll" (object []) :: PhoenixFrame Value
  assert (eitherDecode (encode frame) == Right frame) "Phoenix frames must round-trip."

legalMovePayload :: IO ()
legalMovePayload = do
  let channelPayload =
        object
          [ "game" .=
              object
                [ "match" .= object [],
                  "legal_moves" .= [object ["from" .= (11 :: Int), "to" .= (10 :: Int), "die" .= (1 :: Int), "sequence" .= [1 :: Int]]
                ]
          ]
  case gameFromChannelPayload channelPayload of
    Just snapshot ->
      case legalMoves snapshot of
        [move] -> assert (movePayload move == object ["move" .= object ["from" .= (11 :: Int), "to" .= (10 :: Int), "sequence" .= [1 :: Int]]) "Legal move payload must preserve raw coordinates and sequence."
        _ -> failTest "Expected one legal move."
    Nothing -> failTest "Expected a decodable channel snapshot."

assert :: Bool -> String -> IO ()
assert condition message = unless condition (failTest message)

failTest :: String -> IO ()
failTest message = putStrLn message >> exitFailure

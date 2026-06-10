{-# LANGUAGE OverloadedStrings #-}

module Hermes.Desktop.Protocol.PhoenixSocketUrl
  ( buildSocketUrl,
  )
where

import Data.List (intercalate)
import Network.URI

buildSocketUrl :: String -> String
buildSocketUrl baseUrl =
  case parseURI baseUrl of
    Nothing -> error ("Unsupported base URL: " <> baseUrl)
    Just uri ->
      let scheme = case uriScheme uri of
            "http:" -> "ws:"
            "https:" -> "wss:"
            "ws:" -> "ws:"
            "wss:" -> "wss:"
            other -> error ("Unsupported scheme in " <> other)
          authority = maybe (error "Missing authority in base URL.") id (uriAuthority uri)
          queryParts =
            filter (not . null) $
              map dropQuestionMark [uriQuery uri, "?vsn=2.0.0"]
          querySuffix =
            case queryParts of
              [] -> ""
              parts -> "?" <> intercalate "&" parts
       in scheme <> "//" <> uriRegName authority <> portPart authority <> "/socket/websocket" <> querySuffix

dropQuestionMark :: String -> String
dropQuestionMark ('?' : rest) = rest
dropQuestionMark other = other

portPart :: URIAuth -> String
portPart authority
  | null (uriPort authority) = ""
  | otherwise = uriPort authority

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Hermes.Desktop.Protocol.PhoenixClient
  ( PhoenixClient,
    PhoenixEvent (..),
    startPhoenixClient,
    pushPhoenix,
    closePhoenix,
    readPhoenixEvent,
    tryReadPhoenixEvent,
  )
where

import Control.Concurrent (Chan, ThreadId, forkIO, isEmptyChan, killThread, newChan, readChan, threadDelay, writeChan)
import Control.Exception (SomeException, catch, finally)
import Control.Monad (forever, void)
import Data.Aeson (Value, eitherDecode, encode, object, (.=))
import qualified Data.ByteString.Lazy as Lazy
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Hermes.Desktop.Protocol.PhoenixFrame
import Hermes.Desktop.Protocol.PhoenixSocketUrl (buildSocketUrl)
import Network.URI
import qualified Network.WebSockets as WebSocket
import qualified Wuss

data PhoenixClient = PhoenixClient
  { commandQueue :: Chan ClientCommand,
    eventQueue :: Chan PhoenixEvent,
    workerThread :: ThreadId
  }

data PhoenixEvent
  = PhoenixConnected
  | PhoenixFrameReceived (PhoenixFrame Value)
  | PhoenixDisconnected Text
  | PhoenixProtocolError Text
  deriving (Eq, Show)

data ClientCommand
  = Push Text Value
  | Close

data SocketTarget = SocketTarget
  { secureSocket :: Bool,
    socketHost :: String,
    socketPort :: Int,
    socketPath :: String
  }

startPhoenixClient :: String -> Text -> Value -> IO PhoenixClient
startPhoenixClient baseUrl topic joinPayload = do
  commands <- newChan
  events <- newChan
  worker <- forkIO (runClient baseUrl topic joinPayload commands events)
  pure (PhoenixClient commands events worker)

pushPhoenix :: PhoenixClient -> Text -> Value -> IO ()
pushPhoenix client event payload = writeChan (commandQueue client) (Push event payload)

closePhoenix :: PhoenixClient -> IO ()
closePhoenix client = do
  writeChan (commandQueue client) Close
  killThread (workerThread client)

readPhoenixEvent :: PhoenixClient -> IO PhoenixEvent
readPhoenixEvent = readChan . eventQueue

tryReadPhoenixEvent :: PhoenixClient -> IO (Maybe PhoenixEvent)
tryReadPhoenixEvent client = do
  empty <- isEmptyChan (eventQueue client)
  if empty then pure Nothing else Just <$> readChan (eventQueue client)

runClient :: String -> Text -> Value -> Chan ClientCommand -> Chan PhoenixEvent -> IO ()
runClient baseUrl topic joinPayload commands events =
  forever $ do
    let target = socketTarget baseUrl
    let application connection = connectionLoop connection topic joinPayload commands events
    let connect =
          if secureSocket target
            then Wuss.runSecureClient (socketHost target) (socketPort target) (socketPath target) application
            else WebSocket.runClient (socketHost target) (socketPort target) (socketPath target) application
    catch connect $ \(exception :: SomeException) ->
      writeChan events (PhoenixDisconnected (Text.pack (show exception)))
    threadDelay 1500000

connectionLoop :: WebSocket.Connection -> Text -> Value -> Chan ClientCommand -> Chan PhoenixEvent -> IO ()
connectionLoop connection topic joinPayload commands events = do
  sendFrame connection (PhoenixFrame (Just "1") (Just "1") topic "phx_join" joinPayload)
  writeChan events PhoenixConnected
  writer <- forkIO (writerLoop connection topic commands events)
  heartbeat <- forkIO (heartbeatLoop connection)
  readerLoop connection events `finally` (killThread writer >> killThread heartbeat)

writerLoop :: WebSocket.Connection -> Text -> Chan ClientCommand -> Chan PhoenixEvent -> IO ()
writerLoop connection topic commands events =
  forever $ do
    command <- readChan commands
    case command of
      Push event payload ->
        catch
          (sendFrame connection (PhoenixFrame Nothing (Just "2") topic event payload))
          (\(exception :: SomeException) -> writeChan events (PhoenixDisconnected (Text.pack (show exception))))
      Close -> WebSocket.sendClose connection ("desktop client closing" :: Text)

heartbeatLoop :: WebSocket.Connection -> IO ()
heartbeatLoop connection =
  forever $ do
    threadDelay 25000000
    sendFrame connection (PhoenixFrame Nothing Nothing "phoenix" "heartbeat" (object []))

readerLoop :: WebSocket.Connection -> Chan PhoenixEvent -> IO ()
readerLoop connection events =
  forever $ do
    bytes <- WebSocket.receiveData connection :: IO Lazy.ByteString
    case eitherDecode bytes of
      Left message -> writeChan events (PhoenixProtocolError (Text.pack message))
      Right frame -> writeChan events (PhoenixFrameReceived frame)

sendFrame :: WebSocket.Connection -> PhoenixFrame Value -> IO ()
sendFrame connection frame = WebSocket.sendTextData connection (encode frame)

socketTarget :: String -> SocketTarget
socketTarget baseUrl =
  case parseURI (buildSocketUrl baseUrl) of
    Nothing -> error "Unable to build a Phoenix socket URL."
    Just uri ->
      let authority = fromMaybe (error "Phoenix socket URL is missing a host.") (uriAuthority uri)
          scheme = uriScheme uri
          defaultPort = if scheme == "wss:" then 443 else 80
          port =
            case uriPort authority of
              ':' : portText -> fromMaybe defaultPort (readMaybePort portText)
              _ -> defaultPort
       in SocketTarget
            { secureSocket = scheme == "wss:",
              socketHost = uriRegName authority,
              socketPort = port,
              socketPath = uriPath uri <> uriQuery uri
            }

readMaybePort :: String -> Maybe Int
readMaybePort value =
  case reads value of
    [(port, "")] -> Just port
    _ -> Nothing

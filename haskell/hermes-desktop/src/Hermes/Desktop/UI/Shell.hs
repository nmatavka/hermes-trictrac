{-# LANGUAGE OverloadedStrings #-}

module Hermes.Desktop.UI.Shell
  ( runShell,
  )
where

import Control.Monad (foldM, when)
import Data.Aeson (Pair, Value (..), object, (.=))
import Data.Aeson.Key (fromText)
import qualified Data.Text as Text
import Data.Text (Text)
import Graphics.Gloss
import Graphics.Gloss.Interface.IO.Game
import Hermes.Desktop.Catalog
import Hermes.Desktop.Config
import Hermes.Desktop.Paths
import Hermes.Desktop.Protocol.PhoenixClient
import Hermes.Desktop.Protocol.Snapshot
import Hermes.Desktop.Protocol.TableData
import Hermes.Desktop.Runtime.Local

data UiScreen = LobbyScreen | TableScreen

data DesktopUi = DesktopUi
  { uiConfig :: DesktopConfig,
    uiCatalog :: DesktopCatalog,
    uiRuntime :: Either String LocalRuntimeHandle,
    uiScreen :: UiScreen,
    uiVariant :: Text,
    uiManualVariant :: Text,
    uiTavli :: Bool,
    uiMultiSeat :: Bool,
    uiMoreGames :: Bool,
    uiAiOpponent :: Bool,
    uiClient :: Maybe PhoenixClient,
    uiGame :: Maybe GameSnapshot,
    uiStatus :: Text,
    uiSelectedFrom :: Maybe Value,
    uiAmbiguousMoves :: [LegalMove],
    uiChatEditing :: Bool,
    uiChatDraft :: Text
  }

runShell :: DesktopConfig -> SupportPaths -> DesktopCatalog -> Either String LocalRuntimeHandle -> IO ()
runShell config _paths catalog runtimeResult =
  playIO
    (InWindow "Hermes Desktop" (1280, 800) (40, 40))
    (makeColorI 16 18 24 255)
    30
    (initialUi config catalog runtimeResult)
    (pure . renderUi)
    handleUiEvent
    updateUi

initialUi :: DesktopConfig -> DesktopCatalog -> Either String LocalRuntimeHandle -> DesktopUi
initialUi config catalog runtimeResult =
  DesktopUi
    { uiConfig = config,
      uiCatalog = catalog,
      uiRuntime = runtimeResult,
      uiScreen = LobbyScreen,
      uiVariant = variantId config,
      uiManualVariant = variantId config,
      uiTavli = False,
      uiMultiSeat = False,
      uiMoreGames = False,
      uiAiOpponent = opponentMode config == AiOpponent,
      uiClient = Nothing,
      uiGame = Nothing,
      uiStatus = runtimeStatus runtimeResult,
      uiSelectedFrom = Nothing,
      uiAmbiguousMoves = [],
      uiChatEditing = False,
      uiChatDraft = ""
    }

runtimeStatus :: Either String LocalRuntimeHandle -> Text
runtimeStatus (Right handle) = "Local runtime ready at " <> runtimeBaseUrl handle
runtimeStatus (Left message) = Text.pack message

renderUi :: DesktopUi -> Picture
renderUi ui =
  Pictures
    [ color (makeColorI 231 239 244 255) (Translate (-590) 355 (Scale 0.28 0.28 (Text "HERMES DESKTOP"))),
      case uiScreen ui of
        LobbyScreen -> renderLobby ui
        TableScreen -> renderTable ui,
      color (makeColorI 167 184 194 255) (label (-590) (-370) 0.12 (uiStatus ui))
    ]

renderLobby :: DesktopUi -> Picture
renderLobby ui =
  Pictures
    [ label (-590) 292 0.15 "Choose a Game",
      renderButton (-545) 242 1040 34 (not (uiMultiSeat ui)) "Head-to-head",
      renderButton (-545) 200 1040 34 (uiMultiSeat ui) "Multi-seat tables",
      if uiMultiSeat ui then renderMultiSeatLobby ui else renderHeadToHeadLobby ui
    ]

renderHeadToHeadLobby :: DesktopUi -> Picture
renderHeadToHeadLobby ui =
  Pictures
    ( primaryButtons
        <> [ renderButton (-545) (-105) 260 34 (uiMoreGames ui) "More games",
             renderButton (-265) (-105) 260 34 (not (uiAiOpponent ui)) "Play Against: Human",
             renderButton 15 (-105) 260 34 (uiAiOpponent ui) "Play Against: Computer"
           ]
        <> tavliControls
        <> moreButtons
        <> [renderButton (-545) (-305) 540 42 False "Enter table"]
    )
  where
    primaryButtons =
      concatMap (uncurry renderPrimaryRow) (zip [145, 82] (chunk4 (primaryVariants (uiCatalog ui))))
    renderPrimaryRow y entries =
      [ renderButton x y 250 48 (selectedPrimary entry) (menuTitle entry)
        | (x, entry) <- zip [-545, -285, -25, 235] entries
      ]
    selectedPrimary entry =
      if uiTavli ui
        then variantId entry `elem` ["backgammon", "tapa", "jacquet"]
        else variantId entry == uiVariant ui
    tavliEligible = uiManualVariant ui `elem` ["backgammon", "tapa", "jacquet"]
    tavliControls =
      if tavliEligible
        then
          [ label (-545) (-165) 0.15 "Tavli",
            renderButton (-420) (-180) 100 32 (not (uiTavli ui)) "Off",
            renderButton (-310) (-180) 100 32 (uiTavli ui) "On"
          ]
            <> if uiTavli ui then [label (-180) (-170) 0.12 "Backgammon → Tapa → Jacquet"] else []
        else []
    moreButtons =
      if uiMoreGames ui
        then
          [ renderButton x y 250 36 (variantId entry == uiVariant ui) (menuTitle entry)
            | (row, entries) <- zip [0 :: Int ..] (chunk4 (moreVariants (uiCatalog ui))),
              (column, entry) <- zip [0 :: Int ..] entries,
              let x = -545 + fromIntegral column * 260,
              let y = -235 - fromIntegral row * 44
          ]
        else []

renderMultiSeatLobby :: DesktopUi -> Picture
renderMultiSeatLobby ui =
  Pictures
    ( label (-590) 145 0.15 "Choose a Multi-seat Table"
        : [ renderButton (-545) y 1040 38 (sessionFormatId format == uiVariant ui) (sessionFormatTitle format <> " — " <> sessionFormatMeta format)
            | (format, y) <- zip (multiSeatFormats (lobby (uiCatalog ui))) [100, 55 .. -260]
          ]
        <> [renderButton (-545) (-320) 540 42 False "Enter table"]
    )

renderTable :: DesktopUi -> Picture
renderTable ui =
  case uiGame ui of
    Nothing -> label (-590) 230 0.2 "Connecting to table…"
    Just game ->
      Pictures
        [ label (-590) 290 0.16 (tableHeading game),
          label (-590) 260 0.13 ("Turn: " <> turnText game <> "    Dice: " <> diceText game),
          renderActionRow ui game,
          renderBoard ui game,
          renderMoveChoices ui,
          renderPendingChoices game,
          renderTableControls ui,
          label (-590) (-335) 0.13 (if uiChatEditing ui then "Chat: " <> uiChatDraft ui <> "_" else "Click chat, type, then press Enter")
        ]
  where
    tableHeading game =
      let activeLeg = maybe "" (" · " <>) (activeLegId game)
       in variantId game <> activeLeg <> " · " <> statusText game

renderActionRow :: DesktopUi -> GameSnapshot -> Picture
renderActionRow ui game =
  Pictures
    [ renderButton (-545) 205 120 34 (actionEnabled "can_roll" game) "Roll",
      renderButton (-415) 205 120 34 (actionEnabled "can_undo" game) "Undo",
      renderButton (-285) 205 120 34 (actionEnabled "can_confirm" game) "Confirm",
      renderButton (-155) 205 120 34 (actionEnabled "can_reset" game) "Reset",
      renderButton (-25) 205 120 34 False "Resign",
      renderButton 105 205 150 34 False "Remain seated",
      renderButton 265 205 150 34 False "Claim queue",
      renderButton 425 205 120 34 False "Claim roster"
    ]

renderBoard :: DesktopUi -> GameSnapshot -> Picture
renderBoard ui game =
  Pictures (topRow <> bottomRow <> [boardFrame])
  where
    points = boardPoints game
    topRow = [renderPoint ui game point x 80 | (point, x) <- zip (reverse (filter ((>= 12) . pointIndex) points)) pointXs]
    bottomRow = [renderPoint ui game point x (-95) | (point, x) <- zip (filter ((< 12) . pointIndex) points) pointXs]
    pointXs = [-520, -430 .. 490]
    boardFrame = color (makeColorI 97 69 44 255) (lineLoop [(-560, 135), (560, 135), (560, -150), (-560, -150)])

renderPoint :: DesktopUi -> GameSnapshot -> PointStack -> Float -> Float -> Picture
renderPoint ui game point x y =
  Pictures
    [ color fill (Translate x y (rectangleSolid 78 90)),
      color white (Translate (x - 31) (y + 26) (Scale 0.1 0.1 (Text (show (pointIndex point))))),
      renderPieces (pointPieces point) x y
    ]
  where
    selectable = any ((== pointSpace (pointIndex point)) . legalFrom) (legalMoves game)
    target = maybe False (\source -> any (\move -> legalFrom move == source && legalTo move == pointSpace (pointIndex point)) (legalMoves game)) (uiSelectedFrom ui)
    fill
      | target = makeColorI 67 145 116 255
      | selectable = makeColorI 105 83 43 255
      | otherwise = makeColorI 61 47 35 255

renderPieces :: [Text] -> Float -> Float -> Picture
renderPieces pieces x y =
  Pictures
    [ Translate x (y - 12 - fromIntegral index * 9) (color (pieceColor piece) (circleSolid 7))
      | (piece, index) <- zip (take 7 pieces) [0 :: Int ..]
    ]

pieceColor :: Text -> Color
pieceColor "white" = makeColorI 224 229 222 255
pieceColor "black" = makeColorI 39 44 48 255
pieceColor _ = greyN 0.5

renderMoveChoices :: DesktopUi -> Picture
renderMoveChoices ui =
  Pictures
    [ renderButton (-545) y 540 30 False (moveLabel move)
      | (move, y) <- zip (uiAmbiguousMoves ui) [-210, -245 ..]
    ]
  where
    moveLabel move = spaceLabel (legalFrom move) <> " → " <> spaceLabel (legalTo move) <> maybe "" ((" · die " <>) . Text.pack . show) (legalDie move)

renderPendingChoices :: GameSnapshot -> Picture
renderPendingChoices game =
  Pictures
    [ renderButton 35 y 190 30 False choice
      | (_event, choice, _payload, y) <- zipChoiceRows (pendingChoices game)
    ]

zipChoiceRows :: [(Text, Text, Value)] -> [(Text, Text, Value, Float)]
zipChoiceRows choices = [(event, labelText, payload, y) | ((event, labelText, payload), y) <- zip choices [-210, -245 ..]]

renderTableControls :: DesktopUi -> Picture
renderTableControls _ui =
  Pictures
    [ renderButton (-545) (-330) 220 30 False "Chat",
      renderButton (-315) (-330) 220 30 False "Back to lobby"
    ]

renderButton :: Float -> Float -> Float -> Float -> Bool -> Text -> Picture
renderButton x y width height selected text =
  Pictures
    [ color background (Translate (x + width / 2) (y + height / 2) (rectangleSolid width height)),
      color border (Translate (x + width / 2) (y + height / 2) (rectangleWire width height)),
      color white (Translate (x + 10) (y + height / 2 - 5) (Scale 0.115 0.115 (Text (Text.unpack text))))
    ]
  where
    background = if selected then makeColorI 48 120 108 255 else makeColorI 39 49 60 255
    border = if selected then makeColorI 133 224 196 255 else makeColorI 102 121 134 255

label :: Float -> Float -> Float -> Text -> Picture
label x y scale text = Translate x y (Scale scale scale (Text (Text.unpack text)))

diceText :: GameSnapshot -> Text
diceText game = Text.intercalate ", " (map (Text.pack . show) (diceValues game))

handleUiEvent :: Event -> DesktopUi -> IO DesktopUi
handleUiEvent event ui =
  case event of
    EventKey (MouseButton LeftButton) Down _ position -> handleClick position ui
    EventKey (Char character) Down _ _ | uiChatEditing ui -> pure ui {uiChatDraft = uiChatDraft ui <> Text.singleton character}
    EventKey (SpecialKey KeyBackspace) Down _ _ | uiChatEditing ui -> pure ui {uiChatDraft = Text.dropEnd 1 (uiChatDraft ui)}
    EventKey (SpecialKey KeyEnter) Down _ _ | uiChatEditing ui -> sendChat ui
    _ -> pure ui

handleClick :: (Float, Float) -> DesktopUi -> IO DesktopUi
handleClick position ui =
  case uiScreen ui of
    LobbyScreen -> handleLobbyClick position ui
    TableScreen -> handleTableClick position ui

handleLobbyClick :: (Float, Float) -> DesktopUi -> IO DesktopUi
handleLobbyClick position ui
  | hit (-545, 242, 1040, 34) position = pure ui {uiMultiSeat = False, uiTavli = False}
  | hit (-545, 200, 1040, 34) position = pure ui {uiMultiSeat = True, uiTavli = False}
  | uiMultiSeat ui = handleSessionClick position ui
  | otherwise = handleHeadToHeadClick position ui

handleHeadToHeadClick :: (Float, Float) -> DesktopUi -> IO DesktopUi
handleHeadToHeadClick position ui
  | hit (-545, -105, 260, 34) position = pure ui {uiMoreGames = not (uiMoreGames ui)}
  | hit (-265, -105, 260, 34) position = pure ui {uiAiOpponent = False}
  | hit (15, -105, 260, 34) position =
      pure $
        if uiTavli ui && not tavliComputerAvailable
          then ui {uiAiOpponent = True, uiTavli = False, uiVariant = uiManualVariant ui, uiStatus = "Tavli Zero is not released; restored the selected component game."}
          else ui {uiAiOpponent = True}
  | tavliEligible && hit (-420, -180, 100, 32) position = pure ui {uiTavli = False, uiVariant = uiManualVariant ui}
  | tavliEligible && hit (-310, -180, 100, 32) position =
      pure $
        if uiAiOpponent ui && not tavliComputerAvailable
          then ui {uiStatus = "Tavli Zero is not released yet."}
          else ui {uiTavli = True}
  | hit (-545, -305, 540, 42) position = joinTable ui
  | otherwise =
      case clickedVariant position ui of
        Just entry | not (uiTavli ui) -> pure ui {uiVariant = variantId entry, uiManualVariant = variantId entry}
        _ -> pure ui
  where
    tavliEligible = uiManualVariant ui `elem` ["backgammon", "tapa", "jacquet"]
    tavliComputerAvailable = maybe False (aiAvailable . localAi) (findVariant "tavli" (uiCatalog ui))

handleSessionClick :: (Float, Float) -> DesktopUi -> IO DesktopUi
handleSessionClick position ui
  | hit (-545, -320, 540, 42) position = joinTable ui
  | otherwise =
      case [format | (format, y) <- zip (multiSeatFormats (lobby (uiCatalog ui))) [100, 55 .. -260], hit (-545, y, 1040, 38) position] of
        (format : _) -> pure ui {uiVariant = sessionFormatId format, uiManualVariant = sessionFormatId format}
        [] -> pure ui

clickedVariant :: (Float, Float) -> DesktopUi -> Maybe VariantCatalogEntry
clickedVariant position ui =
  let primary = concat (chunk4 (primaryVariants (uiCatalog ui)))
      primaryHits =
        [ entry
          | (row, entries) <- zip [0 :: Int ..] (chunk4 primary),
            (column, entry) <- zip [0 :: Int ..] entries,
            hit (-545 + fromIntegral column * 260, 145 - fromIntegral row * 63, 250, 48) position
        ]
      moreHits =
        [ entry
          | uiMoreGames ui,
            (row, entries) <- zip [0 :: Int ..] (chunk4 (moreVariants (uiCatalog ui))),
            (column, entry) <- zip [0 :: Int ..] entries,
            hit (-545 + fromIntegral column * 260, -235 - fromIntegral row * 44, 250, 36) position
        ]
   in firstOrNothing (primaryHits <> moreHits)

joinTable :: DesktopUi -> IO DesktopUi
joinTable ui = do
  let config = uiConfig ui
      selected = currentVariant ui
      bot = selectedBot ui
      joinPayload =
        object
          ( [ "user" .= playerName config,
              "variant" .= selected,
              "client_id" .= ("desktop:" <> lobbyName config)
            ]
              <> maybe [] (\kind -> ["bot" .= kind]) bot
              <> sessionDefaults ui
          )
  client <- startPhoenixClient (Text.unpack (serverUrl config)) ("games:" <> lobbyName config) joinPayload
  pure ui {uiScreen = TableScreen, uiClient = Just client, uiStatus = "Joining " <> selected <> "…"}

currentVariant :: DesktopUi -> Text
currentVariant ui = if uiTavli ui then "tavli" else uiVariant ui

selectedBot :: DesktopUi -> Maybe Text
selectedBot ui
  | not (uiAiOpponent ui) = Nothing
  | otherwise = do
      entry <- findVariant (currentVariant ui) (uiCatalog ui)
      info <- Just (localAi entry)
      if aiAvailable info then aiKind info else Nothing

sessionDefaults :: DesktopUi -> [Pair]
sessionDefaults ui =
  case filter ((== uiVariant ui) . sessionFormatId) (multiSeatFormats (lobby (uiCatalog ui))) of
    (format : _) -> concatMap sessionFieldPair (sessionFormatJoinFields format)
    [] -> []
  where
    sessionFieldPair field
      | joinFieldId field == "cash_per_jeton" = ["cash_per_jeton_minor" .= (100 :: Int)]
      | otherwise = [fromText (joinFieldId field) .= joinFieldDefault field]

handleTableClick :: (Float, Float) -> DesktopUi -> IO DesktopUi
handleTableClick position ui
  | hit (-545, 205, 120, 34) position = pushAction "roll" ui
  | hit (-415, 205, 120, 34) position = pushAction "undo" ui
  | hit (-285, 205, 120, 34) position = pushAction "confirm" ui
  | hit (-155, 205, 120, 34) position = pushAction "reset" ui
  | hit (-25, 205, 120, 34) position = pushAction "resign" ui
  | hit (105, 205, 150, 34) position = pushAction "remain_seated" ui
  | hit (265, 205, 150, 34) position = pushAction "claim_queue_spot" ui
  | hit (425, 205, 120, 34) position = pushAction "claim_roster_slot" ui
  | hit (-545, -330, 220, 30) position = pure ui {uiChatEditing = True}
  | hit (-315, -330, 220, 30) position = pure ui {uiScreen = LobbyScreen, uiSelectedFrom = Nothing, uiAmbiguousMoves = []}
  | otherwise =
      case uiGame ui >>= pendingChoiceAt position of
        Just (event, payload) -> pushActionPayload event payload ui
        Nothing -> handleBoardClick position ui

handleBoardClick :: (Float, Float) -> DesktopUi -> IO DesktopUi
handleBoardClick position ui =
  case uiGame ui >>= clickedPoint position of
    Nothing -> chooseAmbiguousMove position ui
    Just space ->
      case uiGame ui of
        Nothing -> pure ui
        Just game ->
          case uiSelectedFrom ui of
            Nothing ->
              if any ((== space) . legalFrom) (legalMoves game)
                then pure ui {uiSelectedFrom = Just space, uiStatus = "Choose a legal destination."}
                else pure ui
            Just source ->
              let candidates = filter (\move -> legalFrom move == source && legalTo move == space) (legalMoves game)
               in case candidates of
                    [] -> pure ui {uiSelectedFrom = Nothing}
                    [move] -> pushMove move ui
                    moves -> pure ui {uiAmbiguousMoves = moves, uiStatus = "Choose the exact legal move."}

chooseAmbiguousMove :: (Float, Float) -> DesktopUi -> IO DesktopUi
chooseAmbiguousMove position ui =
  case [move | (move, y) <- zip (uiAmbiguousMoves ui) [-210, -245 ..], hit (-545, y, 540, 30) position] of
    (move : _) -> pushMove move ui
    [] -> pure ui

pendingChoiceAt :: (Float, Float) -> GameSnapshot -> Maybe (Text, Value)
pendingChoiceAt position game =
  firstOrNothing
    [ (event, payload)
      | (event, _labelText, payload, y) <- zipChoiceRows (pendingChoices game),
        hit (35, y, 190, 30) position
    ]

pushMove :: LegalMove -> DesktopUi -> IO DesktopUi
pushMove move ui = do
  pushActionPayload "move" (movePayload move) ui
  pure ui {uiSelectedFrom = Nothing, uiAmbiguousMoves = [], uiStatus = "Move sent to the rules engine."}

pushAction :: Text -> DesktopUi -> IO DesktopUi
pushAction event ui = pushActionPayload event (object []) ui

pushActionPayload :: Text -> Value -> DesktopUi -> IO DesktopUi
pushActionPayload event payload ui = do
  case uiClient ui of
    Just client -> pushPhoenix client event payload
    Nothing -> pure ()
  pure ui

sendChat :: DesktopUi -> IO DesktopUi
sendChat ui
  | Text.null (Text.strip (uiChatDraft ui)) = pure ui {uiChatEditing = False}
  | otherwise = do
      result <- pushActionPayload "chat" (object ["chat" .= uiChatDraft ui]) ui
      pure result {uiChatEditing = False, uiChatDraft = "", uiStatus = "Chat sent."}

updateUi :: Float -> DesktopUi -> IO DesktopUi
updateUi _seconds ui =
  case uiClient ui of
    Nothing -> pure ui
    Just client -> drainEvents client ui

drainEvents :: PhoenixClient -> DesktopUi -> IO DesktopUi
drainEvents client initial = do
  event <- tryReadPhoenixEvent client
  case event of
    Nothing -> pure initial
    Just next -> applyPhoenixEvent next initial >>= drainEvents client

applyPhoenixEvent :: PhoenixEvent -> DesktopUi -> IO DesktopUi
applyPhoenixEvent event ui =
  case event of
    PhoenixConnected -> pure ui {uiStatus = "Connected; waiting for the table state…"}
    PhoenixDisconnected message -> pure ui {uiStatus = "Connection lost: " <> message}
    PhoenixProtocolError message -> pure ui {uiStatus = "Protocol warning: " <> message}
    PhoenixFrameReceived frame ->
      case gameFromChannelPayload (payload frame) of
        Just game -> pure ui {uiGame = Just game, uiStatus = "Table updated."}
        Nothing ->
          if "unauthorized" `Text.isInfixOf` Text.pack (show (payload frame))
            then pure ui {uiStatus = "This server requires browser-session Bluesky sign-in; use the web client."}
            else
              if event frame == "phx_error"
                then pure ui {uiStatus = "Table rejected the request."}
                else pure ui

clickedPoint :: (Float, Float) -> GameSnapshot -> Maybe Value
clickedPoint position game =
  firstOrNothing
    [ pointSpace (pointIndex point)
      | (point, x, y) <- pointPositions (boardPoints game),
        hit (x - 39, y - 45, 78, 90) position
    ]

pointPositions :: [PointStack] -> [(PointStack, Float, Float)]
pointPositions points =
  let top = reverse (filter ((>= 12) . pointIndex) points)
      bottom = filter ((< 12) . pointIndex) points
      xs = [-520, -430 .. 490]
   in [(point, x, 80) | (point, x) <- zip top xs] <> [(point, x, -95) | (point, x) <- zip bottom xs]

chunk4 :: [a] -> [[a]]
chunk4 [] = []
chunk4 values = take 4 values : chunk4 (drop 4 values)

findVariant :: Text -> DesktopCatalog -> Maybe VariantCatalogEntry
findVariant id catalog = firstOrNothing (filter ((== id) . variantId) (variants catalog))

menuTitle :: VariantCatalogEntry -> Text
menuTitle entry = maybe (variantTitle entry) id (variantMenuLabel entry)

firstOrNothing :: [a] -> Maybe a
firstOrNothing (value : _) = Just value
firstOrNothing [] = Nothing

hit :: (Float, Float, Float, Float) -> (Float, Float) -> Bool
hit (x, y, width, height) (pointerX, pointerY) =
  pointerX >= x && pointerX <= x + width && pointerY >= y && pointerY <= y + height

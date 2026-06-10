{-# LANGUAGE OverloadedStrings #-}

module Hermes.Desktop.UI.Shell
  ( runShell,
  )
where

import Data.Maybe (catMaybes)
import Data.Text (Text)
import qualified Data.Text as Text
import Graphics.Gloss
import Graphics.Gloss.Interface.IO.Display (displayIO)
import Graphics.Gloss.Juicy (loadJuicyPNG)
import Hermes.Desktop.Catalog
import Hermes.Desktop.Config
import Hermes.Desktop.Paths
import Hermes.Desktop.Runtime.Local

data UiAssets = UiAssets
  { greenChecker :: Maybe Picture,
    redChecker :: Maybe Picture,
    greenDie :: Maybe Picture,
    redDie :: Maybe Picture
  }

runShell :: DesktopConfig -> SupportPaths -> DesktopCatalog -> Either String LocalRuntimeHandle -> IO ()
runShell config paths catalog runtimeResult = do
  assets <- loadAssets paths

  displayIO
    (InWindow "Hermes Desktop" (1280, 800) (40, 40))
    (makeColorI 16 18 24 255)
    (renderShell config paths catalog runtimeResult assets)

loadAssets :: SupportPaths -> IO UiAssets
loadAssets paths = do
  greenCheckerPicture <- loadJuicyPNG (imagesDir paths <> "/checker-green.png")
  redCheckerPicture <- loadJuicyPNG (imagesDir paths <> "/checker-red.png")
  greenDiePicture <- loadJuicyPNG (imagesDir paths <> "/dice_green1.png")
  redDiePicture <- loadJuicyPNG (imagesDir paths <> "/dice_red1.png")

  pure
    UiAssets
      { greenChecker = greenCheckerPicture,
        redChecker = redCheckerPicture,
        greenDie = greenDiePicture,
        redDie = redDiePicture
      }

renderShell :: DesktopConfig -> SupportPaths -> DesktopCatalog -> Either String LocalRuntimeHandle -> UiAssets -> IO Picture
renderShell config paths catalog runtimeResult assets =
  pure $
    Pictures
      [ color azure (Translate (-560) 320 (Scale 0.35 0.35 (Text "Hermes Desktop"))),
        color white (renderLines (-560) 250 (shellLines config paths catalog runtimeResult)),
        renderAssets assets
      ]

shellLines :: DesktopConfig -> SupportPaths -> DesktopCatalog -> Either String LocalRuntimeHandle -> [Text]
shellLines config paths catalog runtimeResult =
  [ "Mode: " <> modeLabel (runMode config),
    "Server URL: " <> serverUrl config,
    "Lobby: " <> lobbyName config,
    "Variant: " <> variantId config,
    "Opponent: " <> opponentLabel (opponentMode config),
    "Support root: " <> Text.pack (supportRoot paths),
    "Local head-to-head variants: " <> Text.pack (show (length (localVariants catalog))),
    "Online session variants: " <> Text.pack (show (length (sessionVariants catalog))),
    runtimeLine runtimeResult,
    "This window is the desktop shell foundation: runtime launch, assets, catalog, and protocol layers are wired."
  ]

runtimeLine :: Either String LocalRuntimeHandle -> Text
runtimeLine (Right handle) = "Local runtime: ready at " <> runtimeBaseUrl handle
runtimeLine (Left message) = "Runtime status: " <> Text.pack message

modeLabel :: RunMode -> Text
modeLabel LocalMode = "local"
modeLabel OnlineMode = "online"

opponentLabel :: OpponentMode -> Text
opponentLabel HumanOpponent = "human"
opponentLabel AiOpponent = "ai"

renderLines :: Float -> Float -> [Text] -> Picture
renderLines startX startY linesToDraw =
  Pictures $
    zipWith
      (\index lineText ->
         Translate startX (startY - fromIntegral index * 42) $
           Scale 0.14 0.14 $
             Text (Text.unpack lineText))
      [0 ..]
      linesToDraw

renderAssets :: UiAssets -> Picture
renderAssets assets =
  Pictures $
    catMaybes
      [ fmap (Translate 350 120 . Scale 0.45 0.45) (greenChecker assets),
        fmap (Translate 470 120 . Scale 0.45 0.45) (redChecker assets),
        fmap (Translate 350 (-20) . Scale 0.45 0.45) (greenDie assets),
        fmap (Translate 470 (-20) . Scale 0.45 0.45) (redDie assets)
      ]

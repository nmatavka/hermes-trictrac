module Hermes.Desktop.Paths
  ( SupportPaths (..),
    resolveSupportPaths,
  )
where

import Control.Applicative ((<|>))
import Data.List (find)
import System.Directory (doesFileExist, makeAbsolute)
import System.Environment (getExecutablePath, lookupEnv)
import System.FilePath ((</>), normalise, takeDirectory)

data SupportPaths = SupportPaths
  { supportRoot :: FilePath,
    generatedDir :: FilePath,
    imagesDir :: FilePath,
    desktopCatalogPath :: FilePath,
    runtimeRoot :: FilePath,
    runtimeExecutable :: FilePath
  }
  deriving (Eq, Show)

resolveSupportPaths :: Maybe FilePath -> IO SupportPaths
resolveSupportPaths overrideRoot = do
  executablePath <- getExecutablePath
  envRoot <- lookupEnv "HERMES_DESKTOP_SUPPORT_ROOT"

  let executableDir = takeDirectory executablePath
      defaultSupportRoot = normalise (executableDir </> ".." </> "support")
      supportRootCandidate =
        case overrideRoot <|> envRoot of
          Just explicitRoot -> explicitRoot
          Nothing -> defaultSupportRoot

  absoluteSupportRoot <- makeAbsolute supportRootCandidate

  let resolvedSupportRoot = normalise absoluteSupportRoot
      resolvedRuntimeRoot = normalise (takeDirectory resolvedSupportRoot </> "runtime" </> "hermes_trictrac")
      runtimeCandidates =
        [ resolvedRuntimeRoot </> "bin" </> "hermes_trictrac",
          resolvedRuntimeRoot </> "bin" </> "hermes_trictrac.bat",
          resolvedRuntimeRoot </> "bin" </> "hermes_trictrac.exe"
        ]

  runtimePath <- firstExisting runtimeCandidates

  pure
    SupportPaths
      { supportRoot = resolvedSupportRoot,
        generatedDir = resolvedSupportRoot </> "ui" </> "generated",
        imagesDir = resolvedSupportRoot </> "images" </> "6besh",
        desktopCatalogPath = resolvedSupportRoot </> "ui" </> "generated" </> "desktop-variant-catalog.json",
        runtimeRoot = resolvedRuntimeRoot,
        runtimeExecutable = runtimePath
      }

firstExisting :: [FilePath] -> IO FilePath
firstExisting paths = do
  matches <- mapM (\path -> doesFileExist path >>= \exists -> pure (path, exists)) paths
  pure $
    maybe (head paths) fst $
      find snd matches

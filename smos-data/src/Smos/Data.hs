{-# LANGUAGE RecordWildCards #-}

module Smos.Data
    ( module Smos.Data.Types
    , readSmosFile
    , writeSmosFile
    , parseSmosFile
    , parseSmosFileYaml
    , parseSmosFileJSON
    , smosFileYamlBS
    , smosFileJSONBS
    , smosFileJSONPrettyBS
    , emptySmosFile
    , prettySmosForest
    , clockInAt
    , clockOutAt
    , stateHistoryState
    , stateHistorySetState
    , entryState
    , entrySetState
    ) where

import Data.Aeson as JSON
import Data.Aeson.Encode.Pretty as JSON
import qualified Data.ByteString as SB
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as LB
import qualified Data.Text as T
import Data.Time
import Data.Tree
import Data.Validity
import Data.Yaml as Yaml
import Data.Yaml.Builder as Yaml

import Control.Applicative
import Control.Arrow

import Path
import Path.IO

import Smos.Data.Types

readSmosFile :: Path Abs File -> IO (Maybe (Either String SmosFile))
readSmosFile fp = do
    mContents <- forgivingAbsence $ SB.readFile $ toFilePath fp
    case mContents of
        Nothing -> pure Nothing
        Just contents_ -> pure $ Just $ parseSmosFile contents_

writeSmosFile :: Path Abs File -> SmosFile -> IO ()
writeSmosFile fp sf = do
    ensureDir $ parent fp
    SB.writeFile (toFilePath fp) (smosFileYamlBS sf)

parseSmosFile :: ByteString -> Either String SmosFile
parseSmosFile bs = parseSmosFileYaml bs <|> parseSmosFileJSON bs

parseSmosFileYaml :: ByteString -> Either String SmosFile
parseSmosFileYaml = left show . Yaml.decodeEither'

parseSmosFileJSON :: ByteString -> Either String SmosFile
parseSmosFileJSON = JSON.eitherDecode . LB.fromStrict

smosFileYamlBS :: SmosFile -> ByteString
smosFileYamlBS sf = Yaml.toByteString sf

smosFileJSONBS :: SmosFile -> LB.ByteString
smosFileJSONBS = JSON.encode

smosFileJSONPrettyBS :: SmosFile -> LB.ByteString
smosFileJSONPrettyBS = JSON.encodePretty

emptySmosFile :: SmosFile
emptySmosFile = SmosFile []

prettySmosForest :: Forest Entry -> String
prettySmosForest ts = unlines $ map prettySmosTree ts

prettySmosTree :: Tree Entry -> String
prettySmosTree Node {..} =
    unlines [prettySmosEntry rootLabel, prettySmosForest subForest]

prettySmosEntry :: Entry -> String
prettySmosEntry Entry {..} = T.unpack $ headerText entryHeader

clockInAt :: UTCTime -> Logbook -> Maybe Logbook
clockInAt now lb =
    case lb of
        LogClosed es -> Just $ LogOpen now es
        LogOpen {} -> Nothing

clockOutAt :: UTCTime -> Logbook -> Maybe Logbook
clockOutAt now lb =
    case lb of
        LogClosed {} -> Nothing
        LogOpen start es -> Just $ LogClosed $ LogbookEntry start now : es

stateHistoryState :: StateHistory -> Maybe TodoState
stateHistoryState (StateHistory tups) =
    case tups of
        [] -> Nothing
        (StateHistoryEntry mts _:_) -> mts

stateHistorySetState ::
       UTCTime -> Maybe TodoState -> StateHistory -> Maybe StateHistory
stateHistorySetState now mts sh =
    constructValid $
    sh {unStateHistory = StateHistoryEntry mts now : unStateHistory sh}

entryState :: Entry -> Maybe TodoState
entryState = stateHistoryState . entryStateHistory

entrySetState :: UTCTime -> Maybe TodoState -> Entry -> Maybe Entry
entrySetState now mts e = do
    sh' <- stateHistorySetState now mts $ entryStateHistory e
    pure $ e {entryStateHistory = sh'}

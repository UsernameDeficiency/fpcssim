{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.Aeson (FromJSON, ToJSON)
import Data.Map (Map)
import GHC.Generics (Generic)
import Web.Scotty (get, scotty, text)

-- ==========================================
-- 1. Core Entities
-- ==========================================

data MatchFormat = Bo1 | Bo3 | Bo5 deriving (Show, Eq, Generic)

instance ToJSON MatchFormat

instance FromJSON MatchFormat

data MatchStatus = Pending | Completed deriving (Show, Eq, Generic)

instance ToJSON MatchStatus

instance FromJSON MatchStatus

data Team = Team
  { teamId :: String,
    name :: String,
    seed :: Int,
    strength :: Float
  }
  deriving (Show, Eq, Generic)

instance ToJSON Team

instance FromJSON Team

-- ==========================================
-- 2. The Match Record
-- ==========================================

data Match = Match
  { matchId :: String,
    matchRound :: Int,
    teamA :: Team,
    teamB :: Team,
    format :: MatchFormat,
    scoreA :: Int,
    scoreB :: Int,
    status :: MatchStatus,
    winnerId :: Maybe String -- 'Maybe' is Haskell's way of saying it can be null
  }
  deriving (Show, Eq, Generic)

instance ToJSON Match

instance FromJSON Match

-- ==========================================
-- 3. The Tournament State
-- ==========================================

data TeamStanding = TeamStanding
  { wins :: Int,
    losses :: Int,
    buchholz :: Int,
    pastOpponents :: [String]
  }
  deriving (Show, Eq, Generic)

instance ToJSON TeamStanding

instance FromJSON TeamStanding

data TournamentState = TournamentState
  { currentRound :: Int,
    stageType :: String,
    teams :: [Team],
    history :: [Match],
    activeMatches :: [Match],
    standings :: Map String TeamStanding
  }
  deriving (Show, Eq, Generic)

instance ToJSON TournamentState

instance FromJSON TournamentState

-- ==========================================
-- Main Server Entry Point
-- ==========================================

main :: IO ()
main = do
  putStrLn "Starting FPCSSIM Backend on port 3000..."
  scotty 3000 $ do
    get "/api/health" $ do
      text "FPCSSIM Haskell Backend is running smoothly!"

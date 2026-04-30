{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.Aeson (FromJSON, ToJSON)
import Data.List (sortBy)
import Data.Map (Map)
import Data.Ord (comparing)
import GHC.Generics (Generic)
import Network.Wai.Middleware.Cors (simpleCors)
import Web.Scotty (ActionM, get, json, jsonData, middleware, post, scotty, text)

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
    winnerId :: Maybe String
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
-- Tournament Engine
-- ==========================================

-- | Set up initial matches by pairing the top and bottom seeds (1v9, 2v10... for 16 teams)
generateRound1Matches :: [Team] -> String -> [Match]
generateRound1Matches inputTeams stage =
  let sortedTeams = sortBy (comparing seed) inputTeams
      (topHalf, bottomHalf) = splitAt (length sortedTeams `div` 2) sortedTeams

      -- Determine format based on tournament stage
      matchFormat = if stage == "Stage3" then Bo3 else Bo1

      -- Zip teams together to create matches
      createMatch i (tA, tB) =
        Match
          { matchId = "r1_m" ++ show i,
            matchRound = 1,
            teamA = tA,
            teamB = tB,
            format = matchFormat,
            scoreA = 0,
            scoreB = 0,
            status = Pending,
            winnerId = Nothing
          }
   in zipWith createMatch ([1 .. 8] :: [Int]) (zip topHalf bottomHalf)

-- | Initialize the entire tournament state
initTournament :: String -> [Team] -> TournamentState
initTournament stage inputTeams =
  TournamentState
    { currentRound = 1,
      stageType = stage,
      teams = inputTeams,
      history = [],
      activeMatches = generateRound1Matches inputTeams stage,
      standings = mempty
    }

-- ==========================================
-- Main Server Entry Point
-- ==========================================

main :: IO ()
main = do
  putStrLn "Starting FPCSSIM Backend on port 3000..."
  scotty 3000 $ do
    middleware simpleCors

    get "/api/health" $ do
      text "FPCSSIM Haskell Backend is running smoothly!"

    post "/api/init" $ do
      incomingTeams <- jsonData :: Web.Scotty.ActionM [Team]
      let initialState = initTournament "Stage1" incomingTeams
      json initialState

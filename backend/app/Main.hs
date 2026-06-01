{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Monad.IO.Class (liftIO)
import Data.Aeson (FromJSON, ToJSON)
import Data.List (sortBy)
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Ord (comparing)
import GHC.Generics (Generic)
import Network.Wai.Middleware.Cors (cors, corsRequestHeaders, simpleCorsResourcePolicy)
import System.Random (StdGen, newStdGen, randomR)
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
    odds :: Float -- Decimal odds (e.g., 2.0 for 50% implied probability)
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
      halfCount = length sortedTeams `div` 2
      (topHalf, bottomHalf) = splitAt halfCount sortedTeams

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
            status = Pending,
            winnerId = Nothing
          }
   in zipWith createMatch ([1 .. halfCount] :: [Int]) (zip topHalf bottomHalf)

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
-- Simulation Engine
-- ==========================================

-- | Simulate a single match using Outright Betting Odds
simulateMatch :: StdGen -> Match -> (Match, StdGen)
simulateMatch gen match =
  if status match == Completed
    then (match, gen) -- Skip if already simulated
    else
      let oddsA = odds (teamA match)
          oddsB = odds (teamB match)

          -- Convert outright odds to win probality
          -- TODO: Account for bo1 vs bo3 chances if odds are entered manually (bo1 is easier to win for the underdog)
          impliedA = 1.0 / oddsA
          impliedB = 1.0 / oddsB
          -- Normalize to get rid of overround
          probA = impliedA / (impliedA + impliedB)

          -- Determine the winner (If roll < probA, Team A wins)
          (roll, nextGen) = randomR (0.0 :: Float, 1.0 :: Float) gen
          teamAWon = roll < probA

          winner = if teamAWon then Just (teamId (teamA match)) else Just (teamId (teamB match))
          updatedMatch = match {status = Completed, winnerId = winner}
       in (updatedMatch, nextGen)

-- | Recursively simulate all matches in a list
simulateMatches :: StdGen -> [Match] -> ([Match], StdGen)
simulateMatches gen [] = ([], gen)
simulateMatches gen (m : ms) =
  let (m', gen') = simulateMatch gen m
      (ms', gen'') = simulateMatches gen' ms
   in (m' : ms', gen'')

-- | Process a list of completed matches to update the team standings
updateStandings :: [Match] -> Map String TeamStanding -> Map String TeamStanding
updateStandings completedMatches initialStandings = foldr applyMatch initialStandings completedMatches
  where
    applyMatch match currentStandings =
      let tA = teamId (teamA match)
          tB = teamId (teamB match)
          aWon = winnerId match == Just tA
          bWon = winnerId match == Just tB

          -- Create an empty standing if the team isn't in the map yet
          emptyStanding = TeamStanding {wins = 0, losses = 0, buchholz = 0, pastOpponents = []}

          standingA = Map.findWithDefault emptyStanding tA currentStandings
          standingB = Map.findWithDefault emptyStanding tB currentStandings

          newA =
            standingA
              { wins = wins standingA + if aWon then 1 else 0,
                losses = losses standingA + if aWon then 0 else 1,
                pastOpponents = tB : pastOpponents standingA
              }
          newB =
            standingB
              { wins = wins standingB + if bWon then 1 else 0,
                losses = losses standingB + if bWon then 0 else 1,
                pastOpponents = tA : pastOpponents standingB
              }
       in Map.insert tA newA (Map.insert tB newB currentStandings)

-- | Simulates the current active round and updates the global tournament state
simulateRound :: StdGen -> TournamentState -> TournamentState
simulateRound gen state =
  let (simulatedMatches, _) = simulateMatches gen (activeMatches state)

      -- Calculate new standings based on these results
      newStandings = updateStandings simulatedMatches (standings state)

      -- Move the completed matches into the tournament history
      newHistory = history state ++ simulatedMatches
   in state
        { activeMatches = simulatedMatches, -- Leave them here briefly so the UI can display the results
          history = newHistory,
          standings = newStandings
        }

-- ==========================================
-- Main Server Entry Point
-- ==========================================

-- TODO: Might want to add debug logs
main :: IO ()
main = do
  putStrLn "Starting FPCSSIM Backend on port 3000..."
  scotty 3000 $ do
    let customCors = cors (const $ Just $ simpleCorsResourcePolicy {corsRequestHeaders = ["Content-Type"]})
    middleware customCors

    get "/api/health" $ do
      text "FPCSSIM Backend is running smoothly!"

    -- TODO: Add error handling for invalid input
    post "/api/init" $ do
      incomingTeams <- jsonData :: Web.Scotty.ActionM [Team]
      let initialState = initTournament "Stage1" incomingTeams
      json initialState

    post "/api/simulate" $ do
      currentState <- jsonData :: Web.Scotty.ActionM TournamentState

      -- Get a true random seed from the system
      gen <- liftIO newStdGen

      let newState = simulateRound gen currentState
      json newState

{-# LANGUAGE OverloadedStrings #-}

module Main where

import Web.Scotty
import Data.Aeson (object, (.=))
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as TL
import Data.Time.Clock
import Data.Time.Format
import Network.Wai.Middleware.RequestLogger (logStdoutDev)

main :: IO ()
main = do
  putStrLn "Starting scotty server on port 3000"
  scotty 3000 $ do
    middleware logStdoutDev

    get "/api/hello" $ do
      json $ object ["message" .= ("Hello from Haskell scotty!" :: Text)]

    get "/api/time" $ do
      now <- liftAndCatchIO getCurrentTime
      let t = formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" now
      json $ object ["time" .= (t :: String)]

    get "/" $ do
      text (TL.pack "Scotty backend running. Use /api/hello and /api/time")

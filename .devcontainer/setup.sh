#!/bin/bash

# Install required libraries
sudo apt-get update
sudo apt-get install -y libgmp-dev zlib1g-dev

# Install the Haskell Language Server so the VS Code Haskell extension doesn't prompt for it
ghcup install hls 2.14.0.0 --set

# Configure Cabal to build in /tmp to bypass Docker file-sync latency
cd backend
echo 'builddir: /tmp/dist-newstyle' > cabal.project.local

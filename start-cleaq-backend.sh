#!/bin/bash

tmux neww -c ~/dev/cleaq/backend-dev-env/ "docker compose up"
tmux splitw -c ~/dev/cleaq/backend-api/ -v "./gradlew :management:bootRun --args='--spring.profiles.active=local,custom'; zsh -i"
tmux splitw -c ~/dev/cleaq/backend-api/ -h "./gradlew :order:bootRun --args='--spring.profiles.active=local,custom'; zsh -i"

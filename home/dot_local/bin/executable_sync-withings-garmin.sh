#!/usr/bin/env bash

if [ ! -f $XDG_DATA_HOME/withings-sync/.withings_user.json ]
then
  docker run -v $XDG_DATA_HOME/withings-sync:/root --interactive --tty \
    --name withings ghcr.io/jaroslawhartman/withings-sync:master \
    --garmin-username=$(op read op://private/garmin/username) \
    --garmin-password=$(op read op://private/garmin/password)
else
  docker start -i withings
fi

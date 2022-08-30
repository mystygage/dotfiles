#!/bin/sh

PREZTODIR=$HOME/.zprezto
REPO=https://github.com/sorin-ionescu/prezto.git

if [ ! -d $PREZTODIR ]; then
  git clone --recursive $REPO $PREZTODIR
fi

#!/bin/bash

CWD=$(dirname $0)
echo "$(swift --version)" > "$CWD/version"

exec 1> "$CWD/stdout"
exec 2> "$CWD/stderr"

if [ "$_COLOR" = true ] ; then
  export TERM=xterm-256color
  sh "$CWD/faketty.sh" $@ "$CWD/main.swift"
else
  $@ "$CWD/main.swift"
fi

mv "$CWD/stdout" "$CWD/completed"

#!/bin/bash

service postgresql start

cp -R /code /working_code
cd /working_code

echo "Starting test step"

export MIX_ENV=test

echo "Starting prebuild configuration"
mix local.hex --force
echo "local hex executed"
mix local.rebar --force
mix deps.clean --all
echo "local rebar executed"
echo "Downloading deps"
mix deps.get
echo "Starting credo linter"
mix credo --strict || exit 1
echo "Starting tests"
mix test || exit 1
echo "Test npm dependencies"
cd assets
npm i
npm run lint


echo "Test step finish successfully"

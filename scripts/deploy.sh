#!/bin/bash

./gradlew assembleDebug

zip -r features.zip features

ruby scripts/devicefarm.rb

./gradlew assembleDebug

zip -r ../features.zip ../features

ruby devicefarm.rb

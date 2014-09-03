#!/bin/bash

VERSION="2.6"
applicationName="CheeseCutter.app"
backgroundPictureName="background.png"
source="dist"
title="CheeseCutter ${VERSION}"
size=20000
finalDMGName="CheeseCutter_${VERSION}.dmg"

mkdir "${source}"
cp -r "${applicationName}" "${source}"

hdiutil create -srcfolder "${source}" -volname "${title}" -fs HFS+ \
      -fsargs "-c c=64,a=16,e=16" -format UDRW -size ${size}k pack.temp.dmg
device=$(hdiutil attach -readwrite -noverify -noautoopen "pack.temp.dmg" | \
         egrep '^/dev/' | sed 1q | awk '{print $1}')
sleep 5
mkdir /Volumes/"${title}"/.background
cp arch/background.png /Volumes/"${title}"/.background
cp -r tunes README COPYING Changelog /Volumes/"${title}"/

pushd /Volumes/"${title}"
ln -s /Applications
popd

echo '
   tell application "Finder"
     tell disk "'${title}'"
           open
           set current view of container window to icon view
           set toolbar visible of container window to false
           set statusbar visible of container window to false
           set the bounds of container window to {400, 100, 885, 430}
           set theViewOptions to the icon view options of container window
           set arrangement of theViewOptions to not arranged
           set icon size of theViewOptions to 72
           set background picture of theViewOptions to file ".background:'${backgroundPictureName}'"
           delay 1
	   set position of item ${applicationName} of container window to {100, 100}
           set position of item "Applications" of container window to {375, 100}
           update without registering applications
           close
	   open
	   delay 5
           eject
     end tell
   end tell
' | osascript

chmod -Rf go-w /Volumes/"${title}"
sync
sync
hdiutil detach ${device}
hdiutil convert pack.temp.dmg -format UDZO -imagekey zlib-level=9 -o ${finalDMGName}
rm pack.temp.dmg 

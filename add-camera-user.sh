#!/bin/bash
# Adds a watch-only user to a Reolink camera, for Frigate. Some Reolink models (like the Video Doorbell WiFi) can't add
# users in their app or web page, so this asks the camera's own API directly.
# Usage: bash add-camera-user.sh     (needs curl; passwords are typed, never shown, and not saved anywhere)
# Avoid the characters " and \ in the passwords.

read -p "Camera IP address: " IP
read -s -p "Camera admin password: " ADMIN; echo
read -p "New user name [frigate]: " NAME; NAME=${NAME:-frigate}
read -s -p "New user password: " PW; echo
read -s -p "Same password again: " PW2; echo
[ "$PW" = "$PW2" ] || { echo "The passwords don't match. Nothing was changed."; exit 1; }

API="http://$IP/cgi-bin/api.cgi"
TOKEN=$(curl -s -m 10 "$API?cmd=Login" \
  -d "[{\"cmd\":\"Login\",\"param\":{\"User\":{\"Version\":\"0\",\"userName\":\"admin\",\"password\":\"$ADMIN\"}}}]" \
  | grep -o '"name" *: *"[^"]*"' | head -1 | cut -d'"' -f4)
[ -n "$TOKEN" ] || { echo "Couldn't log in to the camera: check its IP address and admin password."; exit 1; }

# level "guest" = the app's "User" type: it can watch, but can't change settings
if curl -s -m 10 "$API?cmd=AddUser&token=$TOKEN" \
     -d "[{\"cmd\":\"AddUser\",\"param\":{\"User\":{\"userName\":\"$NAME\",\"password\":\"$PW\",\"level\":\"guest\"}}}]" \
     | grep -q '"rspCode" *: *200'; then
  echo "Done: $NAME can watch the video, but can't change any settings."
else
  echo "The camera didn't add $NAME. Maybe that user already exists?"
fi
curl -s -m 10 "$API?cmd=Logout&token=$TOKEN" -d '[{"cmd":"Logout","param":{}}]' > /dev/null

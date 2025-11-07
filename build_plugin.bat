@echo off
echo Building MotionDeck plugin ...
rojo build build.project.json -o "%LOCALAPPDATA%\Roblox\Plugins\MotionDeck.rbxm"
echo Done! MotionDeck updated.
pause
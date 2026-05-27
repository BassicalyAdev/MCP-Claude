@echo off
echo ========================================
echo  AI Assistant for Roblox Studio - Setup
echo ========================================
echo.

:: Check Node.js
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Node.js is not installed. Please install it from https://nodejs.org
    pause
    exit /b 1
)

echo [1/3] Installing dependencies...
call npm install
if %errorlevel% neq 0 (
    echo [ERROR] npm install failed
    pause
    exit /b 1
)

echo.
echo [2/3] Building server...
call npm run build
if %errorlevel% neq 0 (
    echo [ERROR] Build failed
    pause
    exit /b 1
)

echo.
echo [3/3] Copying plugin to Roblox Studio...
set PLUGIN_DIR=%LOCALAPPDATA%\Roblox\Plugins
if not exist "%PLUGIN_DIR%" mkdir "%PLUGIN_DIR%"
copy /Y "plugin\ClaudeMCP.lua" "%PLUGIN_DIR%\ClaudeMCP.lua" >nul
echo Plugin copied to: %PLUGIN_DIR%\ClaudeMCP.lua

echo.
echo ========================================
echo  Setup complete!
echo ========================================
echo.
echo Free AI providers:
echo   Groq         - https://console.groq.com
echo   Gemini       - https://aistudio.google.com
echo   Ollama       - https://ollama.com (local, no key)
echo   HuggingFace  - https://huggingface.co
echo.
echo To use:
echo   1. Open Roblox Studio (plugin loads automatically)
echo   2. Run: npm start
echo   3. Click the gear icon in the plugin to set your API key
echo   4. Select an AI provider and start chatting!
echo.
pause

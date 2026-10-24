@echo off
setlocal
cd /d "%~dp0"

where bundle >nul 2>nul
if errorlevel 1 (
  echo Bundler was not found. Install Ruby with Devkit and Bundler, then try again.
  pause
  exit /b 1
)

call bundle check
if errorlevel 1 (
  echo.
  echo Installing the site's missing Ruby dependencies...
  call bundle install
  if errorlevel 1 (
	echo.
	echo Dependency installation failed. Review the error above.
	pause
	exit /b 1
  )
)

echo.
echo All About Foxes: http://localhost:4002
echo Live reload is enabled. Press Ctrl+C to stop the server.
echo.
call bundle exec jekyll serve --host 127.0.0.1 --port 4002 --livereload --livereload-port 35731 --livereload-min-delay 1 --open-url
set "server_exit=%errorlevel%"
if not "%server_exit%"=="0" (
  echo.
  echo The Jekyll server stopped with an error. Review the message above.
  pause
)
exit /b %server_exit%
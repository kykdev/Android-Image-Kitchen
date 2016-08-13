@echo off

cd %~p0
if exist workspace_* for /f "delims=" %%a in ('dir /a:d /s /b workspace_*') do rd /s /q %%a > nul 2>&1

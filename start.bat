@echo off
echo Iniciando servidor RTMP con Ngrok...
docker compose up -d
echo.
echo Esperando conexion (30 segundos)...
timeout /t 30 /nobreak >nul
echo.
echo Panel de control Ngrok: http://localhost:4040
echo Servidor local: http://localhost:8080
echo.
echo Para obtener URLs publicas, ve a: http://localhost:4040
pause
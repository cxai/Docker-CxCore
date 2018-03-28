FROM microsoft/windowsservercore:latest

LABEL description="CxSAST Managers docker image"
LABEL maintainer="Alex Ivkin"
LABEL version="1.1 beta"

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG SQL_SERVER=sql-server\\SQLEXPRESS
ARG SQL_PWD
ARG SQL_USER=sa

# Both are provided at the build time
ARG CX_DOWNLOAD_URL

VOLUME c:/temp
EXPOSE 80 443
WORKDIR c:/CxSAST/

# Disable telemetry
RUN Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0

RUN Invoke-WebRequest $env:CX_DOWNLOAD_URL -OutFile CxSetup.exe -UseBasicParsing ; \
    C:/CxSAST/CxSetup.exe /install /quiet ENGINE=0 MANAGER=1 WEB=0 AUDIT=0 INSTALLFOLDER="C:\CxSAST" INSTALLSHORTCUTS=0 SQLAUTH=1 SQLSERVER="$env:SQL_SERVER" SQLUSER="$env:SQL_USER" SQLPWD="$env:SQL_PWD" ; \
    Wait-Process CxSetup; \
    Remove-Item C:/CxSAST/CxSetup.exe;

COPY start.ps1 c:/CxSAST/

# Optional db hostname override at the run-time to be able to run both manually and as a swarm
ENV sast_db _

CMD c:/CxSAST/start.ps1

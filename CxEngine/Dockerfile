FROM microsoft/windowsservercore:latest

LABEL description="Checkmarx CxSAST Engine docker image"
LABEL maintainer="Alex Ivkin"
LABEL version="1.1 beta"

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG SQL_SERVER=sql-server\\SQLEXPRESS
ARG SQL_PWD
ARG SQL_USER=sa

ARG CX_DOWNLOAD_URL

VOLUME c:/temp
EXPOSE 80 443
WORKDIR c:/CxSAST/

# Disable telemetry
RUN Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0

RUN Invoke-WebRequest $env:CX_DOWNLOAD_URL -OutFile CxSetup.exe -UseBasicParsing ; \
    C:/CxSAST/CxSetup.exe /install /quiet ENGINE=1 MANAGER=0 WEB=0 AUDIT=0 INSTALLFOLDER="C:\CxSAST" INSTALLSHORTCUTS=0 SQLAUTH=1 SQLSERVER="$env:SQL_SERVER" SQLUSER="$env:SQL_USER" SQLPWD="$env:SQL_PWD" ; \
    Wait-Process CxSetup ; \
    Remove-Item C:/CxSAST/CxSetup.exe ;

# Placeholders for the SAST variables provided at runtime to configure the engine into the manager
ENV sast_server _
ENV sast_admin _
ENV sast_adminpwd _

COPY start.ps1 c:/CxSAST/

CMD c:/CxSAST/start.ps1

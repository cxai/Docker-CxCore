FROM microsoft/windowsservercore:latest as base

LABEL description="CxSAST Portal docker image"
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
    C:/CxSAST/CxSetup.exe /install /quiet ENGINE=0 MANAGER=0 WEB=1 AUDIT=0 INSTALLFOLDER="C:\CxSAST" INSTALLSHORTCUTS=0 SQLAUTH=1 SQLSERVER="$env:SQL_SERVER" SQLUSER="$env:SQL_USER" SQLPWD="$env:SQL_PWD" ; \
    Wait-Process CxSetup; \
    Remove-Item C:/CxSAST/CxSetup.exe ;

# install components required for the distributed installation
# External Cache 1.1, URL Rewrite 2.1 and Request Router 3.0

RUN Invoke-WebRequest http://download.microsoft.com/download/C/A/5/CA5FAD87-1E93-454A-BB74-98310A9C523C/ExternalDiskCache_amd64.msi -OutFile ExternalDiskCache_amd64.msi -UseBasicParsing ; \
    Start-Process msiexec.exe -ArgumentList '/i', 'ExternalDiskCache_amd64.msi', '/quiet', '/norestart' -NoNewWindow -Wait ; \
    Remove-Item ExternalDiskCache_amd64.msi ; \
    Invoke-WebRequest http://download.microsoft.com/download/D/D/E/DDE57C26-C62C-4C59-A1BB-31D58B36ADA2/rewrite_amd64_en-US.msi -OutFile rewrite_amd64.msi -UseBasicParsing ; \
    Start-Process msiexec.exe -ArgumentList '/i', 'rewrite_amd64.msi', '/quiet', '/norestart' -NoNewWindow -Wait ; \
    Remove-Item rewrite_amd64.msi ; \
    Invoke-WebRequest https://download.microsoft.com/download/E/9/8/E9849D6A-020E-47E4-9FD0-A023E99B54EB/requestRouter_amd64.msi -OutFile requestRouter_amd64.msi -UseBasicParsing ; \
    Start-Process msiexec.exe -ArgumentList '/i',  'requestRouter_amd64.msi', '/quiet', '/norestart' -NoNewWindow -Wait ; \
    Remove-Item requestRouter_amd64.msi ;

COPY start.ps1 c:/CxSAST/
CMD c:/CxSAST/start.ps1

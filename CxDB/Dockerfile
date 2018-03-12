FROM microsoft/mssql-server-linux:2017-latest

LABEL description="Checkmarx CxDB docker image"
LABEL maintainer="Alex Ivkin"
LABEL version="1.1 alpha"

ENV ACCEPT_EULA Y
ENV MSSQL_PID Express

RUN /opt/mssql/bin/mssql-conf set telemetry.customerfeedback false

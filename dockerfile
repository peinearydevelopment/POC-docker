############################
# SDK image                #
# for building the project #
############################
FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS build
ARG CERTIFICATE_PASSWORD="Test|234"
ARG CONFIGURATION="Release"
RUN echo "Build configuration $CONFIGURATION."

#################
# nuget restore #
#################
COPY **/*.csproj /src/
WORKDIR /src
RUN dotnet restore

#################
# build project #
#################
# copies all files in Apis except for those listed in .dockerignore file
COPY **/*.* /src/
RUN dotnet publish -c $CONFIGURATION -o /dist

WORKDIR /
SHELL ["/bin/bash", "-c"]
# https://letsencrypt.org/docs/certificates-for-localhost/#making-and-trusting-your-own-certificates
RUN openssl req \
-x509 \
-out localhost.crt \
-keyout localhost.key \
-newkey rsa:2048 \
-nodes \
-sha256 \
-subj "/CN=localhost" \
-extensions EXT \
-config <(printf "[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")

# create a pfx out of the .crt and .key files
RUN openssl pkcs12 \
-export \
-out dist/localhost.pfx \
-inkey localhost.key \
-in localhost.crt \
-certfile localhost.crt \
-passout pass:${CERTIFICATE_PASSWORD}

#################################
# Runtime image                 #
# for running the compiled code #
#################################
FROM mcr.microsoft.com/dotnet/core/aspnet:3.1 AS runtime
ARG CERTIFICATE_PASSWORD="Test|234"
COPY --from=build /dist /app
WORKDIR /app

ENV ASPNETCORE_Kestrel__Certificates__Default__Password="$CERTIFICATE_PASSWORD"
ENV ASPNETCORE_Kestrel__Certificates__Default__Path=localhost.pfx
ENV ASPNETCORE_URLS=https://+:443
EXPOSE 443
ENTRYPOINT ["dotnet", "Apis.dll"]

# Commands to use this file
# docker build -t my-apis .
# docker run --name my-apis -p 613:443 my-apis
# docker stop my-apis
# docker container rm my-apis
# to test its up and running, run `Invoke-WebRequest https://localhost:613 -SkipCertificateCheck` in powershell

# Outstanding questions:
# https?
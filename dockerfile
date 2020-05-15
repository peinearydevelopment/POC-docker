############################
# SDK image                #
# for building the project #
############################
FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS build
ARG CONFIGURATION="Release"
RUN echo "Build configuration $CONFIGURATION."

#################
# nuget restore #
#################
COPY **/*.csproj ./src/
WORKDIR /src
RUN dotnet restore

#################
# build project #
#################
# copies all files in Apis except for those listed in .dockerignore file
COPY **/*.* ./src/
RUN dotnet publish -c $CONFIGURATION -o /dist
WORKDIR /dist

#################################
# Runtime image                 #
# for running the compiled code #
#################################
FROM mcr.microsoft.com/dotnet/core/aspnet:3.1 AS runtime
ARG CERTIFICATE_PASSWORD="Test|234"
# https://letsencrypt.org/docs/certificates-for-localhost/#making-and-trusting-your-own-certificates
# RUN echo "$(openssl version)"
# RUN openssl req \
# -x509 \
# -out localhost.crt \
# -keyout localhost.key \
# -newkey rsa:2048 \
# -nodes \
# -sha256 \
# -subj "/CN=localhost" \
# -extensions EXT \
# -config <(printf "[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")

# Use opnssl to generate a self signed certificate cert.pfx with password $env:certPassword
RUN openssl genrsa -des3 -passout pass:${CERTIFICATE_PASSWORD} -out server.key 2048
RUN openssl rsa -passin pass:${CERTIFICATE_PASSWORD} -in server.key -out server.key
RUN openssl req -sha256 -new -key server.key -out server.csr -subj '/CN=localhost'
RUN openssl x509 -req -sha256 -days 365 -in server.csr -signkey server.key -out server.crt
RUN openssl pkcs12 -export -out cert.pfx -inkey server.key -in server.crt -certfile server.crt -passout pass:${CERTIFICATE_PASSWORD}

COPY --from=build /dist ./app
ENV ASPNETCORE_Kestrel__Certificates__Default__Password="$CERTIFICATE_PASSWORD"
ENV ASPNETCORE_Kestrel__Certificates__Default__Path=/cert.pfx
ENV ASPNETCORE_URLS=https://+:443
EXPOSE 443
ENTRYPOINT ["dotnet", "app/Apis.dll"]

# Commands to use this file
# docker build -t my-apis .
# docker run --name my-apis -p 8000:80 my-apis
# docker stop my-apis
# docker container rm my-apis

# Outstanding questions:
# https?
ARG CERTIFICATE_PASSWORD="Test|234"
ARG CONFIGURATION="Release"
ARG ENVIRONMENT="Development"
ARG PROJECT_NAME="Apis"

############################
# SDK image                #
############################

# for building the project #
FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS build
ARG CERTIFICATE_PASSWORD
ARG CONFIGURATION
ARG PROJECT_NAME
RUN echo "Build project ${PROJECT_NAME} with configuration ${CONFIGURATION}."

# nuget restore ############
COPY ${PROJECT_NAME}/${PROJECT_NAME}.csproj /src/
WORKDIR /src
RUN dotnet restore

# build project ############
# copies all files in Apis except for those listed in .dockerignore file
COPY ${PROJECT_NAME}/*.* /src/
RUN dotnet publish -c ${CONFIGURATION} -o /dist

# create local certificate #
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
#################################

# for running the compiled code #
FROM mcr.microsoft.com/dotnet/core/aspnet:3.1 AS runtime
ARG CERTIFICATE_PASSWORD
ARG ENVIRONMENT
ARG PROJECT_NAME
COPY --from=build /dist /app
WORKDIR /app

ENV ASPNETCORE_Kestrel__Certificates__Default__Password=${CERTIFICATE_PASSWORD}
ENV ASPNETCORE_Kestrel__Certificates__Default__Path=localhost.pfx
ENV ASPNETCORE_URLS=https://+:443
ENV ASPNETCORE_ENVIRONMENT=${Environment}
EXPOSE 443
# https://github.com/moby/moby/issues/18492
# https://stackoverflow.com/questions/40902445/using-variable-interpolation-in-string-in-docker/#40903689
ENV PROJECT_NAME ${PROJECT_NAME}
ENTRYPOINT ["sh", "-c", "dotnet ${PROJECT_NAME}.dll"]




#################################
# Notes                         #
#################################

# Commands to use this file

# docker build -t my-apis .
# docker run --name my-apis -p 613:443 my-apis
# docker stop my-apis
# docker container rm my-apis
# to test its up and running, run `Invoke-WebRequest https://localhost:613 -SkipCertificateCheck` in powershell


# Things to remember

# ARGs can come before FROM, but still need to be declared after FROM to get default value
# Debian's default shell is dash, can be changed with the SHELL command
# ASP.NET docs encourage API projects to only listen on HTTPS port https://docs.microsoft.com/en-us/aspnet/core/security/enforcing-ssl?view=aspnetcore-3.1&tabs=visual-studio

# Questions

# localhost cert created isn't trusted
    # How would one create a real/trusted cert?
        # https://medium.com/@agusnavce/nginx-server-with-ssl-certificates-with-lets-encrypt-in-docker-670caefc2e31
        # probably requires creating cert outside of docker proceses and then including in image through COPY
    # Is there any benefit/downside to having a local cert?
        # End-to-end encryption?
        # Password is included in the container?
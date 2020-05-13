############################
# SDK image                #
# for building the project #
############################
FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS build
ARG CONFIGURATION="Release"
# ARG CERTIFICATE_PASSWORD="Test|234"
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
RUN dotnet publish -c $CONFIGURATION -o ../dist
# RUN dotnet dev-certs https --clean
# RUN dotnet dev-certs https -ep ~/.aspnet/https/aspnetapp.pfx -p $CERTIFICATE_PASSWORD

#################################
# Runtime image                 #
# for running the compiled code #
#################################
FROM mcr.microsoft.com/dotnet/core/aspnet:3.1 AS runtime
COPY --from=build /dist ./
# COPY --from=build ~/.aspnet/https ~/.aspnet/https
ENV ASPNETCORE_URLS=http://+:80
EXPOSE 80
# ENV ASPNETCORE_URLS=http://+:80;https://+:443
# EXPOSE 80 443
ENTRYPOINT ["dotnet", "Apis.dll"]

# Commands to use this file
    # docker build -t my-apis .
    # docker run --name my-apis -p 8000:80 my-apis
    # docker stop my-apis
    # docker container rm my-apis

# Outstanding questions:
    # https?
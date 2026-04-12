# See https://aka.ms/customizecontainer to learn how to customize your debug container and how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
USER app
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src

# Copy all project files since it's a Clean Architecture solution
COPY ["CoupleApp.Backend/CoupleApp.Backend.csproj", "CoupleApp.Backend/"]
COPY ["CoupleApp.Application/CoupleApp.Application.csproj", "CoupleApp.Application/"]
COPY ["CoupleApp.Core/CoupleApp.Core.csproj", "CoupleApp.Core/"]
COPY ["CoupleApp.Infrastructure/CoupleApp.Infrastructure.csproj", "CoupleApp.Infrastructure/"]

# Restore main project (this will restore referenced projects as well)
RUN dotnet restore "./CoupleApp.Backend/CoupleApp.Backend.csproj"

# Copy the rest of the source code
COPY . .
WORKDIR "/src/CoupleApp.Backend"
RUN dotnet build "./CoupleApp.Backend.csproj" -c $BUILD_CONFIGURATION -o /app/build

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "./CoupleApp.Backend.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Define entrypoint
ENTRYPOINT ["dotnet", "CoupleApp.Backend.dll"]

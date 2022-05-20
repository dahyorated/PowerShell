[[_TOC_]]

# Config and Eureka Configuration

## Repos
One git repo shared by all config services
- Need to create the repo
- Name: configuration
- Branch: master
- URL: https://eyglobaltaxplatform.visualstudio.com/Global%20Tax%20Platform/_git/configuration
- repoAccessToken (read-only)

## Config Services
One config service for each subscription/region
- PROD - EUW
- PROD - USE
- NON-PROD EUW
- NON-PROD USE

### Parameters
- Repo
- configSecret

## Eureka Services
One Eureka service per regions/environment.
- NON-PROD subscriptions
  - DEV-EUW
  - DEV-USE
  - QAT-EUW
  - UAT-EUW
  - PRF-EUW
- PROD subscriptions
  - STG-EUW
  - STG-USE
  - DMO-EUW
  - PRD-EUW
  - PRD-USE

### Paramters
- configSecret
- eurekaSecret
- configUrl (app service name, not complete URL)
- ASPNETCORE_ENVIRONMENT

## Spring References

- [Repo Authentication](https://cloud.spring.io/spring-cloud-config/reference/html/#_authentication)

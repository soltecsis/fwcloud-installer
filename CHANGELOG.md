# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [1.0.6] - 2022-12-15
### Fixed
- Regular expression bug in Linux distribution detection method. Reported by Jeremy Mueller.


## [1.0.5] - 2022-01-31
### Added
- Restart fwcloud service after update it.
- Init fwcloud-ui submodules.
- Clone only the last commit of the main branch of each FWCloud GitHub repository.
- Docker installation support by means of the --docker option.
- Use Node.js 16 LTS.


## [1.0.4] - 2021-01-27
### Added
- Recursively clone git submodules.
- Improve proxy setup.
- Detect proxy config.
- Upgrade procedure from old directory schema to the new one with all the fwcloud processes under /opt/fwcloud/

### Fixed
- Location of .env file.
- Removed database selection and install MariaDB if no database engine installed. 
- Improve database type detection.

## [1.0.4] - 2021-10-27
### Fixed
- Disable audit log in npm install.

## [1.0.3] - 2020-12-01
### Added
- Install fwcloud-websrv.
- New directory structure:
    /opt/fwcloud/websrv
    /opt/fwcloud/ui
    /opt/fwcloud/api
    /opt/fwcloud/updater

## [1.0.2] - 2020-11-24
### Added
- Steps required for install fwcloud-updater.
- Update if fwcloud is already installed.
- Install fwcloud-updater if it is not still present.

### Fixed
- Syntax error: "Cheking FWCloud" -> "Checking FWCloud"

## [1.0.1] - 2020-11-17
### Added
- Proxy support for system packages and node modules.

## [4.2.1](https://github.com/kasp1/Dozer/compare/v4.2.0...v4.2.1) (2023-05-11)


### Bug Fixes

* updated the native ui to build ([78d164b](https://github.com/kasp1/Dozer/commit/78d164b9e612d869577227fa645d5adf7569c828))

# [4.2.0](https://github.com/kasp1/Dozer/compare/v4.1.0...v4.2.0) (2023-05-11)


### Features

* `--key=<value>` specifies any environment variable for the pipeline steps ([15bf07d](https://github.com/kasp1/Dozer/commit/15bf07dec4450506bd573d1d21fc60b90aa82d29))

# [4.1.0](https://github.com/kasp1/Dozer/compare/v4.0.2...v4.1.0) (2022-10-27)


### Features

* the argument --no-browser will prevent the browser tab from being opened if --webui is present ([740c34e](https://github.com/kasp1/Dozer/commit/740c34ed9969b1b6db2d133405bd0ccad4ff9a76))
* values of variables with sensitive information are now automatically hidden in user interface ([4907b04](https://github.com/kasp1/Dozer/commit/4907b04679e842290ef07499b45a0db40c241799))

## [4.0.2](https://github.com/kasp1/Dozer/compare/v4.0.1...v4.0.2) (2022-10-16)


### Bug Fixes

* if NodeJS is installed in the system, NodeJS steps are by default executed with it ([5ce9443](https://github.com/kasp1/Dozer/commit/5ce94439bdb375776f9149660d8bad2890ae5c85))
* increased the output buffer for pipeline steps, allows running steps with a lot of output ([e1df129](https://github.com/kasp1/Dozer/commit/e1df12923fc8b7117d39b1be34f138ba384dcf07))
* the WebUI didn't get served on some circumstances ([ad5eaa1](https://github.com/kasp1/Dozer/commit/ad5eaa114cb618e25686538a8e7c742534aa1cae))

## [4.0.1](https://github.com/kasp1/Dozer/compare/v4.0.0...v4.0.1) (2022-10-13)


### Bug Fixes

* windows taskbar title of Dozer window ([236d403](https://github.com/kasp1/Dozer/commit/236d4038bcad67852f9660bbbd856d46265b197f))

# [4.0.0](https://github.com/kasp1/Dozer/compare/v3.1.0...v4.0.0) (2022-10-13)


### Bug Fixes

* downloading of online steps and replacing variables in commands ([00c0873](https://github.com/kasp1/Dozer/commit/00c087303ec0af5a54e9d315492c0f4ae764500c))
* fixed Runner builds where the binary missed dependencies ([ef25efd](https://github.com/kasp1/Dozer/commit/ef25efd0a7597956ca73240d9c5d54c57377f8b9))
* main title now updates according to step in progress, Dozer logo aligned, fixed windows CI/CD ([3513054](https://github.com/kasp1/Dozer/commit/3513054000760f18816fbcc51dfd759a049675aa))


### Features

* added internal web UI server ([2c9a6c9](https://github.com/kasp1/Dozer/commit/2c9a6c957f951910d9fb26ba9a8b6c28adf226cf))
* added switch between free mode and automatic execution following ([a7439cb](https://github.com/kasp1/Dozer/commit/a7439cbadc05774ddcba886e3e16327e78eef239))
* copy button, case-insensitive filtering ([a3aaaa9](https://github.com/kasp1/Dozer/commit/a3aaaa9e96fc30a572e17f790badfe8c73202f58))
* dev fail pipeline, overall pipeline fail UI state ([3ccfdd0](https://github.com/kasp1/Dozer/commit/3ccfdd003e9769a20d6de853448282b81c2222de))
* native UI experimental layout ([83f9efe](https://github.com/kasp1/Dozer/commit/83f9efe30b389fb7ee6b9c6f7a90972989b83cc7))
* output filtering, copy-able output, toggle icon buttons, title bar ([69b69b6](https://github.com/kasp1/Dozer/commit/69b69b68bdfe7393a91636351801d4f4fd0aef38))
* the runner and UI are now separate applications communicating over websockets ([034bd0c](https://github.com/kasp1/Dozer/commit/034bd0c3a4978ab74eef1fce62cc642ecc403595))
* tooltips, app icons, env variables dialog ([ec05022](https://github.com/kasp1/Dozer/commit/ec0502231bd3cce39694ae79bf7af3ac38631114))


### BREAKING CHANGES

* The `title` parameter of pipeline steps replaces `displayName`, but `displayName`
will be still accepted if `title` is not present. The `--gui` is replaced by `--webui` and will
start the Web UI in a browser tab if specified (instead of an Electron app as before). The `--gui`
parameter is now reserved for Native UI clients.

# [1.4.0](https://github.com/kasp1/Dozer/compare/v1.3.0...v1.4.0) (2021-07-10)


### Bug Fixes

* pipeline arguments containing space are now wrapped with quotes ([6d3b525](https://github.com/kasp1/Dozer/commit/6d3b525734748aecc3b739f12fdd8ee71c4e87c1))


### Features

* optional command line argument --root <path> can now specify and override the working dir ([ec3461f](https://github.com/kasp1/Dozer/commit/ec3461f9627ec3035b71bc68e5b00392412e7e33))

# Changelog

All notable changes to this project will be documented in this file. See [standard-version](https://github.com/conventional-changelog/standard-version) for commit guidelines.

## [1.3.0](https://github.com/kasp1/Dozer/compare/v1.2.0...v1.3.0) (2020-08-07)


### Features

* Variables are now set with stdout output ([45402a0](https://github.com/kasp1/Dozer/commit/45402a0791c8e27e6010ea2c498903bc1e7bde52))

## [1.2.0](https://github.com/kasp1/Dozer/compare/v1.1.1...v1.2.0) (2020-08-05)


### Features

* Steps now display time they took ([042820b](https://github.com/kasp1/Dozer/commit/042820b571c295ad9676999e8d6a410f9768634e))

### [1.1.1](https://github.com/kasp1/Dozer/compare/v1.1.0...v1.1.1) (2020-08-05)

## [1.1.0](https://github.com/kasp1/Dozer/compare/v1.0.0...v1.1.0) (2020-08-05)


### Features

* Added support for .bat files. ([27be816](https://github.com/kasp1/Dozer/commit/27be816d1f820bbfbc1f6adda419183bec9412c7))
* Step indicators are now more colorful ([f2ebb1d](https://github.com/kasp1/Dozer/commit/f2ebb1d14ed1f23dbfad383c3f2c31f9173a2807))

# Changelog

All notable changes to this project will be documented in this file. See [standard-version](https://github.com/conventional-changelog/standard-version) for commit guidelines.

### [8.0.26](https://github.com/macite/doubtfire-deploy/compare/v8.0.23...v8.0.26) (2024-08-26)


### Bug Fixes

* logging of fail to send message in accept submission ([38abe9e](https://github.com/macite/doubtfire-deploy/commit/38abe9eeb7dedf8f7d26b7b1c659be94d9c42d4a))
* use system timeout command with timeout helper ([b77147c](https://github.com/macite/doubtfire-deploy/commit/b77147c791396e202bbf2e01eb60385a1ae6cd7b))

### [8.0.23](https://github.com/macite/doubtfire-deploy/compare/v8.0.22...v8.0.23) (2024-08-05)


### Bug Fixes

* ensure folders are removed when we move files with file helper ([cbec03d](https://github.com/macite/doubtfire-deploy/commit/cbec03d9e148e5d3fbead9b88621f6c06d368371))
* remove global error and report failures to admin user for tii ([842f233](https://github.com/macite/doubtfire-deploy/commit/842f233d210345682d051e77cc3ddedb98baadc9))

### [8.0.22](https://github.com/macite/doubtfire-deploy/compare/v8.0.21...v8.0.22) (2024-08-01)


### Features

* add email on accept submission error ([1e3acd4](https://github.com/macite/doubtfire-deploy/commit/1e3acd4e64af2f41227c03b8fa53ab71811dac20))
* report high usage on database timeout ([8139f41](https://github.com/macite/doubtfire-deploy/commit/8139f41207a2a2b38f6560cc254d8e65bce40988))


### Bug Fixes

* add awaiting processing pdf ([3e0a1ba](https://github.com/macite/doubtfire-deploy/commit/3e0a1bac485322b6f7936fd3c244cdc5594ca9b1))
* avoid attempts to read negative size in file stream helper ([758a51d](https://github.com/macite/doubtfire-deploy/commit/758a51dfb9f8c5bc2cf2471caf5b8c0875467971))
* change zip of new upload to avoid loss ([218afb9](https://github.com/macite/doubtfire-deploy/commit/218afb9291b6864c3ede03b4f74bceaef81b339f))
* ensure scoop files checks files are a hash ([33ee3ce](https://github.com/macite/doubtfire-deploy/commit/33ee3cecd6e8317cd54f51c4e1e4314725b5085c))
* only try overseer assessment when overseer enabled ([e3d36c2](https://github.com/macite/doubtfire-deploy/commit/e3d36c27cffbeb8e56dc6c2b085665c5d91cd9ce))

### [8.0.21](https://github.com/macite/doubtfire-deploy/compare/v8.0.20...v8.0.21) (2024-07-30)


### Bug Fixes

* delay pdf generation to ensure sufficient time for async task to run ([6753d80](https://github.com/macite/doubtfire-deploy/commit/6753d803a573c3ced9fb58ef202486cc69d3329c))

### [8.0.20](https://github.com/macite/doubtfire-deploy/compare/v8.0.19...v8.0.20) (2024-07-29)


### Bug Fixes

* webhook registration key check ([70f095c](https://github.com/macite/doubtfire-deploy/commit/70f095c3bb762b73738344f6902cfd53e11daf0b))

### [8.0.19](https://github.com/macite/doubtfire-deploy/compare/v8.0.18...v8.0.19) (2024-07-26)


### Bug Fixes

* ensure accept submission checks number of files ([cea12e5](https://github.com/macite/doubtfire-deploy/commit/cea12e5bee7ba7b954bdeff1c5257d2c9c9a841a))
* remove newlines from signing key base64 encoding ([d84856b](https://github.com/macite/doubtfire-deploy/commit/d84856b8e90126e34cb34e4d405acc462af7e147))

### [8.0.18](https://github.com/macite/doubtfire-deploy/compare/v8.0.17...v8.0.18) (2024-07-25)


### Features

* add ability to manually remove webhooks from rails console ([7e9adaa](https://github.com/macite/doubtfire-deploy/commit/7e9adaa50b8db70fb488ae3a489ad521dac5e28a))


### Bug Fixes

* ensure tii signing secret is sent as a base64 string ([efa6692](https://github.com/macite/doubtfire-deploy/commit/efa669273bc8aa56ecfced4d63ab0f9af4649273))

### [8.0.17](https://github.com/macite/doubtfire-deploy/compare/v8.0.16...v8.0.17) (2024-07-22)

### [8.0.16](https://github.com/macite/doubtfire-deploy/compare/v8.0.15...v8.0.16) (2024-07-22)


### Bug Fixes

* ensure comment added on task pdf convert fail ([232dcaa](https://github.com/macite/doubtfire-deploy/commit/232dcaa7c5ea11109d35bc3bd7cd9d3c737259cd))

### [8.0.15](https://github.com/macite/doubtfire-deploy/compare/v8.0.14...v8.0.15) (2024-07-22)


### Bug Fixes

* correct turn it in hmac calculation ([a249662](https://github.com/macite/doubtfire-deploy/commit/a249662d6866a80cf03c5793bc4816a766ad2b97))
* ensure pax header is not included in tex on 2nd pass ([1b2a43c](https://github.com/macite/doubtfire-deploy/commit/1b2a43c0bfe45019b69bbf1952373709c09b67c5))

### [8.0.14](https://github.com/macite/doubtfire-deploy/compare/v8.0.13...v8.0.14) (2024-07-18)


### Features

* allow logging to stdout using env var ([7d47eda](https://github.com/macite/doubtfire-deploy/commit/7d47eda6affafb6056d391a101c39670e3a1b7f6))


### Bug Fixes

* add logging info to debug hmac issues ([de3ec39](https://github.com/macite/doubtfire-deploy/commit/de3ec392612470a1103f6a04c737775965e58ccf))

### [8.0.13](https://github.com/macite/doubtfire-deploy/compare/v8.0.12...v8.0.13) (2024-07-17)


### Features

* add env var to configure log to stdout ([0bf29eb](https://github.com/macite/doubtfire-deploy/commit/0bf29eb79824cfab89a6f4ce5ce15d89f1a77ca5))
* check that old tii submissions upload when eula accepted ([6b08013](https://github.com/macite/doubtfire-deploy/commit/6b08013b423ae990c34224fdd6c358b08026e9f0))


### Bug Fixes

* check need to register webhooks in tii action ([ebbacb9](https://github.com/macite/doubtfire-deploy/commit/ebbacb90cd1602b04489d2d41ee9723d13a75852))
* ensure tii module looks for appropriate user ([4dae884](https://github.com/macite/doubtfire-deploy/commit/4dae884dd29bf443d64654e36134e09e570ce31e))
* ensure webhook test will register hooks ([be21763](https://github.com/macite/doubtfire-deploy/commit/be21763e2b486df0181da1a87ffbddcfb7407388))
* limit tii action log to 25 entries ([03e9214](https://github.com/macite/doubtfire-deploy/commit/03e9214182e07561100b051cbed6e82191cc8750))
* merge student records for deakin students ([4f3979b](https://github.com/macite/doubtfire-deploy/commit/4f3979ba4c00a0040f4899e33e48cd950cb6e833))
* tii action retry resets retries ([789fbad](https://github.com/macite/doubtfire-deploy/commit/789fbada30f8d91cfaff732a4392ecb12d346e3f))

### [8.0.12](https://github.com/macite/doubtfire-deploy/compare/v8.0.11...v8.0.12) (2024-07-15)


### Features

* allow register webhooks to be controlled via config ([e01ed19](https://github.com/macite/doubtfire-deploy/commit/e01ed1940ecc7f91c66ea9d22ebbacae04ce7b70))

### [8.0.11](https://github.com/macite/doubtfire-deploy/compare/v8.0.10...v8.0.11) (2024-07-12)


### Features

* ensure deakin sync retries failed connections ([d4808b0](https://github.com/macite/doubtfire-deploy/commit/d4808b0f9d2653a02e56f868a9f0d9bec6e53826))

### [8.0.10](https://github.com/doubtfire-lms/doubtfire-deploy/compare/v8.0.9...v8.0.10) (2024-07-10)


### Bug Fixes

* ensure failure to send email is handled ([32b1d9f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/32b1d9f94c225e326ed7fbc111565fa75de3ec00))
* ensure logger only logs to stdout in development ([e3fab0d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e3fab0d897bac82dcc14d3ff4b3948245a203b1c))
* ensure sidekiq moves to Rails root before task pdf creation ([bb29f84](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bb29f84c8c4808886cf84b89069a622308d7b859))
* ensure task definitions render when upload requirements are nil ([6373eee](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6373eee8ab38f5b1c79be5e88302c1880e36cc90))
* ensure turn it in actions only occur when tii enabled ([5b8f5d3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5b8f5d35f520f7e59ddfe53d795200f45882c517))
* guard access of pwd incase pwd is invalid ([58d8281](https://github.com/doubtfire-lms/doubtfire-deploy/commit/58d828193ee4448df15d4fcc391d2a1a22338efc))
* turn it in enabled property ([a49fc8c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a49fc8c042d608f109706278f933071e0f058ed2))

### [8.0.9](https://github.com/macite/doubtfire-deploy/compare/v8.0.8...v8.0.9) (2024-07-03)


### Features

* allow new unit code to be provided to rollover ([7f3b752](https://github.com/macite/doubtfire-deploy/commit/7f3b7529a9c8ee0a8800e28aa1504f221f80bc5d))


### Bug Fixes

* ensure main convenor validation on change only ([52450be](https://github.com/macite/doubtfire-deploy/commit/52450bec9039fda80f6f8a6d3a742adc8def8d77))
* remove rollover teaching period ([eacbac1](https://github.com/macite/doubtfire-deploy/commit/eacbac1f659e09252ab24a4fc9e0d5a02d811a00))
* streamline archiving units in maintenance task ([e740d82](https://github.com/macite/doubtfire-deploy/commit/e740d8218478b6ef27795fc15093082c07e0c69a))

### [8.0.8](https://github.com/doubtfire-lms/doubtfire-deploy/compare/v8.0.7...v8.0.8) (2024-07-01)


### Features

* provide task to archive pdfs ([9e85c21](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9e85c2186880a374d5306a8aa4e6eccc108239ff))

## [8.1.0](https://github.com/doubtfire-lms/doubtfire-deploy/compare/v8.0.7...v8.1.0) (2024-07-01)


### Features

* provide task to archive pdfs ([9e85c21](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9e85c2186880a374d5306a8aa4e6eccc108239ff))

### [8.0.7](https://github.com/macite/doubtfire-deploy/compare/v8.0.6...v8.0.7) (2024-07-01)


### Bug Fixes

* remove sync of online students at deakin ([2b64bce](https://github.com/macite/doubtfire-deploy/commit/2b64bcef3b74882403d2b04a9da80a7d0e8c68b6))

### [8.0.6](https://github.com/macite/doubtfire-deploy/compare/v8.0.5...v8.0.6) (2024-06-28)


### Bug Fixes

* ensure upload requirements works in edit ([61f35ce](https://github.com/macite/doubtfire-deploy/commit/61f35cecf8b4af9ab520bfcc9bde72a0d11c7481))

### [8.0.5](https://github.com/macite/doubtfire-deploy/compare/v8.0.4...v8.0.5) (2024-06-27)


### Bug Fixes

* ensure new units can have a different main convenor ([44b6566](https://github.com/macite/doubtfire-deploy/commit/44b656605e44a529078656ba9174b843056e0e31))

### [8.0.4](https://github.com/macite/doubtfire-deploy/compare/v8.0.3...v8.0.4) (2024-06-27)


### Bug Fixes

* ensure unit recode results in file moves ([4d0c10f](https://github.com/macite/doubtfire-deploy/commit/4d0c10faff97db01c2f952f4afd66f02af283bb5))

### [8.0.3](https://github.com/macite/doubtfire-deploy/compare/v8.0.2...v8.0.3) (2024-06-25)


### Bug Fixes

* export task definition to csv ([793b734](https://github.com/macite/doubtfire-deploy/commit/793b73466fa468f1cb51ed69a07d1c8701dff3a8))
* limit exposure of nil for task def fields ([fc1bcfd](https://github.com/macite/doubtfire-deploy/commit/fc1bcfd88407f877d6ed7fadc6f70a8dad0e279f))

### [8.0.2](https://github.com/macite/doubtfire-deploy/compare/v8.0.1...v8.0.2) (2024-06-21)


### Bug Fixes

* ensure file stream has a string path ([fa5ca52](https://github.com/macite/doubtfire-deploy/commit/fa5ca52b1e2470fbb2537e15259f30946b1e8a54))

### [8.0.1](https://github.com/macite/doubtfire-deploy/compare/v7.0.32...v8.0.1) (2024-06-21)


### Bug Fixes

* correct handling of group submissions ([931c9dd](https://github.com/macite/doubtfire-deploy/commit/931c9dd4280e31e935f796bf1d349add1b431c63))
* correct ipynb code ([9e2056d](https://github.com/macite/doubtfire-deploy/commit/9e2056d8d721325683d115db2356fbca8f7380c7))
* correct issues with missing rsvg convert and identified test problems ([2024350](https://github.com/macite/doubtfire-deploy/commit/2024350f8080928597bad2b00f6aacd7a6a1be1f))
* correct merge issues to ensure tests pass ([192bd41](https://github.com/macite/doubtfire-deploy/commit/192bd4175607f8ac2efa1acb6f029883a3bdcea1))
* correct typos in unit role needed for teaching role ([f808ad4](https://github.com/macite/doubtfire-deploy/commit/f808ad437f424f40a4eb68d5218ddf4317ba44b6))
* ensure error reported when viewer not available ([2aaacb6](https://github.com/macite/doubtfire-deploy/commit/2aaacb6e9c181b260e9c7f62f362dd1da2ab98ad))
* ensure ipynb handles markdown, raw, and long output ([955ca0b](https://github.com/macite/doubtfire-deploy/commit/955ca0bf844ad673a445e04012e6950a07f748d8))
* handle long, raw, and markdown ipynb ([609b49b](https://github.com/macite/doubtfire-deploy/commit/609b49bf1b73af9eeeb66e4788c7d6dffbca94fa))
* limit to 3 group attachments in tii upload ([5252639](https://github.com/macite/doubtfire-deploy/commit/525263903a11af362d78b82c8065a665024a3a1f))
* reinstate teaching staff ids ([167eb1a](https://github.com/macite/doubtfire-deploy/commit/167eb1a144ad667d00a8b7c9a469115943048fc4))
* task file import ([#438](https://github.com/macite/doubtfire-deploy/issues/438)) ([8f37943](https://github.com/macite/doubtfire-deploy/commit/8f379430fd48b0449ef21f680165e4323cad1750))
* truncate long lines in PDF conversion ([#439](https://github.com/macite/doubtfire-deploy/issues/439)) ([2425997](https://github.com/macite/doubtfire-deploy/commit/2425997305afb4f6a7964a7cd689a04418828ea1))

## [8.0.0-11](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-10...v8.0.0-11) (2024-05-13)

## [8.0.0-10](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-9...v8.0.0-10) (2024-05-13)


### Bug Fixes

* host url for turn it in integration ([3cd67d7](https://github.com/macite/doubtfire-deploy/commit/3cd67d7c58916cda429d3c0266942cfc2c0ef878))

## [8.0.0-9](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-8...v8.0.0-9) (2024-05-11)


### Bug Fixes

* ensure default log in tii actions ([a9959fe](https://github.com/macite/doubtfire-deploy/commit/a9959fef2223ffca41338b15c973b888253225bf))
* ensure tii launch handles errors so rails can progress ([d7c9c3c](https://github.com/macite/doubtfire-deploy/commit/d7c9c3c8c60b49721aa9cac1f8df6ec716b82422))
* revert to default cache store ([c3a22bf](https://github.com/macite/doubtfire-deploy/commit/c3a22bfee6e9912fd8b4d331d6a6e6f350b72ffa))

## [8.0.0-8](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-7...v8.0.0-8) (2024-05-11)


### Bug Fixes

* adjust log and params in tii_actions ([4bfdfb1](https://github.com/macite/doubtfire-deploy/commit/4bfdfb1faf5bbaf45ec7827ec89e4cd231f88dba))
* display latex math properly in jupyter notebooks ([ba6d615](https://github.com/macite/doubtfire-deploy/commit/ba6d61506a5f699aed299658f9a664123fdaf57b))
* update for dotenv 3 ([ef8611f](https://github.com/macite/doubtfire-deploy/commit/ef8611f917b198064a891f81c02408ff081e977b))

## [8.0.0-7](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-6...v8.0.0-7) (2024-05-02)

## [8.0.0-6](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-5...v8.0.0-6) (2024-05-02)


### Bug Fixes

* revert to doubtfire local image for unit tests ([73fcbe3](https://github.com/macite/doubtfire-deploy/commit/73fcbe3f5adb603253033e7b126502a5d3c006f1))

## [8.0.0-5](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-4...v8.0.0-5) (2024-05-02)


### Bug Fixes

* correct updates in TII migration ([d1ab30b](https://github.com/macite/doubtfire-deploy/commit/d1ab30ba666898f556b69db53766124742b4f593))

## [8.0.0-4](https://github.com/macite/doubtfire-deploy/compare/v7.0.24...v8.0.0-4) (2024-05-01)


### Features

* add the pdf-reader gem for validating pdf submissions ([71c845b](https://github.com/macite/doubtfire-deploy/commit/71c845bf28fccf28de17ed83e3da1cf243646e7b))
* implement unit test for pdf validation on submit ([57db1dc](https://github.com/macite/doubtfire-deploy/commit/57db1dc57a75aaf211030ecf78b9252a5d8b583b))
* improve pdf file validation and detect encrypted pdfs ([dd729cf](https://github.com/macite/doubtfire-deploy/commit/dd729cf31bec115bd0e7018f33a692bd35bb5519))


### Bug Fixes

* add missing moss language in task def post ([1fa7b0b](https://github.com/macite/doubtfire-deploy/commit/1fa7b0b10f855bc2e23aa27e78ed41ff3e5b4683))
* add redis to the github actions workflow ([9935720](https://github.com/macite/doubtfire-deploy/commit/99357205d42d148f3a6165a96122691680409092))
* correct tii migrationm defaults ([2beb6e8](https://github.com/macite/doubtfire-deploy/commit/2beb6e8599cf6b99992e34548615e7802e7ff141))
* document two new env variables for redis ([749903f](https://github.com/macite/doubtfire-deploy/commit/749903f390a388fac2c2a8652975580611f1e072))
* implement error reporting in database populator ([136b9f9](https://github.com/macite/doubtfire-deploy/commit/136b9f98151688d3d6a578db1f980b39b3e21514))
* install ruby-lsp in the development environment ([c57290e](https://github.com/macite/doubtfire-deploy/commit/c57290e4b2f7ba1bab7d600965988489dc3dd5a4))
* pick up redis url from env for sidekiq if present ([e9628eb](https://github.com/macite/doubtfire-deploy/commit/e9628eb31398719d78508a610a251a785f56a14f))
* remove plagiarism checks field ([19107bf](https://github.com/macite/doubtfire-deploy/commit/19107bf87601115ea15036f25634b2ba30e23c7c))
* remove serialisation of plagiarism checks ([1962cc9](https://github.com/macite/doubtfire-deploy/commit/1962cc96ff46134d756984473d1022792e9ada1a))
* skip unit tests and linting for documentation updates ([2503fe6](https://github.com/macite/doubtfire-deploy/commit/2503fe61468f8ebe37e54ccb1d0cc2a11387949b))

## [8.0.0-3](https://github.com/macite/doubtfire-deploy/compare/v7.0.23...v8.0.0-3) (2024-03-22)


### Bug Fixes

* ensure redis is in dockerfile ([c37f5ba](https://github.com/macite/doubtfire-deploy/commit/c37f5ba0e78fbbb6fb1f7423f8b1bbabb557f761))
* revert new tii action field to text from json ([72a8f18](https://github.com/macite/doubtfire-deploy/commit/72a8f18c31a3b5476f4f7b414b54cf47e3db8087))

## [8.0.0-2](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-1...v8.0.0-2) (2024-03-22)


### Bug Fixes

* remove switch to json db format ([1b789a2](https://github.com/macite/doubtfire-deploy/commit/1b789a2194b745a6f91f8989c12c9387932ca70c))

## [8.0.0-1](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-0...v8.0.0-1) (2024-03-21)

## [8.0.0-0](https://github.com/macite/doubtfire-deploy/compare/v7.0.22...v8.0.0-0) (2024-03-21)


### Features

* add ability to adjust similarity flag ([339acf8](https://github.com/macite/doubtfire-deploy/commit/339acf8d741ff8d53b9cf1bb7a00e88907d8a183))
* add ability to fetch tii viewer url ([002bb07](https://github.com/macite/doubtfire-deploy/commit/002bb07972f9364eea74563af66efa8f783c2c2e))
* add api to interact with tii group attachments ([f286302](https://github.com/macite/doubtfire-deploy/commit/f2863020a3619f097c182c98b1392e5c05e7c7c0))
* add similarity report webhook ([07157f9](https://github.com/macite/doubtfire-deploy/commit/07157f9f0c6bbbc8d07b37807562b0ec00606c97))
* add submission tii hook ([3f1c8ca](https://github.com/macite/doubtfire-deploy/commit/3f1c8ca1e9ef25b010c7a9061b986ce514775a71))
* add tii submission to enable retry ([e38e884](https://github.com/macite/doubtfire-deploy/commit/e38e88423779a0d92cfe22eb96cc4e3d5ac07582))
* add upload tii group attachment ([aa10e35](https://github.com/macite/doubtfire-deploy/commit/aa10e35c45920ef0504dd9073a1c38470cae39da))
* allow score to 100 for tasks ([757d184](https://github.com/macite/doubtfire-deploy/commit/757d1845a48f5ec967b7094940b50e2bd4478ab4))
* asynchronously process submissions ([5a1ab9c](https://github.com/macite/doubtfire-deploy/commit/5a1ab9c051e054f7a30f6a1958c78f14b226d365))
* cache tii details in files ([ae2208c](https://github.com/macite/doubtfire-deploy/commit/ae2208c344c0959382e833557ccc69227e471da3))
* can fetch and retry tii actions ([81ee714](https://github.com/macite/doubtfire-deploy/commit/81ee714c7c0043502100758accc3d526ee3d73e9))
* check tii features ([21a0fcc](https://github.com/macite/doubtfire-deploy/commit/21a0fcc324f184e0de416fa7091f1e57ba33f329))
* delay generation for a short period to allow sidekiq to handle ([a53a998](https://github.com/macite/doubtfire-deploy/commit/a53a9980c56556b3e65321ac8e0ca455ea9f2ce6))
* ensure correct error when no token ([0aa8e71](https://github.com/macite/doubtfire-deploy/commit/0aa8e7130551a2f6e4c76302179a13aadb720344))
* ensure eula loads from file where possible ([aa4d7e8](https://github.com/macite/doubtfire-deploy/commit/aa4d7e86649f60cce5ebbbcb5f403b64e31315f9))
* ensure only high similarity for tii reported ([4c4e55a](https://github.com/macite/doubtfire-deploy/commit/4c4e55a9b8febc2d18954a4baf8de1d5993341de))
* ensure turn it in viewer only available when report ready ([124558f](https://github.com/macite/doubtfire-deploy/commit/124558f6c2c28d14e8fd47fb7e5ab0fac09425d0))
* move cache to redis to share across instances ([63ab5b2](https://github.com/macite/doubtfire-deploy/commit/63ab5b27a8b142209dd6bcf9aa148ada56a04a91))
* pdf report web hook ([355b375](https://github.com/macite/doubtfire-deploy/commit/355b37582b2d430d66c2aafc1cc545c049fd5d78))
* record max similarity percent and flag high tii submissions ([9f56be9](https://github.com/macite/doubtfire-deploy/commit/9f56be9a1fc562f0429ce73b7aab0ce4b7775c23))
* record overall match percent in tii submission ([f0bd981](https://github.com/macite/doubtfire-deploy/commit/f0bd981ffe6aa967093ed7ce992b37a81aa7a4e3))
* register turn it in webhooks ([b3fbc45](https://github.com/macite/doubtfire-deploy/commit/b3fbc45c759b34f7ab31bc251e1f441e3a0dbe36))
* report tii presence via settings api ([5354584](https://github.com/macite/doubtfire-deploy/commit/5354584db125c4186cf23643ad672fadab367f9d))
* report tii upload action status ([6dadc16](https://github.com/macite/doubtfire-deploy/commit/6dadc1630d5a88dbba69c3d05092a25d21653fd2))
* trigger tii group attachment on change ([4adee6b](https://github.com/macite/doubtfire-deploy/commit/4adee6bafa71b9a2db91970932a84a517bf72c2c))
* update group on due date change ([98187f1](https://github.com/macite/doubtfire-deploy/commit/98187f1b5c4a5751ddd2c051e93cfc9cdba6fbfd))


### Bug Fixes

* add description to tii actions ([039ca1a](https://github.com/macite/doubtfire-deploy/commit/039ca1a40f6ccfeb671de5f2400a58b71c210b5d))
* change load of tii eula and feature to use file cache ([d17c5d6](https://github.com/macite/doubtfire-deploy/commit/d17c5d6fa69a7916a19807fe645bdcb3b8c1f428))
* change tii batch upload to limit submission rate ([984524f](https://github.com/macite/doubtfire-deploy/commit/984524fbc3c04c04337137672554c25c8ea6c0de))
* correct latex packages for texlive 2024 ([1e52ea5](https://github.com/macite/doubtfire-deploy/commit/1e52ea5a01e514f29eabae6ee6de655dd527ed79))
* create missing portfolios ([259baa6](https://github.com/macite/doubtfire-deploy/commit/259baa6dd863122eccaec3d88d7fdfaaf1bb97e4))
* ensure endpoint can accept eula ([f8a69a7](https://github.com/macite/doubtfire-deploy/commit/f8a69a72bf9a8a425d4f0d63fa1f36112390ac8a))
* ensure file download returns something ([3439bab](https://github.com/macite/doubtfire-deploy/commit/3439babcd521155f1c78d76f71717c0645c23d95))
* ensure similarities without files work in ui ([bbbedb7](https://github.com/macite/doubtfire-deploy/commit/bbbedb7e2dfecf96c7a31e628e6f3824bdbb033d))
* ensure staff before tutorial data ([953068e](https://github.com/macite/doubtfire-deploy/commit/953068e219df6c3722a44389deca837d3cd47380))
* ensure tests work and address tii check list items ([3dc5cb1](https://github.com/macite/doubtfire-deploy/commit/3dc5cb1f37ee1707da8b3f42f39b1bd43b2e5f09))
* ensure tii initializer loads correctly ([0339ce5](https://github.com/macite/doubtfire-deploy/commit/0339ce5e1fa76e82bb82bf2b516f1ae990944e27))
* ensure we can get the report url for moss reports ([582d13a](https://github.com/macite/doubtfire-deploy/commit/582d13a292f56e7d6294fb636b1aeb4228b98426))
* ensure we do not ask to accept eula if not required ([3df2ade](https://github.com/macite/doubtfire-deploy/commit/3df2ade168970741b80413f396dbb6b312124cf0))
* ensure we send indexing and eula details in viewer and submissions ([38d4059](https://github.com/macite/doubtfire-deploy/commit/38d4059bf2f301896c27fea83d635b496c218a0a))
* eula link in upload action ([96e8bce](https://github.com/macite/doubtfire-deploy/commit/96e8bce8354026865a7792a62acc8898c7d18dee))
* get tii user details for viewer url ([c7de571](https://github.com/macite/doubtfire-deploy/commit/c7de57158aa630fe62f430c247ad277baba49e5a))
* no auth mirrors timeout ([b83f09c](https://github.com/macite/doubtfire-deploy/commit/b83f09c3b10f3d93216c34d1adb642d43c82476b))
* only admin can retry tii actions ([7e019cc](https://github.com/macite/doubtfire-deploy/commit/7e019cc34005d8de6b69f6c4475a79e4e2ceff37))
* remove debugging ([c6d067a](https://github.com/macite/doubtfire-deploy/commit/c6d067aed1dd6b283615a12706a7e9ed4c452052))
* remove max pct similar ([87bc428](https://github.com/macite/doubtfire-deploy/commit/87bc42888d28fe6911fd25281845e54ab290bd8f))
* rescue missing action in job ([ea84ac2](https://github.com/macite/doubtfire-deploy/commit/ea84ac21fbfbf72cb476458261f943e1a8ddbf4f))
* simulate signoff adds similarities ([74a74e0](https://github.com/macite/doubtfire-deploy/commit/74a74e07dc7a61d56472e19ca49787d8ec2890cb))
* update save status on actions ([096aee6](https://github.com/macite/doubtfire-deploy/commit/096aee685d2cf0652092b4f87a319de73e1dd1e9))
* update schema to match migration dates ([5c1afe4](https://github.com/macite/doubtfire-deploy/commit/5c1afe421dd41b8f56284e776ce39996b3f28d71))

## [8.0.0](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-11...v8.0.0) (2024-05-23)


### Bug Fixes

* correct typos in unit role needed for teaching role ([f808ad4](https://github.com/macite/doubtfire-deploy/commit/f808ad437f424f40a4eb68d5218ddf4317ba44b6))

## [8.0.0-11](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-10...v8.0.0-11) (2024-05-13)

## [8.0.0-10](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-9...v8.0.0-10) (2024-05-13)


### Bug Fixes

* host url for turn it in integration ([3cd67d7](https://github.com/macite/doubtfire-deploy/commit/3cd67d7c58916cda429d3c0266942cfc2c0ef878))

## [8.0.0-9](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-8...v8.0.0-9) (2024-05-11)


### Bug Fixes

* ensure default log in tii actions ([a9959fe](https://github.com/macite/doubtfire-deploy/commit/a9959fef2223ffca41338b15c973b888253225bf))
* ensure tii launch handles errors so rails can progress ([d7c9c3c](https://github.com/macite/doubtfire-deploy/commit/d7c9c3c8c60b49721aa9cac1f8df6ec716b82422))
* revert to default cache store ([c3a22bf](https://github.com/macite/doubtfire-deploy/commit/c3a22bfee6e9912fd8b4d331d6a6e6f350b72ffa))

## [8.0.0-8](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-7...v8.0.0-8) (2024-05-11)


### Bug Fixes

* adjust log and params in tii_actions ([4bfdfb1](https://github.com/macite/doubtfire-deploy/commit/4bfdfb1faf5bbaf45ec7827ec89e4cd231f88dba))
* update for dotenv 3 ([ef8611f](https://github.com/macite/doubtfire-deploy/commit/ef8611f917b198064a891f81c02408ff081e977b))

## [8.0.0-7](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-6...v8.0.0-7) (2024-05-02)

## [8.0.0-6](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-5...v8.0.0-6) (2024-05-02)


### Features

* add the pdf-reader gem for validating pdf submissions ([71c845b](https://github.com/macite/doubtfire-deploy/commit/71c845bf28fccf28de17ed83e3da1cf243646e7b))
* implement unit test for pdf validation on submit ([57db1dc](https://github.com/macite/doubtfire-deploy/commit/57db1dc57a75aaf211030ecf78b9252a5d8b583b))
* improve pdf file validation and detect encrypted pdfs ([dd729cf](https://github.com/macite/doubtfire-deploy/commit/dd729cf31bec115bd0e7018f33a692bd35bb5519))


### Bug Fixes

* add redis to the github actions workflow ([9935720](https://github.com/macite/doubtfire-deploy/commit/99357205d42d148f3a6165a96122691680409092))
* document two new env variables for redis ([749903f](https://github.com/macite/doubtfire-deploy/commit/749903f390a388fac2c2a8652975580611f1e072))
* implement error reporting in database populator ([136b9f9](https://github.com/macite/doubtfire-deploy/commit/136b9f98151688d3d6a578db1f980b39b3e21514))
* install ruby-lsp in the development environment ([c57290e](https://github.com/macite/doubtfire-deploy/commit/c57290e4b2f7ba1bab7d600965988489dc3dd5a4))
* pick up redis url from env for sidekiq if present ([e9628eb](https://github.com/macite/doubtfire-deploy/commit/e9628eb31398719d78508a610a251a785f56a14f))
* revert to doubtfire local image for unit tests ([73fcbe3](https://github.com/macite/doubtfire-deploy/commit/73fcbe3f5adb603253033e7b126502a5d3c006f1))
* skip unit tests and linting for documentation updates ([2503fe6](https://github.com/macite/doubtfire-deploy/commit/2503fe61468f8ebe37e54ccb1d0cc2a11387949b))

## [8.0.0-5](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-4...v8.0.0-5) (2024-05-02)


### Bug Fixes

* correct updates in TII migration ([d1ab30b](https://github.com/macite/doubtfire-deploy/commit/d1ab30ba666898f556b69db53766124742b4f593))

## [8.0.0-4](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-3...v8.0.0-4) (2024-05-01)


### Bug Fixes

* add missing moss language in task def post ([1fa7b0b](https://github.com/macite/doubtfire-deploy/commit/1fa7b0b10f855bc2e23aa27e78ed41ff3e5b4683))
* correct tii migrationm defaults ([2beb6e8](https://github.com/macite/doubtfire-deploy/commit/2beb6e8599cf6b99992e34548615e7802e7ff141))
* remove plagiarism checks field ([19107bf](https://github.com/macite/doubtfire-deploy/commit/19107bf87601115ea15036f25634b2ba30e23c7c))
* remove serialisation of plagiarism checks ([1962cc9](https://github.com/macite/doubtfire-deploy/commit/1962cc96ff46134d756984473d1022792e9ada1a))

## [8.0.0-3](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-2...v8.0.0-3) (2024-03-22)

### Bug Fixes

* ensure redis is in dockerfile ([c37f5ba](https://github.com/macite/doubtfire-deploy/commit/c37f5ba0e78fbbb6fb1f7423f8b1bbabb557f761))
* revert new tii action field to text from json ([72a8f18](https://github.com/macite/doubtfire-deploy/commit/72a8f18c31a3b5476f4f7b414b54cf47e3db8087))

## [8.0.0-2](https://github.com/doubtfire-lms/doubtfire-deploy/compare/v8.0.0-1...v8.0.0-2) (2024-03-22)


### Bug Fixes

* remove switch to json db format ([1b789a2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1b789a2194b745a6f91f8989c12c9387932ca70c))

## [8.0.0-1](https://github.com/macite/doubtfire-deploy/compare/v8.0.0-0...v8.0.0-1) (2024-03-21)

## [8.0.0-0](https://github.com/macite/doubtfire-deploy/compare/v7.0.22...v8.0.0-0) (2024-03-21)


### Features

* add ability to adjust similarity flag ([339acf8](https://github.com/macite/doubtfire-deploy/commit/339acf8d741ff8d53b9cf1bb7a00e88907d8a183))
* add ability to fetch tii viewer url ([002bb07](https://github.com/macite/doubtfire-deploy/commit/002bb07972f9364eea74563af66efa8f783c2c2e))
* add api to interact with tii group attachments ([f286302](https://github.com/macite/doubtfire-deploy/commit/f2863020a3619f097c182c98b1392e5c05e7c7c0))
* add similarity report webhook ([07157f9](https://github.com/macite/doubtfire-deploy/commit/07157f9f0c6bbbc8d07b37807562b0ec00606c97))
* add submission tii hook ([3f1c8ca](https://github.com/macite/doubtfire-deploy/commit/3f1c8ca1e9ef25b010c7a9061b986ce514775a71))
* add tii submission to enable retry ([e38e884](https://github.com/macite/doubtfire-deploy/commit/e38e88423779a0d92cfe22eb96cc4e3d5ac07582))
* add upload tii group attachment ([aa10e35](https://github.com/macite/doubtfire-deploy/commit/aa10e35c45920ef0504dd9073a1c38470cae39da))
* allow score to 100 for tasks ([757d184](https://github.com/macite/doubtfire-deploy/commit/757d1845a48f5ec967b7094940b50e2bd4478ab4))
* asynchronously process submissions ([5a1ab9c](https://github.com/macite/doubtfire-deploy/commit/5a1ab9c051e054f7a30f6a1958c78f14b226d365))
* cache tii details in files ([ae2208c](https://github.com/macite/doubtfire-deploy/commit/ae2208c344c0959382e833557ccc69227e471da3))
* can fetch and retry tii actions ([81ee714](https://github.com/macite/doubtfire-deploy/commit/81ee714c7c0043502100758accc3d526ee3d73e9))
* check tii features ([21a0fcc](https://github.com/macite/doubtfire-deploy/commit/21a0fcc324f184e0de416fa7091f1e57ba33f329))
* delay generation for a short period to allow sidekiq to handle ([a53a998](https://github.com/macite/doubtfire-deploy/commit/a53a9980c56556b3e65321ac8e0ca455ea9f2ce6))
* ensure correct error when no token ([0aa8e71](https://github.com/macite/doubtfire-deploy/commit/0aa8e7130551a2f6e4c76302179a13aadb720344))
* ensure eula loads from file where possible ([aa4d7e8](https://github.com/macite/doubtfire-deploy/commit/aa4d7e86649f60cce5ebbbcb5f403b64e31315f9))
* ensure only high similarity for tii reported ([4c4e55a](https://github.com/macite/doubtfire-deploy/commit/4c4e55a9b8febc2d18954a4baf8de1d5993341de))
* ensure turn it in viewer only available when report ready ([124558f](https://github.com/macite/doubtfire-deploy/commit/124558f6c2c28d14e8fd47fb7e5ab0fac09425d0))
* move cache to redis to share across instances ([63ab5b2](https://github.com/macite/doubtfire-deploy/commit/63ab5b27a8b142209dd6bcf9aa148ada56a04a91))
* pdf report web hook ([355b375](https://github.com/macite/doubtfire-deploy/commit/355b37582b2d430d66c2aafc1cc545c049fd5d78))
* record max similarity percent and flag high tii submissions ([9f56be9](https://github.com/macite/doubtfire-deploy/commit/9f56be9a1fc562f0429ce73b7aab0ce4b7775c23))
* record overall match percent in tii submission ([f0bd981](https://github.com/macite/doubtfire-deploy/commit/f0bd981ffe6aa967093ed7ce992b37a81aa7a4e3))
* register turn it in webhooks ([b3fbc45](https://github.com/macite/doubtfire-deploy/commit/b3fbc45c759b34f7ab31bc251e1f441e3a0dbe36))
* report tii presence via settings api ([5354584](https://github.com/macite/doubtfire-deploy/commit/5354584db125c4186cf23643ad672fadab367f9d))
* report tii upload action status ([6dadc16](https://github.com/macite/doubtfire-deploy/commit/6dadc1630d5a88dbba69c3d05092a25d21653fd2))
* trigger tii group attachment on change ([4adee6b](https://github.com/macite/doubtfire-deploy/commit/4adee6bafa71b9a2db91970932a84a517bf72c2c))
* update group on due date change ([98187f1](https://github.com/macite/doubtfire-deploy/commit/98187f1b5c4a5751ddd2c051e93cfc9cdba6fbfd))


### Bug Fixes

* add description to tii actions ([039ca1a](https://github.com/macite/doubtfire-deploy/commit/039ca1a40f6ccfeb671de5f2400a58b71c210b5d))
* change load of tii eula and feature to use file cache ([d17c5d6](https://github.com/macite/doubtfire-deploy/commit/d17c5d6fa69a7916a19807fe645bdcb3b8c1f428))
* change tii batch upload to limit submission rate ([984524f](https://github.com/macite/doubtfire-deploy/commit/984524fbc3c04c04337137672554c25c8ea6c0de))
* correct latex packages for texlive 2024 ([1e52ea5](https://github.com/macite/doubtfire-deploy/commit/1e52ea5a01e514f29eabae6ee6de655dd527ed79))
* create missing portfolios ([259baa6](https://github.com/macite/doubtfire-deploy/commit/259baa6dd863122eccaec3d88d7fdfaaf1bb97e4))
* deakin username change for student id ([1445ddf](https://github.com/macite/doubtfire-deploy/commit/1445ddfa26fc207609f40f84e8f8f92145e0e8cc))
* ensure endpoint can accept eula ([f8a69a7](https://github.com/macite/doubtfire-deploy/commit/f8a69a72bf9a8a425d4f0d63fa1f36112390ac8a))
* ensure file download returns something ([3439bab](https://github.com/macite/doubtfire-deploy/commit/3439babcd521155f1c78d76f71717c0645c23d95))
* ensure similarities without files work in ui ([bbbedb7](https://github.com/macite/doubtfire-deploy/commit/bbbedb7e2dfecf96c7a31e628e6f3824bdbb033d))
* ensure staff before tutorial data ([953068e](https://github.com/macite/doubtfire-deploy/commit/953068e219df6c3722a44389deca837d3cd47380))
* ensure tests work and address tii check list items ([3dc5cb1](https://github.com/macite/doubtfire-deploy/commit/3dc5cb1f37ee1707da8b3f42f39b1bd43b2e5f09))
* ensure tii initializer loads correctly ([0339ce5](https://github.com/macite/doubtfire-deploy/commit/0339ce5e1fa76e82bb82bf2b516f1ae990944e27))
* ensure we can get the report url for moss reports ([582d13a](https://github.com/macite/doubtfire-deploy/commit/582d13a292f56e7d6294fb636b1aeb4228b98426))
* ensure we do not ask to accept eula if not required ([3df2ade](https://github.com/macite/doubtfire-deploy/commit/3df2ade168970741b80413f396dbb6b312124cf0))
* ensure we send indexing and eula details in viewer and submissions ([38d4059](https://github.com/macite/doubtfire-deploy/commit/38d4059bf2f301896c27fea83d635b496c218a0a))
* eula link in upload action ([96e8bce](https://github.com/macite/doubtfire-deploy/commit/96e8bce8354026865a7792a62acc8898c7d18dee))
* get tii user details for viewer url ([c7de571](https://github.com/macite/doubtfire-deploy/commit/c7de57158aa630fe62f430c247ad277baba49e5a))
* no auth mirrors timeout ([b83f09c](https://github.com/macite/doubtfire-deploy/commit/b83f09c3b10f3d93216c34d1adb642d43c82476b))
* only admin can retry tii actions ([7e019cc](https://github.com/macite/doubtfire-deploy/commit/7e019cc34005d8de6b69f6c4475a79e4e2ceff37))
* remove debugging ([c6d067a](https://github.com/macite/doubtfire-deploy/commit/c6d067aed1dd6b283615a12706a7e9ed4c452052))
* remove max pct similar ([87bc428](https://github.com/macite/doubtfire-deploy/commit/87bc42888d28fe6911fd25281845e54ab290bd8f))
* rescue missing action in job ([ea84ac2](https://github.com/macite/doubtfire-deploy/commit/ea84ac21fbfbf72cb476458261f943e1a8ddbf4f))
* simulate signoff adds similarities ([74a74e0](https://github.com/macite/doubtfire-deploy/commit/74a74e07dc7a61d56472e19ca49787d8ec2890cb))
* update save status on actions ([096aee6](https://github.com/macite/doubtfire-deploy/commit/096aee685d2cf0652092b4f87a319de73e1dd1e9))
* update schema to match migration dates ([5c1afe4](https://github.com/macite/doubtfire-deploy/commit/5c1afe421dd41b8f56284e776ce39996b3f28d71))

### [7.0.26](https://github.com/doubtfire-lms/doubtfire-deploy/compare/v7.0.25...v7.0.26) (2024-05-21)

### [7.0.25](https://github.com/doubtfire-lms/doubtfire-deploy/compare/v7.0.24...v7.0.25) (2024-05-20)


### Bug Fixes

* ensure portfolio tasks more likely to work with long files ([e9d6641](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e9d66411690482f446dfdb1d53d705435eb22aea))
* skip unit tests and linting for documentation updates ([399d109](https://github.com/doubtfire-lms/doubtfire-deploy/commit/399d1098aef2788545a22c1d3e768b0fe61a74cf))

### [7.0.24](https://github.com/doubtfire-lms/doubtfire-deploy/compare/v7.0.23...v7.0.24) (2024-03-26)


### Bug Fixes

* ensure that tagpdf is installed in latex ([d1f2197](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d1f2197e882038ef095b98a4558644e0c4c4bd33))

### [7.0.23](https://github.com/macite/doubtfire-deploy/compare/v7.0.22...v7.0.23) (2024-03-22)


### Bug Fixes

* deakin username change for student id ([1445ddf](https://github.com/macite/doubtfire-deploy/commit/1445ddfa26fc207609f40f84e8f8f92145e0e8cc))

### [7.0.22](https://github.com/macite/doubtfire-deploy/compare/v7.0.21...v7.0.22) (2023-12-01)


### Bug Fixes

* change_task_comment_fail ([a86d1b0](https://github.com/macite/doubtfire-deploy/commit/a86d1b03cfa3db70007785182258c146bc91bc47))

### [7.0.21](https://github.com/macite/doubtfire-deploy/compare/v7.0.20...v7.0.21) (2023-09-04)


### Features

* allow admin bind in ldap ([de66236](https://github.com/macite/doubtfire-deploy/commit/de662367d8cb3a291cc00424e25ccf1a6d6587ac))

### [7.0.20](https://github.com/macite/doubtfire-deploy/compare/v7.0.19...v7.0.20) (2023-08-29)


### Bug Fixes

* add processing for raw cells in ipynb ([ebacf38](https://github.com/macite/doubtfire-deploy/commit/ebacf3867aa09dbfad1a9eaa88953cbb418644f8))
* auto generate rake task ([3bd9107](https://github.com/macite/doubtfire-deploy/commit/3bd91079764ad153f299e2519e7ddbba9377fc8e))
* ensure devise is setup for ldap auth ([2561a05](https://github.com/macite/doubtfire-deploy/commit/2561a05649b0a3b34420fc2104b0c0b6be1a2fca))

### [7.0.19](https://github.com/macite/doubtfire-deploy/compare/v7.0.18...v7.0.19) (2023-06-20)


### Bug Fixes

* auto gen portfolio checks stats and refactor ([92ba764](https://github.com/macite/doubtfire-deploy/commit/92ba764d0f2a6527582042d6181d2a166b1582da))
* ensure campus valid on import ([5ef73ba](https://github.com/macite/doubtfire-deploy/commit/5ef73baa752bc95330b21bc232d234ee8f59b0d0))
* ensure unit dates can be edited independently ([2a3d3c1](https://github.com/macite/doubtfire-deploy/commit/2a3d3c193df12ac7f17e86b3ad2d16af27264fae))
* rollover with portfolio creation date ([2b1352f](https://github.com/macite/doubtfire-deploy/commit/2b1352f25554d79b6feb74159fec0763d15310ca))

### [7.0.18](https://github.com/macite/doubtfire-deploy/compare/v7.0.17...v7.0.18) (2023-06-18)

### [7.0.17](https://github.com/macite/doubtfire-deploy/compare/v7.0.16...v7.0.17) (2023-06-17)


### Bug Fixes

* ensure unit creation can set convenor ([b6d85ef](https://github.com/macite/doubtfire-deploy/commit/b6d85efa79e3545096d74d8503b0fb95af8232f8))

### [7.0.16](https://github.com/macite/doubtfire-deploy/compare/v7.0.15...v7.0.16) (2023-06-03)


### Bug Fixes

* ensure page count work on pdfs with errors ([57b01b3](https://github.com/macite/doubtfire-deploy/commit/57b01b37da246173fb0eccda77c9698692807b60))
* exclude pax on retry of portfolio creation ([bc75712](https://github.com/macite/doubtfire-deploy/commit/bc7571223928531bd252bc5cb7be9f4827aa64e2))
* portfolio creation in resouce contention test ([5cdb1e2](https://github.com/macite/doubtfire-deploy/commit/5cdb1e2b1031614c9a02e11d24e05546e988ba70))

### [7.0.15](https://github.com/macite/doubtfire-deploy/compare/v7.0.14...v7.0.15) (2023-06-03)


### Features

* add script to generate missing portfolios ([375975f](https://github.com/macite/doubtfire-deploy/commit/375975f46d7ebb8d29c6a62b01cc3e90820e4b04))


### Bug Fixes

* compress pdf file exists ([8091965](https://github.com/macite/doubtfire-deploy/commit/80919655415890a260c4e95060d20a8dcc686d77))
* create missing portfolios ([85b965f](https://github.com/macite/doubtfire-deploy/commit/85b965ffd3941aeaf8650ce19098a7b2f5e9649f))

### [7.0.14](https://github.com/macite/doubtfire-deploy/compare/v7.0.13...v7.0.14) (2023-06-01)


### Bug Fixes

* use qpdf for page count ([220e897](https://github.com/macite/doubtfire-deploy/commit/220e897a3d1144ef97e63b2292f011cfb126a01b))

### [7.0.12](https://github.com/macite/doubtfire-deploy/compare/v7.0.11...v7.0.12) (2023-06-01)


### Bug Fixes

* improve handling of pdf pages ([a79dc81](https://github.com/macite/doubtfire-deploy/commit/a79dc81865737658985bd045585623245d806459))
* switch pdf compression to qpdf ([30a401f](https://github.com/macite/doubtfire-deploy/commit/30a401f649444e6d873612aa55919a7e7a173471))
* use qpdf for page count ([220e897](https://github.com/macite/doubtfire-deploy/commit/220e897a3d1144ef97e63b2292f011cfb126a01b))

### [7.0.13](https://github.com/macite/doubtfire-deploy/compare/v7.0.12...v7.0.13) (2023-05-31)


### Bug Fixes

* switch pdf compression to qpdf ([30a401f](https://github.com/macite/doubtfire-deploy/commit/30a401f649444e6d873612aa55919a7e7a173471))

### [7.0.12](https://github.com/macite/doubtfire-deploy/compare/v7.0.11...v7.0.12) (2023-05-30)


### Bug Fixes

* improve handling of pdf pages ([a79dc81](https://github.com/macite/doubtfire-deploy/commit/a79dc81865737658985bd045585623245d806459))

### [7.0.11](https://github.com/macite/doubtfire-deploy/compare/v7.0.10...v7.0.11) (2023-05-24)


### Bug Fixes

* portfolio creation with additional code files ([e1e4da2](https://github.com/macite/doubtfire-deploy/commit/e1e4da259fd9b8fa845c9e8781989592ed082efe))

### [7.0.10](https://github.com/macite/doubtfire-deploy/compare/v7.0.9...v7.0.10) (2023-05-05)


### Features

* ensure task explorer gets extensions ([f72b378](https://github.com/macite/doubtfire-deploy/commit/f72b378c3326c392c33af2dd44a991137e57be3c))


### Bug Fixes

* ensure extension checks allow audio upload ([dc33fc7](https://github.com/macite/doubtfire-deploy/commit/dc33fc7b7022395c1a69d7a23362f5ebfe11a1b6))
* exclude tasks from withdrawn units in webcal feed ([bcd29fb](https://github.com/macite/doubtfire-deploy/commit/bcd29fba2623136456c11e0dbff7ea61544eb08c))

### [7.0.9](https://github.com/macite/doubtfire-deploy/compare/v7.0.8...v7.0.9) (2023-04-04)


### Features

* ensure campus changes can be synced ([5f02f5b](https://github.com/macite/doubtfire-deploy/commit/5f02f5bc36c97e61d68d5e67bed27822df290d8e))


### Bug Fixes

* ensure markdown works with invalid latex ([58965dd](https://github.com/macite/doubtfire-deploy/commit/58965dd799d1a073ddb59c76d1a9af2edfe871db))

### [7.0.8](https://github.com/macite/doubtfire-deploy/compare/v7.0.7...v7.0.8) (2023-03-23)


### Features

* skip newpax on pdf generation fail retry ([d463b0d](https://github.com/macite/doubtfire-deploy/commit/d463b0dcb672be953f7072abd796d9c723071bdb))
* support documents of different size ([d4e1c59](https://github.com/macite/doubtfire-deploy/commit/d4e1c59ef443514eed7697a101dcedba24d20b4b))

### [7.0.7](https://github.com/macite/doubtfire-deploy/compare/v7.0.6...v7.0.7) (2023-03-22)


### Features

* add registry for docker pull of images ([8b00a2b](https://github.com/macite/doubtfire-deploy/commit/8b00a2bf95ec4577b082749a333f1573e502973f))

### [7.0.6](https://github.com/macite/doubtfire-deploy/compare/v7.0.5...v7.0.6) (2023-03-21)

### [7.0.5](https://github.com/macite/doubtfire-deploy/compare/v7.0.4...v7.0.5) (2023-03-21)


### Features

* add support for csv code file upload ([561beb3](https://github.com/macite/doubtfire-deploy/commit/561beb3c7de28a56710f2748f84f8176c8bf9609))
* handle markdown in ipynb ([358f646](https://github.com/macite/doubtfire-deploy/commit/358f64629097507bde923abda3fe552576eeaaa9))

### [7.0.4](https://github.com/macite/doubtfire-deploy/compare/v7.0.3...v7.0.4) (2023-03-20)


### Features

* pull overseer docker image ([f9efef7](https://github.com/macite/doubtfire-deploy/commit/f9efef716a613eb928cebd30aa80c61fd65a12a2))


### Bug Fixes

* ensure teaching period can be removed ([e7dfaaa](https://github.com/macite/doubtfire-deploy/commit/e7dfaaa7d7df4e2191c9e7df071cc7f7807c17e7))
* log info for docker login ([80ac4de](https://github.com/macite/doubtfire-deploy/commit/80ac4ded27f142451e8379511a87f2457cdbd58a))

### [7.0.3](https://github.com/macite/doubtfire-deploy/compare/v7.0.2...v7.0.3) (2023-03-10)


### Bug Fixes

* ensure we can handle long ipynb output ([97e18d5](https://github.com/macite/doubtfire-deploy/commit/97e18d54962f863e830aa13302ade47c026e00d6))

### [7.0.2](https://github.com/macite/doubtfire-deploy/compare/v7.0.1...v7.0.2) (2023-03-03)

### [7.0.1](https://github.com/macite/doubtfire-deploy/compare/v7.0.0...v7.0.1) (2023-03-03)


### Bug Fixes

* correct issue logging in with SSL ([1886b1d](https://github.com/macite/doubtfire-deploy/commit/1886b1d923199115996f7ecb0c3fc161a55799ac))
* correct issue with deleting groups errors ([61e8e30](https://github.com/macite/doubtfire-deploy/commit/61e8e30109e5a2615261375531d5138774658357))

## [7.0.0](https://github.com/macite/doubtfire-deploy/compare/v6.0.18...v7.0.0) (2023-02-23)


### Features

* ensure rollover returns new unit details ([3f956ba](https://github.com/macite/doubtfire-deploy/commit/3f956ba6a68e71d8ead6c27a7ee34f78faf1f9b9))


### Bug Fixes

* align project create with new entity data ([1d9443a](https://github.com/macite/doubtfire-deploy/commit/1d9443a20b8c0147097f98fcc3e4a3f8c9112134))
* campus is optional on tutorial create ([f58b1ee](https://github.com/macite/doubtfire-deploy/commit/f58b1eeb0e18bc2df71dd9e38bc04f00e98e8a53))
* changes in unit entity staff check ([dbe6ba8](https://github.com/macite/doubtfire-deploy/commit/dbe6ba80464d97ca40207fa5f60b95ff6d32f01d))
* correct links to portfolios in emails ([9ecd555](https://github.com/macite/doubtfire-deploy/commit/9ecd5555675c6ffebf639768587ffbdcccf2d28f))
* csv import of task definitions ([56927ab](https://github.com/macite/doubtfire-deploy/commit/56927abc258df08432f5fc810355f8778a5c7c3b))
* ensure creating of new units works ([7fa790f](https://github.com/macite/doubtfire-deploy/commit/7fa790f04e71d278484a6b1ea5710839468e73a4))
* ensure group imports use presenter ([a4df066](https://github.com/macite/doubtfire-deploy/commit/a4df06630e8c87007c14bbfee9e7b238670443f6))
* ensure latex works on arm ([ae71686](https://github.com/macite/doubtfire-deploy/commit/ae71686165df4af2ce0813118d9113bc882c856f))
* ensure missing parameters responds with error ([c7ba812](https://github.com/macite/doubtfire-deploy/commit/c7ba812693b229cc7899f1a952315ad0050444e3))
* ensure project updates work for staff and students ([e47a001](https://github.com/macite/doubtfire-deploy/commit/e47a001ba245daa1cee9924b39446a9c6ff87f26))
* ensure ulo class stats works ([e0be10b](https://github.com/macite/doubtfire-deploy/commit/e0be10b46258f0408993a3cb597a43648373537c))
* lambda syntax issue ([6f9a3dd](https://github.com/macite/doubtfire-deploy/commit/6f9a3dde451fbf74f0d2fae8496008c31b068a46))
* report error on invalid role change ([8400c38](https://github.com/macite/doubtfire-deploy/commit/8400c382139b7e89fbc1f1d3cc0e7a87efc7b434))
* return student username and id ([ab94b40](https://github.com/macite/doubtfire-deploy/commit/ab94b405dce65b70645d7f45c02895283c5b52c9))
* switch cloud to online for Deakin integration ([f6dacfb](https://github.com/macite/doubtfire-deploy/commit/f6dacfbb7257bbcebfdd6de3c3197835c824d6f2))

### [6.0.18](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.17...v6.0.18) (2022-10-04)


### Bug Fixes

* ensure portfolio PDFs are compressed ([49dbc36](https://github.com/doubtfire-lms/doubtfire-api/commit/49dbc366fec3b7c30c00f992bec06245c55e2115))

### [6.0.17](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.16...v6.0.17) (2022-09-29)


### Bug Fixes

* add term setting to pdf generation to quiet log ([0f4812f](https://github.com/doubtfire-lms/doubtfire-api/commit/0f4812f7108c632fa03a74c85b23b38f8548762a))

### [6.0.16](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.15...v6.0.16) (2022-09-29)


### Bug Fixes

* remove downstream newpax patch and add version check ([7447c55](https://github.com/doubtfire-lms/doubtfire-api/commit/7447c558d16ea6ca0fcb0b61b5a554ac04c65d3b))

### [6.0.15](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.14...v6.0.15) (2022-09-10)


### Bug Fixes

* hard-code date in newpax to avoid nil dates ([b0b3db6](https://github.com/doubtfire-lms/doubtfire-api/commit/b0b3db6ee1405620afd884f8f404e42cb05b33f2))

### [6.0.14](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.13...v6.0.14) (2022-09-05)

### [6.0.13](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.12...v6.0.13) (2022-09-01)


### Features

* add portfolio autogeneration to crontab ([036d763](https://github.com/doubtfire-lms/doubtfire-api/commit/036d763e5679a4fb55a844e5888272780cf76dc9))
* only grant extensions on positive feedback responses ([17d5a98](https://github.com/doubtfire-lms/doubtfire-api/commit/17d5a9840366d7546d7e6e2a77cf835f2219d1c3))


### Bug Fixes

* address potential csrf vuln ([c5f065a](https://github.com/doubtfire-lms/doubtfire-api/commit/c5f065a02abb605d90ba1577ede383e9734537f8))
* correct the bad tag in email template for the "due soon" ul ([697b7fd](https://github.com/doubtfire-lms/doubtfire-api/commit/697b7fdc03b2f1c647bc412a7dcc682a558b7120))
* ignore locally installed gems ([90cfc9c](https://github.com/doubtfire-lms/doubtfire-api/commit/90cfc9c7d6fdf00d900cd799c72b38aa2f0a5666))
* install and use newpax to preserve links in generated PDFs ([8e65a71](https://github.com/doubtfire-lms/doubtfire-api/commit/8e65a714b63ada5ef69c0d87c05d6c761f68d8f6))
* remove duplicate auto generate call in crontab ([93409dc](https://github.com/doubtfire-lms/doubtfire-api/commit/93409dc54e294005e0e215ddd88345b250e88b04))

### [6.0.12](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.11...v6.0.12) (2022-06-03)


### Bug Fixes

* reinstate recipe but fix parse runs issue ([f5afbfe](https://github.com/doubtfire-lms/doubtfire-api/commit/f5afbfe7fe6ebe663f222922d05ba9e54cb3c4c7))

### [6.0.11](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.10...v6.0.11) (2022-06-02)


### Bug Fixes

* only send overseer image id to admin staff ([6201b64](https://github.com/doubtfire-lms/doubtfire-api/commit/6201b6427aa88b5435eafa0085fa2eacb078911c))
* pdf creation latex settings ([4b9e340](https://github.com/doubtfire-lms/doubtfire-api/commit/4b9e3406d5582f0baecf3922481a39542f03d3f5))
* remove defaults from unit update optional parameters ([7eb7f1c](https://github.com/doubtfire-lms/doubtfire-api/commit/7eb7f1cf5925c2a2a60aabb93984aaa03aca4412))
* webcal task selection and api format ([a55f57e](https://github.com/doubtfire-lms/doubtfire-api/commit/a55f57e22599002a46d90547e8be3f37a0ccf9a6))

### [6.0.10](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.9...v6.0.10) (2022-05-25)


### Bug Fixes

* update moss ruby to read similarity reports ([9500bd4](https://github.com/doubtfire-lms/doubtfire-api/commit/9500bd4696218db335ad8f48f980e010d67bfca4))

### [6.0.9](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.8...v6.0.9) (2022-03-27)


### Bug Fixes

* remove pct check for group submission ([e23aec5](https://github.com/doubtfire-lms/doubtfire-api/commit/e23aec565e0a965c7146cade9a9ca46b031024ad))

### [6.0.8](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.7...v6.0.8) (2022-03-22)


### Bug Fixes

* ensure validation works correctly for tutorial enrolments with restricted groups ([abf9d53](https://github.com/doubtfire-lms/doubtfire-api/commit/abf9d5313dee0780b9e653b3c180e501bf6c8ca2))

### [6.0.7](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.6...v6.0.7) (2022-03-17)


### Bug Fixes

* ensure cron tasks are reported via email ([20d6ec0](https://github.com/doubtfire-lms/doubtfire-api/commit/20d6ec0f0b99d308e3f1c9371a8f713174a8ed40))
* ensure sample compose contains institution settings ([0f0185d](https://github.com/doubtfire-lms/doubtfire-api/commit/0f0185dc0111da2056e9e7689d051c0d0b1c09e3))
* ensure task stats uses float division ([fc75222](https://github.com/doubtfire-lms/doubtfire-api/commit/fc75222d928e6e9e868c7e520ea9d9ee5251cfc8))
* ensure TaskStatus.count uses sql where needed ([383a904](https://github.com/doubtfire-lms/doubtfire-api/commit/383a9047aa8ce849a302ce40ecadd7848df42b49))
* ensure there is access to task status count from database ([976ec0a](https://github.com/doubtfire-lms/doubtfire-api/commit/976ec0ad2c2e7dff63d65baf45ddc1f342aa7249))
* post project uses default task stats ([9ba5a50](https://github.com/doubtfire-lms/doubtfire-api/commit/9ba5a5069f5c8b8d30e27156dbc0b4914c9fc413))
* stop empty nicknames from rendering in student_name ([#364](https://github.com/doubtfire-lms/doubtfire-api/issues/364)) ([b1a6035](https://github.com/doubtfire-lms/doubtfire-api/commit/b1a60356549f14aeb6432c9aec15e0f033732dd8))

### [6.0.7](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.6...v6.0.7) (2022-03-17)


### Bug Fixes

* ensure cron tasks are reported via email ([20d6ec0](https://github.com/doubtfire-lms/doubtfire-api/commit/20d6ec0f0b99d308e3f1c9371a8f713174a8ed40))
* ensure sample compose contains institution settings ([0f0185d](https://github.com/doubtfire-lms/doubtfire-api/commit/0f0185dc0111da2056e9e7689d051c0d0b1c09e3))
* ensure TaskStatus.count uses sql where needed ([383a904](https://github.com/doubtfire-lms/doubtfire-api/commit/383a9047aa8ce849a302ce40ecadd7848df42b49))
* ensure there is access to task status count from database ([976ec0a](https://github.com/doubtfire-lms/doubtfire-api/commit/976ec0ad2c2e7dff63d65baf45ddc1f342aa7249))
* post project uses default task stats ([9ba5a50](https://github.com/doubtfire-lms/doubtfire-api/commit/9ba5a5069f5c8b8d30e27156dbc0b4914c9fc413))
* stop empty nicknames from rendering in student_name ([#364](https://github.com/doubtfire-lms/doubtfire-api/issues/364)) ([b1a6035](https://github.com/doubtfire-lms/doubtfire-api/commit/b1a60356549f14aeb6432c9aec15e0f033732dd8))

### [6.0.6](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.5...v6.0.6) (2022-03-03)


### Bug Fixes

* ensure content disposition is accessible on file download ([0f38961](https://github.com/doubtfire-lms/doubtfire-api/commit/0f389611ae24fc4bea181ab807974d67b1b26264))

### [6.0.5](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.4...v6.0.5) (2022-03-03)


### Bug Fixes

* align param and field names in stream put ([919fd60](https://github.com/doubtfire-lms/doubtfire-api/commit/919fd605e148ad11a26d7c3fce5f020032d19b2e))

### [6.0.4](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.3...v6.0.4) (2022-02-28)


### Bug Fixes

* revert to using serialize with task comments ([371688c](https://github.com/doubtfire-lms/doubtfire-api/commit/371688c18a6914fe3fba2ac8cf9b02a7417cc462))

### [6.0.3](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.2...v6.0.3) (2022-02-25)


### Bug Fixes

* ensure enrolments sync script is executable ([23714d0](https://github.com/doubtfire-lms/doubtfire-api/commit/23714d0c339082eb02b8f4e9a2759e162c4766f0))

### [6.0.2](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.1...v6.0.2) (2022-02-23)


### Bug Fixes

* ensure students can withdraw from tutorials ([0dcab00](https://github.com/doubtfire-lms/doubtfire-api/commit/0dcab0039b5d93509a619058a112f05a615563d8))

### [6.0.1](https://github.com/doubtfire-lms/doubtfire-api/compare/v6.0.0...v6.0.1) (2022-02-17)

## [6.0.0](https://github.com/doubtfire-lms/doubtfire-api/compare/v5.0.7...v6.0.0) (2022-02-02)


### Features

* add script to sync enrolments ([e932725](https://github.com/doubtfire-lms/doubtfire-api/commit/e932725ca41aac68998a00a69e9e45a993fa6c48))
* add sprockets to development to host swagger ([b928f78](https://github.com/doubtfire-lms/doubtfire-api/commit/b928f78669348f7ca0ce94ecc881f2cad6eefcd2))
* adjust dockerfile to work without code volume ([54c8d6b](https://github.com/doubtfire-lms/doubtfire-api/commit/54c8d6bacfee0233c379961d357fec715bd4dee7))
* allow configuration to turn off mail sending ([ed8b3af](https://github.com/doubtfire-lms/doubtfire-api/commit/ed8b3af4805a6c6f13d9cd049e1afc370dcf6e1a))
* enhance error reporting from overseer ([b79e4ce](https://github.com/doubtfire-lms/doubtfire-api/commit/b79e4ceadcc3a733cb6d809ec73288a1f8866e93))
* enhance rails logging ([77f76b2](https://github.com/doubtfire-lms/doubtfire-api/commit/77f76b25b633e6d5c421e3ee3f2c8d21ffb1e638))
* move task dates when unit start date changes ([958a263](https://github.com/doubtfire-lms/doubtfire-api/commit/958a263eaaf8fddb55ae0b208d6ea3f4f268445b))
* report errors when attempting to add student as tutor ([7d8571a](https://github.com/doubtfire-lms/doubtfire-api/commit/7d8571a4f1ef951342899afcd6bf8b9b12f67fa2))
* update to rails 7 and rails encrypted attributes ([c99ec09](https://github.com/doubtfire-lms/doubtfire-api/commit/c99ec0942ce006361d4d4acfc93a587e584c3f66))


### Bug Fixes

* Access serialised object now uses object.object ([00e532b](https://github.com/doubtfire-lms/doubtfire-api/commit/00e532b4393d78fa0e407396a52d8488eb96a87d))
* Add content disposition to evidence download ([b47b9ab](https://github.com/doubtfire-lms/doubtfire-api/commit/b47b9ab79fec4b6dfb2055a786aaeaeef3616493))
* Add custom serialiser to support rails 6 ([d051bef](https://github.com/doubtfire-lms/doubtfire-api/commit/d051befdebecd41b062de60e84aed70d2b4027b7))
* Add database populator require to units factory ([29b22b9](https://github.com/doubtfire-lms/doubtfire-api/commit/29b22b9d74312f17ce975ef863c1eedcd14f5eb9))
* Add factory_bot_rails in test,staging ([f4a85d6](https://github.com/doubtfire-lms/doubtfire-api/commit/f4a85d66c6dfd194c72c42760a483962e391c8f1))
* Add headers for application controllers to match grape ([71cc316](https://github.com/doubtfire-lms/doubtfire-api/commit/71cc316848743ba6dd10c430d0e0bebfcda3d55d))
* add idp certificate to saml settings ([e5926fa](https://github.com/doubtfire-lms/doubtfire-api/commit/e5926fa9fd42277aee4be7fb81569d712d9995e0))
* add listen gem for development environment ([1675dbf](https://github.com/doubtfire-lms/doubtfire-api/commit/1675dbfcb48b923eada172fba8831b00cb6de799))
* add missing end from if statement in auth_helpers ([4034dd2](https://github.com/doubtfire-lms/doubtfire-api/commit/4034dd2e8be59abc21e1ae8f3e2178b38aa7bc22))
* add missing end to authentication_api ([28caaab](https://github.com/doubtfire-lms/doubtfire-api/commit/28caaab4a93bfc0bc35f1a16028413713b51c3c4))
* add missing overseer entities ([7f09f50](https://github.com/doubtfire-lms/doubtfire-api/commit/7f09f508428ebede4aa7f04d90ef26abe113b3f7))
* add required config/storage.yml file ([de3df26](https://github.com/doubtfire-lms/doubtfire-api/commit/de3df26af99ae1233e9bf42eeddb7727c195ac25))
* add saml signout URL ([879624c](https://github.com/doubtfire-lms/doubtfire-api/commit/879624c799268e6b582f871ac7218d622f0cec6f))
* add saml to gemfile.lock ([1456597](https://github.com/doubtfire-lms/doubtfire-api/commit/145659728c619b07b7c0d74b7de967bc67bb89e1))
* Add serializer for task comments ([6afa092](https://github.com/doubtfire-lms/doubtfire-api/commit/6afa09215b4803a659c74f33b2004d11b2143251))
* Auth token via user ([6dc53b9](https://github.com/doubtfire-lms/doubtfire-api/commit/6dc53b9b27473a98f83b83c8235145d5729ab567))
* Auth token via user ([75bab1d](https://github.com/doubtfire-lms/doubtfire-api/commit/75bab1d49286f863c25d632985ed2f9190de3177))
* Authenticate auth tokens via User ([ca9edb7](https://github.com/doubtfire-lms/doubtfire-api/commit/ca9edb7896a5b8abdb633eec27842afcbcbb8421))
* Authenticate token via user ([224e5e9](https://github.com/doubtfire-lms/doubtfire-api/commit/224e5e953e1613ff5fad6677e0a423bccfb5d1d2))
* Authenticate tokens via User ([3bcad77](https://github.com/doubtfire-lms/doubtfire-api/commit/3bcad77319b918b6c8afafaa4943464c425ddf0e))
* Check sending headers from auth test ([c8c7ef4](https://github.com/doubtfire-lms/doubtfire-api/commit/c8c7ef4da2e294e3049086b31fa1980d75a94fd6))
* check userRole when creating SAML user ([fce7fbd](https://github.com/doubtfire-lms/doubtfire-api/commit/fce7fbdd604b8af5d76a942bb3016145c6f980ff))
* check userRole when creating SAML user ([bbf7adb](https://github.com/doubtfire-lms/doubtfire-api/commit/bbf7adba1a6ddc2e683ca053477a2d59983adee7))
* consolidate aaf/saml response format ([1a5fcb8](https://github.com/doubtfire-lms/doubtfire-api/commit/1a5fcb88bb4ce824fe37ad4361e4185a40714a41))
* Correct assert json matches update for rails ([14e1aa9](https://github.com/doubtfire-lms/doubtfire-api/commit/14e1aa9f98ba3bc7d0bf124c9ff071ce3a59dac3))
* correct calculation of week number for units outside teaching periods ([591780c](https://github.com/doubtfire-lms/doubtfire-api/commit/591780c74bc0238112167ebce0a8259c8280bc18))
* correct can destroy behaviour for rails 6 ([794b6e4](https://github.com/doubtfire-lms/doubtfire-api/commit/794b6e4764d3edbb49cb2d3c49bb1176ed55257a))
* Correct case of auth params and headers ([d3c0206](https://github.com/doubtfire-lms/doubtfire-api/commit/d3c020618d5d10acbe68560204ef11f1dfcfff48))
* Correct error message response ([4086227](https://github.com/doubtfire-lms/doubtfire-api/commit/408622700117f5f8a942ad92f0205d940e46ce4d))
* Correct exception handling in tests and ensure foreign key breaks are handled in the API ([81856d1](https://github.com/doubtfire-lms/doubtfire-api/commit/81856d1f2d94eee6f48325540f0df52b9b636497))
* Correct group test with missing auth details ([820e255](https://github.com/doubtfire-lms/doubtfire-api/commit/820e255564494d83e7512ad614d0bec4674c7b9f))
* correct issue in foreign key migration ([a70fb57](https://github.com/doubtfire-lms/doubtfire-api/commit/a70fb570d2f52f5af91c3e54a99c5d2345f1aa91))
* Correct issue with double adding user if to auth token ([b3afad6](https://github.com/doubtfire-lms/doubtfire-api/commit/b3afad6c64ae1d45775d40dde88189e6fd4a5823))
* correct issues in schema and migration of discussion comments ([799f5cc](https://github.com/doubtfire-lms/doubtfire-api/commit/799f5cc2e413eefce903876238671cb34622a75d))
* Correct issues with sign out ([e47e05b](https://github.com/doubtfire-lms/doubtfire-api/commit/e47e05bee7b52da04fe410fe3f935a163aff4878))
* Correct json model compare to work with hash ([070e677](https://github.com/doubtfire-lms/doubtfire-api/commit/070e677f4a7bf26b35e1b87b516e7712bf44821a))
* correct key env settings in development ([19d7cc9](https://github.com/doubtfire-lms/doubtfire-api/commit/19d7cc9633dfda45b358ac9b74f165f8ddd00cf7))
* correct logging of aaf login and add to saml ([90d2608](https://github.com/doubtfire-lms/doubtfire-api/commit/90d260865c8e87776fbee5195d0ca21060602f00))
* correct migrate index creation with bigint switch ([81287ea](https://github.com/doubtfire-lms/doubtfire-api/commit/81287ea9bc16e8b34731c1fb0dc925115a810680))
* correct migration of auth token. ([11c3235](https://github.com/doubtfire-lms/doubtfire-api/commit/11c3235fd613fbbac26c2f4fdd966ad75b0fb028))
* Correct populator use of BigDecimal ([f7f5aa3](https://github.com/doubtfire-lms/doubtfire-api/commit/f7f5aa3f6999fd2485df6a80da4c959627776be2))
* Correct reference in auth token migration ([6a4f643](https://github.com/doubtfire-lms/doubtfire-api/commit/6a4f6434bb26a3847e6691b113659900586e9ff7))
* correct remove index migration ([09c402f](https://github.com/doubtfire-lms/doubtfire-api/commit/09c402f7ac8ece9108ed5cbbbadbace6633f82ab))
* correct task definition entity ([0d8f3d1](https://github.com/doubtfire-lms/doubtfire-api/commit/0d8f3d1173b68824662fe49b6f087efaf87b2397))
* Correct typo in user for reminder test ([8609444](https://github.com/doubtfire-lms/doubtfire-api/commit/860944409b79e1f8a147695b74c791ff9059f85c))
* Correct unit model test to work with new environment ([91d29fd](https://github.com/doubtfire-lms/doubtfire-api/commit/91d29fd79db130ae06d405f11938592895edbfe0))
* Correct use of assert nil in task status tests ([63852bb](https://github.com/doubtfire-lms/doubtfire-api/commit/63852bb6c61a5398e65a59878ddaa945befdc654))
* correct use of doubtfire logger ([6ae0220](https://github.com/doubtfire-lms/doubtfire-api/commit/6ae0220edff3bc7a2f44035321cbbc236cc5df41))
* Correct use of present to use with key not using ([4c60841](https://github.com/doubtfire-lms/doubtfire-api/commit/4c608418d38b4148e8c16f88e1ab68b36f359dfb))
* create saml config hash ([f478102](https://github.com/doubtfire-lms/doubtfire-api/commit/f4781021290c369709adb3e97c44c06fea5c08ca))
* Default remember to false on generate token ([62d1785](https://github.com/doubtfire-lms/doubtfire-api/commit/62d1785fccb8542de6a8b62a955a7c0262ac3dd9))
* Delete duplicate .object in serialisers ([4225dbf](https://github.com/doubtfire-lms/doubtfire-api/commit/4225dbf5d90aa29cae9efa04257632de9eca631c))
* don't specify bundler version ([c665cb7](https://github.com/doubtfire-lms/doubtfire-api/commit/c665cb729df8b26c81a008001cd4c9dbcd822517))
* ensure all routes use presenters ([c05b624](https://github.com/doubtfire-lms/doubtfire-api/commit/c05b624660d4da63a0f86114115b42965edf0717))
* ensure authentication token is unique for a user ([eb73851](https://github.com/doubtfire-lms/doubtfire-api/commit/eb738510e70093954aa4c890fdabc4ca235fa3cb))
* Ensure error on invalid token ([314b269](https://github.com/doubtfire-lms/doubtfire-api/commit/314b269d71fa6df7dcd9db3d2b78b0a32ada845f))
* Ensure generate tokens is passed remember value ([0ece967](https://github.com/doubtfire-lms/doubtfire-api/commit/0ece967f278db75d48a87ed8177d5270bb4bbb29))
* ensure init includes aadmin ([faf8255](https://github.com/doubtfire-lms/doubtfire-api/commit/faf8255ebc381d920fb3cf029bb5d0ee887f5315))
* Ensure key is 32 bytes only in encrypted attributes ([9d9eb11](https://github.com/doubtfire-lms/doubtfire-api/commit/9d9eb111e5633f8dc86f9a13f73b418d37096fea))
* ensure migration tests for foreign keys ([fca64c6](https://github.com/doubtfire-lms/doubtfire-api/commit/fca64c6b6628c6fe2ffc572e0ad591bfb7fb1e61))
* Ensure migration works for auth tokens up and down ([7d4dbcd](https://github.com/doubtfire-lms/doubtfire-api/commit/7d4dbcdfa18ed7c28402fbe3948a3d9b6e4b5431))
* ensure overseer comment entity has current user ([91f8430](https://github.com/doubtfire-lms/doubtfire-api/commit/91f84300d1a232f3130a533256bfa8dfed5d273a))
* Ensure pdf generation works for tests ([f06e371](https://github.com/doubtfire-lms/doubtfire-api/commit/f06e371aa7ac733a96c187ed7e3e9c751708e249))
* ensure rake db:init is available for new deployments ([e5e1092](https://github.com/doubtfire-lms/doubtfire-api/commit/e5e10924531453407e07e236e080021dab0fa145))
* Ensure signif works on integers ([011478f](https://github.com/doubtfire-lms/doubtfire-api/commit/011478fce31370e03897b0df482276f7a3f5da8d))
* Ensure status comments are marked as read on create ([171ec76](https://github.com/doubtfire-lms/doubtfire-api/commit/171ec76110df0357a2878382e7047ba1fdd5d5ab))
* Ensure that group tests work with new ([7aa14e6](https://github.com/doubtfire-lms/doubtfire-api/commit/7aa14e6e25fe8690a810a56d55976be36ee49eab))
* Ensure that students can reply to others in group comments ([83bc4d7](https://github.com/doubtfire-lms/doubtfire-api/commit/83bc4d73cc1772baab704d266508773218ce0154))
* Ensure that updating task status returns update only task details ([5c35915](https://github.com/doubtfire-lms/doubtfire-api/commit/5c35915fc84b2e17bde0656ca497331f44b6746f))
* Ensure that user is saved on generate of auth token ([0627780](https://github.com/doubtfire-lms/doubtfire-api/commit/062778017ee7d7df6e90f507d0181a96e0e9309a))
* ensure unit roles always include the unit id ([9b624e5](https://github.com/doubtfire-lms/doubtfire-api/commit/9b624e579f8d60bace7d5f0d1a8d04f49b6e474d))
* Ensure user accessed correctly in unit entity ([98a2d59](https://github.com/doubtfire-lms/doubtfire-api/commit/98a2d59334421f0445b7ecdb542d1999df84d816))
* Ensure using throw abort in before destroy on error ([e503ca2](https://github.com/doubtfire-lms/doubtfire-api/commit/e503ca221fba5b12875b6478a7e4e62ac29d2d75))
* Ensure webcal method use correct auth methods ([71773b6](https://github.com/doubtfire-lms/doubtfire-api/commit/71773b6bf17b21c993ab41856a51d7668c89eaa3))
* Fix and use bundler2.0 in CI ([631d339](https://github.com/doubtfire-lms/doubtfire-api/commit/631d339beaec125aeb2e63201609d99e19fa6f48))
* Fix error when change code to factorybot ([59fc722](https://github.com/doubtfire-lms/doubtfire-api/commit/59fc7224be6fcf934d9db660b1f1450372b63148))
* fix logger syntax error ([e87fcc1](https://github.com/doubtfire-lms/doubtfire-api/commit/e87fcc1e00400384d6190afadb21963a7793adc6))
* Fix Travis CI error ([ae6e151](https://github.com/doubtfire-lms/doubtfire-api/commit/ae6e1518dc5c84a2def625771a95ac85529ed31a))
* fix typos in authentication helper doc ([7cdb854](https://github.com/doubtfire-lms/doubtfire-api/commit/7cdb85453bf64bf296f8ca613e6f8ff8cfa4f2fd))
* Grape now uses *body* to return data update in teaching periods ([a7ebcda](https://github.com/doubtfire-lms/doubtfire-api/commit/a7ebcdaee8457d7f98268efe52c393b6a3440034))
* Grape params are now hash - update file upload field access to read from hash ([b4366fc](https://github.com/doubtfire-lms/doubtfire-api/commit/b4366fc2cbab4998e3b4aaf17b6efe4ce7e1f134))
* improve reliability of get awaiting feedback test ([318c9bc](https://github.com/doubtfire-lms/doubtfire-api/commit/318c9bc367986b66e09a95117e91a760f40cddf2))
* Incorrect use of self to access activee record rows ([8424272](https://github.com/doubtfire-lms/doubtfire-api/commit/84242721379b159ad07f9b14bc905f7376a57c76))
* lock listen gem version ([49c907c](https://github.com/doubtfire-lms/doubtfire-api/commit/49c907c88aa4edccae96ad6113a398acbb3ab5f8))
* Migrate to unit entity and fix unit api tests ([f38c377](https://github.com/doubtfire-lms/doubtfire-api/commit/f38c3774ed17153f65291c3c98984b07c5921ae4))
* pass required username to sign_in page ([58a9fc2](https://github.com/doubtfire-lms/doubtfire-api/commit/58a9fc2ecebb902ede084dd3db62d4bb8182f684))
* read saml config from hash correctly ([0e17743](https://github.com/doubtfire-lms/doubtfire-api/commit/0e177433a8ef14420e7d4b955878d944fa96409b))
* reenforce bundler version in dockerfile ([0d5341b](https://github.com/doubtfire-lms/doubtfire-api/commit/0d5341bad96025ab30f3fbe7a4032d6c9e8644fd))
* remote username mangling ([e7accd9](https://github.com/doubtfire-lms/doubtfire-api/commit/e7accd96cfbe18bf8d9a548752edf1a8b3ed9130))
* remove all use of active model serializers ([f628ff4](https://github.com/doubtfire-lms/doubtfire-api/commit/f628ff463306cf018b1304bfd34cfffd02883e86))
* remove clock drift from settings object ([1d63e9c](https://github.com/doubtfire-lms/doubtfire-api/commit/1d63e9c597956eac94f93d3bb39de59cee35ee0b))
* remove create_and_post_user method ([12237a8](https://github.com/doubtfire-lms/doubtfire-api/commit/12237a828ca8bfa5ffba3784d4c92fdc4e642a13))
* remove down migration data update for auth tokens. ([bbeef86](https://github.com/doubtfire-lms/doubtfire-api/commit/bbeef86da00749554af0c8fbf4562b3522152318))
* remove duplicate index on learning outcomes ([6d23243](https://github.com/doubtfire-lms/doubtfire-api/commit/6d23243c38f5d4fe3815d8ffc63a2fdda210799e))
* remove old bundler version specified ([348b9c2](https://github.com/doubtfire-lms/doubtfire-api/commit/348b9c26e67470b917ef0c162df07e3f5994ce2a))
* remove postgres from Gemfile.lock ([83150d9](https://github.com/doubtfire-lms/doubtfire-api/commit/83150d94a3b39341adedc2cbf3964aa852420525))
* remove references to discussion comment table ([d6507cf](https://github.com/doubtfire-lms/doubtfire-api/commit/d6507cf2e6949a8be6af66f1ad8b9b46c9d8126e))
* Remove return from TaskEntity other projects ([f396596](https://github.com/doubtfire-lms/doubtfire-api/commit/f3965963fc6844bd131de3a3be065af02784e2ce))
* Remove sample html file ([51ef0d6](https://github.com/doubtfire-lms/doubtfire-api/commit/51ef0d62d2568e4fc4b84f2dc8f8311bc2c1e8dc))
* remove task comment foreign key in id migration ([58c264e](https://github.com/doubtfire-lms/doubtfire-api/commit/58c264e89c72848ab569b4fb4dc22f53731c2293))
* Remove trace from group tests ([deed1e7](https://github.com/doubtfire-lms/doubtfire-api/commit/deed1e76c7a1374b909e02912e1e748feb8406e5))
* remove unnecessary access token from action ([c4c34de](https://github.com/doubtfire-lms/doubtfire-api/commit/c4c34de1c023de25a72b1a2f685d9c4b2bc654fc))
* Remove unneeded email from tutor in tutorial ([00f5082](https://github.com/doubtfire-lms/doubtfire-api/commit/00f50821217a65244c90d9a6326953be366962c7))
* remove unused devise routes ([a270d25](https://github.com/doubtfire-lms/doubtfire-api/commit/a270d25be16c3c4c9db983f2f9eb67b576f0f15c))
* rename not_queued enum constant ([55a86e3](https://github.com/doubtfire-lms/doubtfire-api/commit/55a86e37b25386bd172809ad9abe9ee8f40e380e))
* revert gemfile lock ([73721d2](https://github.com/doubtfire-lms/doubtfire-api/commit/73721d290d901809a492548e3fde87141246c416))
* support zeitwerk mode loader ([15e3f96](https://github.com/doubtfire-lms/doubtfire-api/commit/15e3f9662493a6c1839aa7daa50cc12a0dc301ec))
* Switch auth and user to grape entity ([b92d3db](https://github.com/doubtfire-lms/doubtfire-api/commit/b92d3dbdca50f7d0a4613327d78138504c801cc5))
* Switch file access to hash ([38d7a3c](https://github.com/doubtfire-lms/doubtfire-api/commit/38d7a3ce953938a61c21d6504a3dd0578cfa81fc))
* Switch from after to before update where changed used ([3bd7d4b](https://github.com/doubtfire-lms/doubtfire-api/commit/3bd7d4bfcbcb35e1113229ee414bfe299ef66b47))
* Switch from around to before update ([69cbe06](https://github.com/doubtfire-lms/doubtfire-api/commit/69cbe069399be64a5fa60370753a4abf6afde837))
* switch latex config to use recipe ([7e75c15](https://github.com/doubtfire-lms/doubtfire-api/commit/7e75c15b14a189f785c50902007fc55b044cf677))
* switch scopes to methods ([989e8c2](https://github.com/doubtfire-lms/doubtfire-api/commit/989e8c297300fc3f0f5782367d4dc5591fe70af1))
* Switch tutorial api to use new entity ([be9ead0](https://github.com/doubtfire-lms/doubtfire-api/commit/be9ead090d6abdef0e12446b7e672a4c4e533758))
* Update authentication in Sign-out API ([1e843e2](https://github.com/doubtfire-lms/doubtfire-api/commit/1e843e2d37d7db49c8870b96778dd2d6f00738dc))
* update bunny pub sub to fix subscriber launch ([37de3bc](https://github.com/doubtfire-lms/doubtfire-api/commit/37de3bccff94cad2be1a607f173ba5580bc10016))
* Update faker deprecated methods ([f19928d](https://github.com/doubtfire-lms/doubtfire-api/commit/f19928d50080a895babec3f496f66d41a50f79d1))
* update migration for ralls 6 ([348b4b3](https://github.com/doubtfire-lms/doubtfire-api/commit/348b4b38619fbf068252c7a470cdb7020bb68a26))
* Update migration to work with new code on migrate without data loss ([c032ec3](https://github.com/doubtfire-lms/doubtfire-api/commit/c032ec3f1eeea20d439258f7718a89a2ca1f1702))
* update model object to work with ruby 3.1 ([ebc5832](https://github.com/doubtfire-lms/doubtfire-api/commit/ebc5832b3ccda6769329b5f4ae701bc351fcf07b))
* Update status tests based on new read by everyone on status comments ([ebc8694](https://github.com/doubtfire-lms/doubtfire-api/commit/ebc8694086730c15a6294079397866d53115244a))
* Update tutorial enrolments to use new entities ([1fe02c3](https://github.com/doubtfire-lms/doubtfire-api/commit/1fe02c328bf4938155e01e70363a88eab120e9d1))
* Update use of update attributes ([b5e5d46](https://github.com/doubtfire-lms/doubtfire-api/commit/b5e5d464d760c18d3881f07783010d7b39780623))
* Update zip filename access ([77f7b70](https://github.com/doubtfire-lms/doubtfire-api/commit/77f7b70a0f488537f30988584c62e28d115d197f))
* Updated activity types, campuses and csv tests ([5710753](https://github.com/doubtfire-lms/doubtfire-api/commit/5710753b95de8805a0aa61fd4122b6e37aa6ca5e))
* Updated comments and units tests ([e760fff](https://github.com/doubtfire-lms/doubtfire-api/commit/e760ffffd8c551c384d9c00b94f61b525e8eeb05))
* Updated tutorials, unit roles, units and users tests ([8d2035f](https://github.com/doubtfire-lms/doubtfire-api/commit/8d2035f6ba3e60968da7063bf3676333c469ae35))
* Updated unit testing for all /api/activity_types_api_test endpoint ([1df78d9](https://github.com/doubtfire-lms/doubtfire-api/commit/1df78d9b5b34e6bd4403fe5e1b360f4e2c6d2638))
* Updated unit testing for all /api/auth endpoint ([ae3e8cf](https://github.com/doubtfire-lms/doubtfire-api/commit/ae3e8cfb3fe4987e0a0ecc969855d17361f7c9c1))
* Updated Unit tests for groups, projects, students and api ([0aac2de](https://github.com/doubtfire-lms/doubtfire-api/commit/0aac2defb2db602b5fd36e22bd4e51a45e4ba4a7))
* upgrade callbacks and use of _changed? and _was to new rails 6 behaviour ([20f779b](https://github.com/doubtfire-lms/doubtfire-api/commit/20f779bfe111c17b81aac940720578eef75a8980))
* Upgrade ruby version to 2.6 in CI ([7603cb8](https://github.com/doubtfire-lms/doubtfire-api/commit/7603cb83d35d41b5fda99d28bb4da9cae7526655))
* use new Grape Entity model for overseer ([9632b88](https://github.com/doubtfire-lms/doubtfire-api/commit/9632b881d1e7d14653742ca5af83094d2a2033fe))
* use password auth if not aaf or saml ([aee8d6b](https://github.com/doubtfire-lms/doubtfire-api/commit/aee8d6bb73e41489093ff189f3cd375f151c04a3))
* Use presenter in portfolio evidence api ([a8ee43e](https://github.com/doubtfire-lms/doubtfire-api/commit/a8ee43e6cea5b21808a925287d44c447bfb54caa))
* use puts instead of y ([312390e](https://github.com/doubtfire-lms/doubtfire-api/commit/312390eda2631142b439e61473fe50d88dc51443))

### [5.0.7](https://github.com/doubtfire-lms/doubtfire-api/compare/v5.0.6...v5.0.7) (2021-12-09)


### Features

* Add support for files from Elements of Computer Systems ([#333](https://github.com/doubtfire-lms/doubtfire-api/issues/333)) ([a3742a5](https://github.com/doubtfire-lms/doubtfire-api/commit/a3742a5058dac2c34abd8ea28370e7abbde54c75))
* make portfolio evidence relative ([701f58c](https://github.com/doubtfire-lms/doubtfire-api/commit/701f58c9c30cb54199c823dec34eb63a50264714))


### Bug Fixes

* correct convert submission to pdf to use new folder by default ([f216834](https://github.com/doubtfire-lms/doubtfire-api/commit/f216834bb2bb8906e823282dba064372a8463ef0))
* esure changes to portfolio evidence apply to task ([6ade5f1](https://github.com/doubtfire-lms/doubtfire-api/commit/6ade5f13d1206d72142a19c2c7984dc46b4fd9ae))
* remote username mangling ([789fed1](https://github.com/doubtfire-lms/doubtfire-api/commit/789fed1c67010ad8c1b8a46a36b3965de3565c7b))

### [5.0.4](https://github.com/doubtfire-lms/doubtfire-api/compare/v5.0.3...v5.0.4) (2021-12-06)


### Features

* add script to sync enrolments ([bc65722](https://github.com/doubtfire-lms/doubtfire-api/commit/bc65722c7c22670f5e522d12c472c75c227c43b6))


### Bug Fixes

* remove set environment from scripts ([f3437bd](https://github.com/doubtfire-lms/doubtfire-api/commit/f3437bde40d7042080528d57a16428103e260602))

### [5.0.3](https://github.com/doubtfire-lms/doubtfire-api/compare/v5.0.2...v5.0.3) (2021-11-19)


### Features

* log messages to stdout on all environments ([31041c6](https://github.com/doubtfire-lms/doubtfire-api/commit/31041c627de2db7c5e5cc0d3d81ebe68235b5120))


### Bug Fixes

* correct error message on submission process fail ([b789239](https://github.com/doubtfire-lms/doubtfire-api/commit/b78923996cf0cd4987a54dc1fa563e54abe2ffd1))
* ensure populator works with init ([89ae68b](https://github.com/doubtfire-lms/doubtfire-api/commit/89ae68bc40c75ff6c7fd44a1452df42761592581))
* update bunny pub sub to fix logging and launch issues ([a3ae105](https://github.com/doubtfire-lms/doubtfire-api/commit/a3ae105f45ea699eeae2b16557a91b0209b7116c))

### [5.0.2](https://github.com/doubtfire-lms/doubtfire-api/compare/v5.0.1...v5.0.2) (2021-11-19)


### Bug Fixes

* update bunny pub sub version ([f594bdf](https://github.com/doubtfire-lms/doubtfire-api/commit/f594bdfef57323cfb9490584ca955e79b0e07bee))

### [5.0.1](https://github.com/doubtfire-lms/doubtfire-api/compare/v5.0.0...v5.0.1) (2021-10-27)

## [5.0.0](https://github.com/doubtfire-lms/doubtfire-api/compare/v5.0.0-2...v5.0.0) (2021-10-13)


### Features

* add ability to export auth tokens for migration from 5 to 6 ([b40bdd9](https://github.com/doubtfire-lms/doubtfire-api/commit/b40bdd96924f0e308850f72d27440e0d305c0759))
* Add ability to init production ([bd200e6](https://github.com/doubtfire-lms/doubtfire-api/commit/bd200e6295db8f55dbcd77f6bad6b462a4e98964))


### Bug Fixes

* Add missing comma in unit.rb ([36c4fac](https://github.com/doubtfire-lms/doubtfire-api/commit/36c4fac7c04b50e4db1f7de12540a9206e858660))
* Add missing self keyword ([f4be643](https://github.com/doubtfire-lms/doubtfire-api/commit/f4be643108b30cf43877d3342341837288712f46))
* Add rescue/ensure block to ontrack_receive_action ([53d8d3c](https://github.com/doubtfire-lms/doubtfire-api/commit/53d8d3cf0dfe5353cdfd73bcf222088efea2bdea))
* align overseer assessment with single assessment comment ([25dbaf8](https://github.com/doubtfire-lms/doubtfire-api/commit/25dbaf802a410863d44db26192511788988728ee))
* Allow protocol to be included in host configuration ([142d80d](https://github.com/doubtfire-lms/doubtfire-api/commit/142d80d78a71d5fd33a87bbd64e0f348f15e8d58))
* Change password back to what it was ([73e6bd8](https://github.com/doubtfire-lms/doubtfire-api/commit/73e6bd884f6a558dba1a099f20e235558f5a1a1b))
* correct convert submission to pdf to use new folder by default ([a4ed642](https://github.com/doubtfire-lms/doubtfire-api/commit/a4ed642cf4c4db29b01e14319a3652314126c972))
* correct development redirect url on aaf auth ([badf14f](https://github.com/doubtfire-lms/doubtfire-api/commit/badf14f43542bd30759708d68a3756d0801d4cbc))
* correct hard coded path to overseer instance ([627d257](https://github.com/doubtfire-lms/doubtfire-api/commit/627d2576616be6e7de52d17cc106deb1df105d35))
* correct overseer env settings in compose ([1daabe8](https://github.com/doubtfire-lms/doubtfire-api/commit/1daabe800ef1cafd36b2391dfcdce2e8e03012dd))
* correct port for developemnt to use 3000 ([778442d](https://github.com/doubtfire-lms/doubtfire-api/commit/778442d146ad7db35f7182ae5d9be53bab44aabe))
* Correct request in skip prod to use STDIN ([6c2c8ef](https://github.com/doubtfire-lms/doubtfire-api/commit/6c2c8ef0d1d985b151f38995c430bebbcc892158))
* Download the task assessment resources authorisation ([d2ae227](https://github.com/doubtfire-lms/doubtfire-api/commit/d2ae2274d9f73067b5972ccf251933e7077773eb))
* Ensure docker image installs bundler ([26110d7](https://github.com/doubtfire-lms/doubtfire-api/commit/26110d7eddae3e490c76ff3b6363912bd82ab2ea))
* ensure tasks with assessments can be destroyed cleanly ([e322b8d](https://github.com/doubtfire-lms/doubtfire-api/commit/e322b8d21bbc99a63a928ef9b5b6b7e4bed34bc8))
* ensure that init does not add task status twice ([86d9dd4](https://github.com/doubtfire-lms/doubtfire-api/commit/86d9dd41605fea50d30a4a07bc742ab123d74b8c))
* ensure two newlines between comment text in assessment comment ([3dd7021](https://github.com/doubtfire-lms/doubtfire-api/commit/3dd7021ea5c1bc1329f674669ef7f95a6f96fb2e))
* File permissions for overseer to operate upon ([e3708aa](https://github.com/doubtfire-lms/doubtfire-api/commit/e3708aa03f0fb273a0642b7544115b842d97e8d7))
* Gemfile.lock revision for bunny-pub-sub ([c5b137a](https://github.com/doubtfire-lms/doubtfire-api/commit/c5b137afe473e4a23da4857f81eb87b715dda904))
* Include :has_task_assessment_resources? ([6975790](https://github.com/doubtfire-lms/doubtfire-api/commit/69757903ab217f4f96efdb6f9c095523ffd03953))
* Let config.overseer_images exist without OVERSEER_ENABLED flag ([56e6874](https://github.com/doubtfire-lms/doubtfire-api/commit/56e687422e9987858058b078688603f0835d4b04))
* Missing `sm_instance` method error ([94fd461](https://github.com/doubtfire-lms/doubtfire-api/commit/94fd46166a4bfe96ce988f323c309d040a6fe73e))
* New assessment API bugs ([0f4273c](https://github.com/doubtfire-lms/doubtfire-api/commit/0f4273c3a39d8fd8d0117720f9fc3e18c076ae84))
* Quotes in application.rb ([d55ec13](https://github.com/doubtfire-lms/doubtfire-api/commit/d55ec134928bc5994dd4539d2144c71532e9b9b9))
* Remove breaking empty test ([97a9c3d](https://github.com/doubtfire-lms/doubtfire-api/commit/97a9c3df1025aa7587f4c5fce5929fe2271a8ebc))
* Remove bundle exec rake db:setup step ([fcc7e26](https://github.com/doubtfire-lms/doubtfire-api/commit/fcc7e267227a5d6238fd817d1d480b71f9dc3082))
* Remove clutter from submission API ([15f0361](https://github.com/doubtfire-lms/doubtfire-api/commit/15f0361d8a15dd8885a0dfc082ac5af9e1f8ec02))
* Require bunny-pub-sub in all environments ([bf75374](https://github.com/doubtfire-lms/doubtfire-api/commit/bf753749b99a58e2af5731b8519c54b5fa7a5d3d))
* Routes param description for docker_image_name_tag ([eec9ed3](https://github.com/doubtfire-lms/doubtfire-api/commit/eec9ed399407d1b2d7fd9bd4f8e8e06ef4faea88))
* Set default units.assessment_enabled to true ([d2b1c89](https://github.com/doubtfire-lms/doubtfire-api/commit/d2b1c89211daf4d746d1b753bcbc7dd40b924507))
* Strip path till submission history for easy mounting ([c3d43b0](https://github.com/doubtfire-lms/doubtfire-api/commit/c3d43b01c1a4d9fdc2b68ca048c4a364bdf03f4a))
* Strip till /doubtfire-api instead ([e0b599c](https://github.com/doubtfire-lms/doubtfire-api/commit/e0b599c9012fcf7f24d4166e22119e4d23d27103))
* Switch task definition to use docker image model ([68212eb](https://github.com/doubtfire-lms/doubtfire-api/commit/68212eb7093cdb4b36b678e8125a770cb64e29b3))
* Task comments generation ([91eacae](https://github.com/doubtfire-lms/doubtfire-api/commit/91eacae50a5b5989e975034421bf65378efef963))
* Task status error ([01a0f9e](https://github.com/doubtfire-lms/doubtfire-api/commit/01a0f9edceae11674898abf1700f055ba20d97f9))
* test moving file into place ([fe0681d](https://github.com/doubtfire-lms/doubtfire-api/commit/fe0681d5c40965f64ac481255106bbeb340bbf49))
* Typo in application.rb ([9e8e930](https://github.com/doubtfire-lms/doubtfire-api/commit/9e8e9301e6a437f8b7705eacd059ea19c9c92599))
* Update bunny-pub-sub version ([6e3cbe5](https://github.com/doubtfire-lms/doubtfire-api/commit/6e3cbe557959e28823b558ec7bdc514beb4579bf))
* Update bunny-pub-sub version in Gemfile.lock ([971eb80](https://github.com/doubtfire-lms/doubtfire-api/commit/971eb802a37871296228fdfca02a8347f85f1fa6))
* Update config in compose to include production ([941ea1c](https://github.com/doubtfire-lms/doubtfire-api/commit/941ea1c2b760f5a4fdcda9f80632f16471efcfca))
* Update overseer actions to work with new structure ([96836d2](https://github.com/doubtfire-lms/doubtfire-api/commit/96836d200dbcdc9bc1c11e4e99dc09e71890b7c4))
* Update overseer config to use new fixed settings ([a520b64](https://github.com/doubtfire-lms/doubtfire-api/commit/a520b64a53e026caa8828777ac998fd5218a01f8))
* Uploading new files replaces existing files in student_work/new/task_id folder ([a8a4563](https://github.com/doubtfire-lms/doubtfire-api/commit/a8a4563fa372479e4b61c4a9646d19753e711702))
* Validation for docker_image_name_tag now respects nil values ([23408f7](https://github.com/doubtfire-lms/doubtfire-api/commit/23408f76b6d173ff5e36c8a8072096f234e8af1b))
* Validators for docker_image_name_tag ([372fe97](https://github.com/doubtfire-lms/doubtfire-api/commit/372fe97235584a291b4a8ddb97d109d4cfe50595))
* Variable name ([5303ceb](https://github.com/doubtfire-lms/doubtfire-api/commit/5303ceb48be6d9e768a67560b84bd5a8e20c2f7c))
* YAML Docker image name, disable image ([3fe985b](https://github.com/doubtfire-lms/doubtfire-api/commit/3fe985bc6fc8b223eb9e6f8c5927d0def4612f64))

## [5.0.0-rc1](https://github.com/doubtfire-lms/doubtfire-deploy/compare/v2.0.0...v5.0.0-rc1) (2021-08-03)


### Bug Fixes

* Correctly assign webcal reminder descriptions. Fixes [#316](https://github.com/doubtfire-lms/doubtfire-deploy/issues/316) ([fa178b7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/fa178b793090de80dd2359258e81d90354dac114))
* Ensure Deakin star activities only include associated teaching period ([1e3e981](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1e3e981d2bff0ae714c527143cd18307a1a9a6c9))
* Remove harcoded user ID in webcal exclusion update ([d7e66aa](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d7e66aa353dd88da98d51c30732ad4ad674090da))
* Run migration ChangeDoNotResubmit ([6354aff](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6354affa6162a474c7caf6fb2ee769e204727340))

## 2.0.0 (2021-07-29)


### Features

* Add ability to init production ([bd200e6](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bd200e6295db8f55dbcd77f6bad6b462a4e98964))


### Bug Fixes

*  Remove empty check for potentially null group set on import ([c771c7b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c771c7b1d3e631d2ed6143c230daf03e264ae255))
* .ceil of an integer not returning what was expected ([686e08d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/686e08d8ba6320cd6ad3de4d6b9034b45a8c31ad))
* `task-webcal` review by [@macite](https://github.com/macite) ([c5f8d90](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c5f8d90431027828f45c8265de3c0fb9e2e71274))
* Add :download_csv to tutor_role_permissions ([45dc74d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/45dc74da79cf7254341ba82998def6d0c785c15d))
* Add a page break to LOs in portfolio ([28922fc](https://github.com/doubtfire-lms/doubtfire-deploy/commit/28922fc260769c5b9de8f194366c6c46e5d30214))
* Add a preliminary line before the weekly summary ([b1a6d23](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b1a6d2395c186f8e8b194139d94ad53c057b6844))
* Add ability to redirect on AAF signout ([9d071f2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9d071f2107f1d6fd5841495ee651573b79633262))
* Add additional character support to latex ([6c13ea8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6c13ea8dd9d7cd4e41bb245a314e82655f4f482a))
* Add additional packages for latex install in CI ([dbc085b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/dbc085bb45d0822a9de2fd7dd00eecc3c060b3c5))
* Add anchors to duplicate dev secrets in test & replica ([19255c7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/19255c79943f96851eba15256160e4da79167e17))
* Add application csv as mime time for csv upload ([88b784b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/88b784bc119c0a0e3a1683ab36d07a3373dcd351))
* Add application/ogg for audio files ([ceaf809](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ceaf809741dad4de75e197a3e9d4897b7ff60bb7))
* Add attachment to task sheet and adjust attachment logic ([6fe7f00](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6fe7f00afbccd40d261246546a00bd35a7f950c5))
* Add auto extension to params for unit put ([92d39bf](https://github.com/doubtfire-lms/doubtfire-deploy/commit/92d39bf6935fd1eff245b1d2fd337f136d214ad8))
* Add back plagiarism pages to the ui ([236d1f4](https://github.com/doubtfire-lms/doubtfire-deploy/commit/236d1f4a776332d1e14c2b8568c315f3c86a0efc))
* Add campus and capacity while importing tutorials from csv ([1f9bf57](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1f9bf5718da7912db16ce82e0817fcb754894931))
* Add campus id to add tutorial ([863507e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/863507e051faae7d9990fe0a8da09d43731457e8))
* Add capacity to group set serializer ([023d14e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/023d14ec8cb14da560dfe40e9ab6564022342c26))
* Add ccheccks for group tasks on batch marking ([09f4da3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/09f4da367128a8fde7b6786133d06e0d1e711878))
* Add check to ensure some rake tasks fail in production ([2c2efe3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2c2efe3ed0ac4fbea96696d159536ccc67b549f0))
* Add comma to assertion ([0e28203](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0e28203624bb6df4a423f8fffccc9df6cf9adb46))
* Add converters to student import ([7da182f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7da182f61b75615d9712b219eaa53bceb86e6443))
* Add correct conditions for recipient ([75b56e7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/75b56e73b5bd377907bde43a94d30b51915c8acd))
* Add correct conditions for recipient ([2f61e80](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2f61e80d334e64e97b371780c2a7fe6db4b152b0))
* Add correct table names to migration ([20a5824](https://github.com/doubtfire-lms/doubtfire-deploy/commit/20a58240789b4dfb850903506a48390af0aecea6))
* Add correct table names to migration ([a8f149e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a8f149e00c41e5787e93bcb2e6fb29930faf644d))
* Add correct validations to TaskComment model ([f6662bc](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f6662bc0b75c3553e3cfb972f24efacb0bb073ee))
* Add default coment for audio and image comments ([3b63a5d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3b63a5d27589ff2fb7cd6dc586461fa5e7b3dea5))
* Add exception details for unhandled exceptions to log ([eca1389](https://github.com/doubtfire-lms/doubtfire-deploy/commit/eca1389e352bf460500d0dc3424325c42e16a423))
* Add from_existing_unit to duplicate task def call ([7096cae](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7096caeb727cb861a27c4baa072038b8d407919f))
* Add guard so only one team member can submit at a time ([2a43a35](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2a43a35346378e9c3c82a6034e295846579b2c62))
* Add lock check to permissions on group set ([58baed3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/58baed3cf795df6ef27d9895955d177b553d4e31))
* Add log info to report MOSS urls ([fb7d859](https://github.com/doubtfire-lms/doubtfire-deploy/commit/fb7d85988c91a8e4e8a3a0de1766a3e8a86e9b15))
* Add migration to extend text size ([4947bbd](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4947bbd103cdb75de4eab486a66181266dfbe345))
* Add minitest-arount back to gemfile ([b1a1b95](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b1a1b955379dd606a731b25ae4b013d3fcda9fae))
* Add missing bcrypt import to user model ([dafaac2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/dafaac282e68f29a952a1441df6982370cdf617a))
* Add missing bind option to accept all connections ([200b0c9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/200b0c994c699fab78c356d7c497351050f47433))
* Add missing comma in unit permissions array ([ea89bdb](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ea89bdb822cf5be99bb9fe433f1219d455ac1d34))
* Add missing comma in unit.rb ([36c4fac](https://github.com/doubtfire-lms/doubtfire-deploy/commit/36c4fac7c04b50e4db1f7de12540a9206e858660))
* Add missing copy of files processed in accept submission ([c87c016](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c87c0164db298b11e80e7cdb20e505fe830312c6))
* Add missing CSV header ([4a57bc5](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4a57bc5ab2c4b2b7e730f4f31b36d4e1b59f2be7))
* Add missing default on extend_authentication_token ([2626b99](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2626b997228258a7b665ababf5be00730d6d5bff))
* Add missing desc: parameter in tasks.rb ([153a71c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/153a71c9785637e2e8ca3fb08dab393c8e60f52b))
* Add missing grade to shallow task serializer ([1620b00](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1620b000d54031584ce88c4f313a4f116836c515))
* Add missing logger to PortfolioEvidence ([8cf4ee9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8cf4ee933099dffa756dc43e7d8a05f963ab92d6))
* add missing migration for unit_role change ([714a9c7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/714a9c7428c7441394c7100544cc2499bfd3389f))
* add missing migration script ([bf77914](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bf77914037ed1db987831d004da1568095da96a4))
* Add missing module function for put_json ([bcedfd4](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bcedfd4021ca304c63ec55edd4f3d534040d009a))
* Add missing module function for with_auth_token ([3f2db3c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3f2db3cd9acf7eb964cc7b2d5710f36f787d144b))
* add missing optional task parameter details to learning alignment api ([e760fe8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e760fe8ad6007b83e7a9d2a1ba61e00819c14293))
* Add missing password setter for dev environment ([99f5b4e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/99f5b4e56719e26c5312396df8dc2473c02975ed))
* Add missing RAILS_ENV for docker api ([8db9e70](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8db9e701f565d9bd76beb5106e50a6725081c73e))
* Add missing self keyword ([f4be643](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f4be643108b30cf43877d3342341837288712f46))
* add missing serializer ([a11029a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a11029a4f2e63aca98af381ccd76fed8241df967))
* Add missing static function returning singleton logger ([c7d0d33](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c7d0d33e53745d3145ebf08e89c81f134afa62e2))
* Add missing static function returning singleton logger ([28b4cd7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/28b4cd7f932f06f82733fb74348e5ff80de48bac))
* Add missing status weight for time exceeded ([0fd4aaf](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0fd4aafdb9b52b6a8cca5a858fab0bdced847445))
* Add missing task argument to task script ([e1847a8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e1847a84d097070a087292b797e7b9847a212d64))
* Add num_new_comments to shallow project serializer ([cc54dcf](https://github.com/doubtfire-lms/doubtfire-deploy/commit/cc54dcf456a4937c2eca8b37cca686fbfad91e93))
* Add permissions for admin and convenors to exceed capacity ([4dade19](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4dade194c6af3ecfcb8843bb1dc21eb726654050))
* Add post test for group_sets_api ([185ed0f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/185ed0fa0bcbbca774cea1230dea9c8c67eaa3c8))
* Add required start_date to populate script ([b628cfd](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b628cfd707a6a5659daa2b21eb7ff09acd6b0a80))
* Add rescue/ensure block to ontrack_receive_action ([53d8d3c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/53d8d3cf0dfe5353cdfd73bcf222088efea2bdea))
* Add seperate DB for minitest tests ([3448abe](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3448abeaa3973afb92024d97a0abf88609789d9d))
* Add seperate DB for minitest tests ([dd676fd](https://github.com/doubtfire-lms/doubtfire-deploy/commit/dd676fdad9113b362669f920fe9a7673a6282481))
* Add similarity count to task inbox/feedback API ([2108db2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2108db2e2dfb27754c7cd196cc499513bd710817))
* Add space in between nickname and name for project serializer ([0072400](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0072400bf7e27d3cfaa8b69dd8b628cb4d6cc1d7))
* Add sql file type and move mime types checks to helper ([5f33ac5](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5f33ac5e40e15f041eaa028f5cb5eb9be7a31b51))
* Add task definition validation before update ([c4f950a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c4f950a41192739106bf549d7b3be9d2ddd01ffa))
* Add task_comment_id to where validation ([472b0e6](https://github.com/doubtfire-lms/doubtfire-deploy/commit/472b0e6edc25e4de301bb004880e84548bfcfa67))
* Add task_comment_id to where validation ([e44557b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e44557b55da99cbb98eb33b05f0c562e19e60e8d))
* Add tests and fix issue with rolling over group tasks ([c4825d0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c4825d0940063ada6f248ef5139ceaa06cdd808d))
* Add thread variable for current user in task serializer ([c704dde](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c704dde54d1b5d7c74d0951620d847757a593a76))
* Add time exceeded to ilo scale calculations ([91082ba](https://github.com/doubtfire-lms/doubtfire-deploy/commit/91082ba0a949902c5996c8a561b01a223a26cdc7))
* Add tutorial stream to task definition on create ([1c9de29](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1c9de294375fc5c9acb859c634a353dc0e53b50e))
* Add ui changes to handle sql and vb files ([27d5e21](https://github.com/doubtfire-lms/doubtfire-deploy/commit/27d5e21c9d1e6e6fb395ec16fef0af543947b7d6))
* Add units to teaching period serializer ([71c263c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/71c263c2d3897869850a9d5480cdc0ad40537c71))
* Add user parameter to feedback test ([4dca03d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4dca03d3d5cea4ef1b7a4c7cef63cf32a5d6d252))
* Add validation that weighting must be present ([2bad398](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2bad39804da58e67b41bb58e40a98b3dbbc9b5f0))
* Add validation to check uniqueness of tasks ([0be2114](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0be211445f24afb8075795bc2f19d6c6d3b48716))
* Address issue of breaks updated in the wrong teaching period ([ef2700c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ef2700cb5c66a2e59907699b341d969776053631))
* Adjust dates when current teaching period present ([b1a5f44](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b1a5f449f83fba655749c2232f201eeeb28d0fa5))
* adjust error message on comment post rejection ([61e07f0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/61e07f01febb609eceee42202a7984990ff47dde))
* Adjust faker unique clear order to attempt to address duplicate issues ([8fc016c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8fc016c5e2966cdf1543cc383d603e8baf8b9c79))
* adjust filters for portfolio tasks ([08c7fa5](https://github.com/doubtfire-lms/doubtfire-deploy/commit/08c7fa580d5815130c247f0af5ee38759fe18805))
* Adjust force ssl for staging and use in AAF redirect ([55aaae1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/55aaae172ca451ec47706102c4158a9e72bd91e3))
* Adjust force ssl for staging and use in AAF redirect ([7c39055](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7c3905543fadf8ed178d28d22541d249b210130c))
* adjust processing time for ghostscript to 30 seconds ([83cbcb2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/83cbcb2e62c2d330014aae386ce5998e88aba261))
* Adjust pygments language to include python and use extension if unknown ([1d7ecda](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1d7ecda50da6c60c18527a3cbdfbdca411b19079))
* Adjust task test to make sure full path is used in tasks test ([1bdc229](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1bdc2291bf9f7cd1923e56c5080e1653964714ba))
* adjust upload file limit to 5MB ([d0fe0e3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d0fe0e3bf5882f5ef3156a9603b193ffa9cbdb20))
* align overseer assessment with single assessment comment ([25dbaf8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/25dbaf802a410863d44db26192511788988728ee))
* allow alignments to have no description on import ([ad8af0b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ad8af0bbfe59a461fbbabefc382fe3c97524df4a))
* Allow development to redirect AAF auth ([58381ec](https://github.com/doubtfire-lms/doubtfire-deploy/commit/58381eceb81c56223f4602e0998f77ea53f32c0b))
* allow due date to be optional on task creation ([85a7262](https://github.com/doubtfire-lms/doubtfire-deploy/commit/85a72623f8a1d4d0309e90d51a54eaa1d1103530))
* allow grade_task to work without ui from csv upload. ([8768dc7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8768dc72c289d2ec55f195d74312f34067674815))
* Allow indifferent access to institution config hash ([6d04780](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6d04780908b08c4acbd30d94c4ff60f6c8d34d38))
* Allow institution imports to customise tutorial change behaviour ([574115f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/574115f5a93bc32b6588139d471119e34522c3b8))
* allow portfolio tasks to include some tasks in higher grades if they are included, aligned, and have a PDF. ([8db0ee2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8db0ee2a986b03ec404e4dc44c30268d5a555bec))
* allow portfolio tasks to include some tasks in higher grades if they are included, aligned, and have a PDF. ([43bf33d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/43bf33d46d50237c841684758b223045dc65ab69))
* allow portfolio tasks to include some tasks in higher grades if they are included, aligned, and have a PDF. ([ed87a77](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ed87a77029bc34ec61c262dfe50cd2707693b119))
* Allow protocol to be included in host configuration ([142d80d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/142d80d78a71d5fd33a87bbd64e0f348f15e8d58))
* Allow special characters in task files ([eb2adb6](https://github.com/doubtfire-lms/doubtfire-deploy/commit/eb2adb66119121bfe0b8b0db054adede778ce6a3))
* allow students to work on group tasks independently (task status) ([17d226c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/17d226c567624fd61d1aab87d5f2eb5b6baa476f))
* Allow text file upload for code ([f5207ed](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f5207edc2a48c9803e49750f918ace120e19a361))
* Allow tutorial to be set to no campus ([8f9076f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8f9076f7894ff396ce100ee4eb61e753839a6410))
* Amend API URL to Deakin test server ([92c83a5](https://github.com/doubtfire-lms/doubtfire-deploy/commit/92c83a560784953a25d7a5ae369bd04fca7754de))
* Amend API URL to Deakin test server ([8be1064](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8be1064d9fc7f6e436f42a0b1436077326a267f0))
* Amend incompatible Ruby versions in Dockerfile ([297d025](https://github.com/doubtfire-lms/doubtfire-deploy/commit/297d0251d2c3128aefa4e8974f6b443ce7bb6844))
* Amend invalid migration for is_graded ([cdc3a0f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/cdc3a0f43b2143e2a7625cdba85309f5d360b794))
* Amend invalid syntax for grade_task method ([f1f17a8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f1f17a8aa92dff92e43cdc06480cdb449a9d5260))
* Assign and use expected_auth in put test ([14b8a5f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/14b8a5f995b17a28283c69f3ecbd5da18f05e593))
* Attempt 2 at converting active to boolean in Project api ([ccaf855](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ccaf8557e7df25d479036028919fcfb351226ac2))
* Attempt 2 to convert Project active to boolean in MySql ([f93b0c1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f93b0c1e3c5412c007ffb0d42be8bd1402f17e2f))
* Attempt switching group's tutorial only if tutorial ID specified ([546a9ce](https://github.com/doubtfire-lms/doubtfire-deploy/commit/546a9ce914c5108f901421d673c68f207f5e421d))
* Attempt to fix username factory issue ([701f8fd](https://github.com/doubtfire-lms/doubtfire-deploy/commit/701f8fddd4aeaf5ab4b7712c90a75dc5bcd1d9da))
* Bump web server with latest changes ([dcbec16](https://github.com/doubtfire-lms/doubtfire-deploy/commit/dcbec167d8e0e6b9f4db747a0842e0a3ae637092))
* Bump web server with latest changes ([8510870](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8510870bd8a852aa86af115f9f1e3f66be5957d7))
* Bump web version ([bf34e28](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bf34e28de0502f6c40ec731088c81324c6453371))
* Call add_teaching_period before the save ([1a113ce](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1a113ce66554746c5c2b0bfbd81b77a07ae07e0e))
* call to student_target_grade_stats ([f6b49f0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f6b49f00cb8ab9d7b80a4359ea9c0df284dbc79f))
* Cannot destroy a campus with projects and tutorials ([e9af00b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e9af00bed40621da80441999f8111a8dc413833b))
* Change copy of files to move dir ([13fb77a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/13fb77ac5e2b25daf0b35bc827f9a55b11a9c0be))
* Change get tests for group_sets_api ([65099e9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/65099e92291ba77e7eb3d91fa55e358440181850))
* Change get tests for group_sets_api ([bee0ba1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bee0ba1b2c8c3e1440a9cf02b9d7cf3f85fb0c10))
* Change get tests for group_sets_api ([702c367](https://github.com/doubtfire-lms/doubtfire-deploy/commit/702c367b9837db770031abc9c538c841c1f7a12e))
* Change get tests for group_sets_api ([16ab11e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/16ab11efdf9c11b5413e7013f0dcbdd7b66e1fdb))
* Change get tests for group_sets_api ([f59848e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f59848ef8428d58bb524f30861315657dda4bc05))
* Change get tests for student_api ([ce04c12](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ce04c122e5eb6e2d5fd0a9f0f0d836bcf03df33c))
* Change get tests for student_api ([00abdc7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/00abdc73630a1b6145ada0c686746a07db1cd98c))
* Change get tests for student_api ([1b1e691](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1b1e6915cc6d21dbc3e0e223dba82ffc7d737ae6))
* Change get tests for student_api ([3aae341](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3aae3415ac6e755d66d7683638ec3827c2d4db50))
* Change get tests for students_api ([b86964f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b86964fccc2010ce25fc7ae2dae8145e97cc1fd9))
* Change get tests for students_api ([efde42f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/efde42f5c71e01ec2389738470b753979975b6c6))
* Change get tests for students_api ([0eaac76](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0eaac76c6eccc7277c83b03f60dcdfd5bd6c2517))
* Change get tests for students_api ([2f8c7cf](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2f8c7cf087ac5b49ea4edd6a902f73929188c6c5))
* Change get tests for students_api ([5163a71](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5163a717050fa27ea806592692eb3767b2f20845))
* Change get tests for students_api ([53131cb](https://github.com/doubtfire-lms/doubtfire-deploy/commit/53131cb379f193228e9958fa331de887e9918f0a))
* Change get tests for students_api ([e77f8e7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e77f8e73cef55d753428d7c80a8eb1f7f93d37b5))
* Change get tests for students_api ([4d92402](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4d92402a4e446a11948205d94e97b9d5ba0034ce))
* Change get tests for students_api ([1b3e6de](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1b3e6de7041578aef4704a6180b2dd6d2734c544))
* Change password back to what it was ([73e6bd8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/73e6bd884f6a558dba1a099f20e235558f5a1a1b))
* Change post test for group_sets_api ([dbc8aa9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/dbc8aa9040d33ff39e3017e3800fe515180161cd))
* Change post test for group_sets_api ([50bc51a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/50bc51a32a5dac25906f09bff33595d361f58b12))
* Change post test for group_sets_api ([3a0abab](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3a0abab04c8508f526fd165fca405a2e20868083))
* Change post test for group_sets_api ([aee466e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/aee466e6106b729559958c922784aedb4a23a266))
* Change post test for group_sets_api ([bed8bbf](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bed8bbf429f20347c10e32d200ea35c3759b2438))
* Change post test for group_sets_api ([bdd3085](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bdd30859badec6a3435078f881792b3b52718493))
* Change post test for group_sets_api ([bcf9cc9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bcf9cc9ba03a6eb08cbf12537649f3690ee073fd))
* change task sequence to use start date ([fff536d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/fff536d34754d3f0b96fc08d05282a68c805bbac))
* Change task_definitions to support date submitted and count ([de6138d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/de6138d74cbaa8a075d18f7826016487b888e893))
* Changed string quotes ([d8f21a6](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d8f21a6ef22e917cbbc2d0ad16249057d9d5ac6d))
* Changeget tests for group_sets_api ([efb4295](https://github.com/doubtfire-lms/doubtfire-deploy/commit/efb4295b67fa23191515c3f8f540107d882e1b89))
* Check error count of b2 in test break not colliding ([34b24d9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/34b24d936e7621ec318180014a342ef0fa2e831b))
* Check file upload on unit student csv ([724e1c6](https://github.com/doubtfire-lms/doubtfire-deploy/commit/724e1c6c4253cd57ca8f766122dda67909e4cd40))
* Check if path exists before removing in zip submissions ([feb2e30](https://github.com/doubtfire-lms/doubtfire-deploy/commit/feb2e3002ac80a543e9a3e9dcc6778911c399cb0))
* Check if task pdf files exist with . replaced with _ ([91d869d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/91d869d4ab381e42aec2629fa9fdfab0f6d2fb20))
* Check if tutorial stream is present before serializing ([01ca99a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/01ca99a51116f7dc7df6f0c91ef49498c4ba06ef))
* Check object has hasKey? in group serializer ([d836d3b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d836d3bea687b63ecabe86f136556046902d9e77))
* Clear and update plagiarism data on td change ([9ff0792](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9ff07926139721ae75a4efa6fe8916a8d9478b61))
* Clear and update plagiarism data on td change ([e88b59b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e88b59b37da913243fa65b11314d7afad6904a37))
* Code in test unit import file ([9a15317](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9a153178c1393b88d3d712fc7d20e61843bd3f13))
* Comment Serialize ([d3ff751](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d3ff75158df2f9ae5862bb2ceb10d01ca187fc1f))
* Concurrency issue with project tasks duplication ([952c213](https://github.com/doubtfire-lms/doubtfire-deploy/commit/952c213dd749b0e695a6c746f5ceb39a1d97197d))
* Conversion of file encoding for code ([80fafa8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/80fafa8421b2b85a52d1fb2cdb0280e4e6370856))
* correct API for getting task status -- return data in task/tutorial groups ([13c8e7f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/13c8e7feccd6ba0381ed904f96557a357e0a6b5c))
* Correct auto extension param syntax ([bf7b512](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bf7b5128adc1dd6d424fb9e608264e6e4950eae6))
* correct convert submission to pdf to use new folder by default ([a4ed642](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a4ed642cf4c4db29b01e14319a3652314126c972))
* Correct CSV tests to use new response codes ([21f7d3a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/21f7d3ac2a1aa3c27260e1f5bc4162d5a148e8ec))
* Correct date range for ahead tasks ([2edb15e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2edb15e7156f212e44ec0d6249e4e5f5474a7306))
* correct development redirect url on aaf auth ([badf14f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/badf14f43542bd30759708d68a3756d0801d4cbc))
* Correct enrolment into groups restricted by tutorial ([5c715fe](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5c715fe87948d4a8ae48146905934146fbc1f538))
* Correct erbs with product name ([7a8ef48](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7a8ef48662e6ebe2b0f2df5f078e98104205b494))
* Correct error message for grade fail on task ([3c6ba6d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3c6ba6d02340d372887aebbf5c93149e151ff0ef))
* Correct error messages when group or groupset locked ([d48aced](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d48aced49dc2b14b539609b7e56eed7f3f73c068))
* Correct error reporting in sync enrolments ([76b0334](https://github.com/doubtfire-lms/doubtfire-deploy/commit/76b0334b925c421d48a083ee9fa66826cd057a84))
* Correct error with checking mime types for a file ([6a5059a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6a5059a14d8107b83a1a743e227915ad3d2ccbb2))
* Correct extraction of tutorial id from params on switch tutorial ([3aa75e0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3aa75e00a31ab7d6e5d0b2ce53603d02ad8eec7a))
* Correct file name of portfolio in zip ([a498fa3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a498fa32630174c731068bd7f3eefe008d262fca))
* Correct filenames for task sheet and portfolio downloads ([2bc28a4](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2bc28a4836b012bbde58e708a7304e9927b2220f))
* Correct grade of time exceeded tasks ([962b7e6](https://github.com/doubtfire-lms/doubtfire-deploy/commit/962b7e63497f42cf67916cdced19d3495fd91af2))
* Correct group modification when same tutorial true ([c824d44](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c824d440308afc8f2a2155c9784ec89ed5565a0d))
* Correct group serialisation of student count ([0721277](https://github.com/doubtfire-lms/doubtfire-deploy/commit/072127766b182c30634530f78f754eeeb50fecf1))
* correct hard coded path to overseer instance ([627d257](https://github.com/doubtfire-lms/doubtfire-deploy/commit/627d2576616be6e7de52d17cc106deb1df105d35))
* Correct importing of task definitions with groups ([f921271](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f921271402fc7415ee4228c1379809648c82942c))
* Correct indentation in sync code ([636e21c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/636e21c231018515c2723c6b3722ea0da21f10ab))
* Correct invalid code within group set test ([4ee7d46](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4ee7d46dad21273999481a2caa76e425c847ae08))
* Correct issue causing task feedback test fails ([b59e868](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b59e868830e335cb3ea54b0a0ebae0b97f584c45))
* Correct issue in breaks api test ([3fc3e4a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3fc3e4ac10925025e5e2764c2e7f446b61aa789d))
* Correct issue linking students to timetable data ([b71e355](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b71e3553213484674e63a507b51883bc1ce8393c))
* Correct issue when no tasks failed to query students ([72158f8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/72158f83d4a65f5a34a41bc974aafa95b9456586))
* Correct issue when uploading empty comment attachment ([e59b7d8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e59b7d8fdb28d0a688321e9cf757fe234b8653ca))
* Correct issue with adding auth token in tests ([3c8b12c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3c8b12cc0f192e54043d4e2dd887290bbcedcdf4))
* Correct issue with changes to group task with extension test ([8152dfb](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8152dfb4255e9830435fc7a5c52c3423f3158439))
* Correct issue with compressing images ([74bc733](https://github.com/doubtfire-lms/doubtfire-deploy/commit/74bc7332987803bc940cf7b47c1792f09777828f))
* Correct issue with concurrency bug on team submissions ([b21d7ec](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b21d7ec003b55e6dc25374e1a251e8db0f14bac4))
* Correct issue with conversion of due date to day based ([dec0d4a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/dec0d4a4ee65498598c01ef59b518265da1da5ed))
* Correct issue with creating users failing as no password ([7f5d3ba](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7f5d3baf87fe4ebe49dae4a74949ff9315e3746c))
* Correct issue with delete and foreign key relationship for breaks ([17c6e5f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/17c6e5f2ddcc352c642d68c04821814557bd4466))
* Correct issue with duplication of cloud tutorials ([6fa167e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6fa167efaeae6b6387ed9626b4d8de903537b3cc))
* Correct issue with empty alignment rational ([63aa732](https://github.com/doubtfire-lms/doubtfire-deploy/commit/63aa732d98d381189dc7eb237042deae52b34ab5))
* Correct issue with limiting tasks by grade in unit student tasks ([842ca5b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/842ca5b0e620dcbac428af3236920a471d2ba9aa))
* Correct issue with name of new tutorial stream ([456e829](https://github.com/doubtfire-lms/doubtfire-deploy/commit/456e82966ab279d656e728c90b33ad8130000313))
* Correct issue with pdf erb ([b6a263a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b6a263a50a817979c4276b4ee91a321716050167))
* correct issue with populate script failing ([4c94a88](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4c94a884437e44bc7bdffd3ddd3a09ad4922d98a))
* Correct issue with portfolio creation ([8dabf0c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8dabf0c17e444567a0a7b32be249090335d391d3))
* correct issue with student created task alignments ([b11eda3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b11eda3fb07fa3024e7257051d94b4b638742d2b))
* Correct issue with task completion CSV ([ad2ba69](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ad2ba6993798c4f10ccf634210ae1a0f9dcfe1a9))
* Correct issue with task pdf creation ([9f0e2e7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9f0e2e72bf38b0d481013637a5c1257f32ff7547))
* Correct issue with task stats including tasks for higher grades ([7d29f65](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7d29f65bfa7afe23924fcd820e7b61c3337e5631))
* Correct issue with tracking of task submissions ([3fa2d37](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3fa2d37d2cb80f8818413ab375b3abc66b2cf381))
* Correct issue with tutorial enrolment change validations ([b43ace3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b43ace3f955a69bc2077ddefbb8a88192efe2221))
* Correct issue with use of unit in group import ([07ab84a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/07ab84a8f88f22d732ab19c39673b63745ca1a50))
* Correct issue with variable use in enrol ([ad99b16](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ad99b165f91e893dcbf086b4d777670a03e218d3))
* Correct issue with withdraw students ([a517502](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a51750298f917ec3dd4730481fefc70c180eaa79))
* Correct issues with role checks to ensure all paths return values ([4c6f69e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4c6f69ebb4354fc6eb36f017d8468df837387394))
* Correct issues with task stats inc withdrawn students ([b95de0f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b95de0ff4c336e6b6a509840fc327e05183c8740))
* Correct issues with task status tests ([5b9eab5](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5b9eab51de337377ca1807b570c9d9a56b25f085))
* Correct logging of stream in timetable sync ([93e4728](https://github.com/doubtfire-lms/doubtfire-deploy/commit/93e4728487858fbe27a4a698527cdaefe40bd75c))
* Correct logic error in group membership ([f6bd82d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f6bd82d0cf803d04eaef1372d21f188be90d0408))
* Correct missing end in settings ([5e9af5a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5e9af5a975ecc70a43acb6c9c0479379916e63c8))
* Correct order and remove typo in unit ([5bd67b9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5bd67b99482a10b956eef2c4c82163b988459dcd))
* correct overseer env settings in compose ([1daabe8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1daabe800ef1cafd36b2391dfcdce2e8e03012dd))
* Correct placeholder pdfs and responses when files missing ([a16bed7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a16bed7c59e64dc5310a4b9c558cec87f431f158))
* correct port for developemnt to use 3000 ([778442d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/778442d146ad7db35f7182ae5d9be53bab44aabe))
* Correct request in skip prod to use STDIN ([6c2c8ef](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6c2c8ef0d1d985b151f38995c430bebbcc892158))
* Correct return codes for csv tests ([d490faf](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d490faf88111dff60225c33152a491eebb809abb))
* Correct schema version ([6fcc3cb](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6fcc3cb2681a46009c0f05b867e5dbbfdd44cfd1))
* Correct sending of portfolio emails to come from main convenor ([91ca609](https://github.com/doubtfire-lms/doubtfire-deploy/commit/91ca60905cf9a72d9390bea599c91bedb6dc8176))
* Correct sort order issue in ui ([69d176f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/69d176fac94b3c3862611e14b14649c3a6798840))
* Correct star import creation of tutorials ([f046233](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f046233fb8df851bd767d76b826adbd1568631dc))
* Correct status upon submit ([987b37f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/987b37f397bc9d8cd12546751f6dc000b0b520ee))
* Correct student list query to ensure all students appear ([5ee1cbf](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5ee1cbfd63866486ecf6e987fe8c62ddc106f2bb))
* Correct student tutorial list ([ad4ec4b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ad4ec4bc22cd8b2230db15a8858664c45e166c50))
* Correct sync enrolments with to work with tutorial list ([98c6f3b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/98c6f3bc1047e3620753228eaf4b4bb8b5323741))
* Correct sync of classes to only skip if not in streams ([2d6b3fa](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2d6b3fa4bcb8631a21694f53a298b5ed192b1ed7))
* Correct syncing of cloud units ([4dc96bd](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4dc96bdba1e5f111626af47ec4439c8d374c6ad8))
* Correct tasks API for steam changes ([a00743c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a00743c095ccb60f3637ad41b1a3fe95208eb809))
* Correct tests to make use of FactoryBot ([73e1833](https://github.com/doubtfire-lms/doubtfire-deploy/commit/73e18331a6f23946573b5224f2b9d54f60666635))
* Correct tests to use FactoryBot ([5601b5d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5601b5dd813f21b4648a1e33f5c430c3fe385847))
* Correct tests to use FactoryBot ([34947fa](https://github.com/doubtfire-lms/doubtfire-deploy/commit/34947fab17ffb385c963c186418c91c05fd56f0a))
* Correct top tasks and revert to use extensions ([516edae](https://github.com/doubtfire-lms/doubtfire-deploy/commit/516edaea2291657ac2951fd50138d21c7e4c25e7))
* Correct tutorial tests ([8cae99e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8cae99eada4155aced1df4d22336456639273b23))
* Correct typo in tutorial day for cloud ([9417915](https://github.com/doubtfire-lms/doubtfire-deploy/commit/941791520b0d942a433b253f0519805bf2c8b786))
* correct unit role serialiser to work with or without start date ([f6b75f1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f6b75f1dabd48f8aef993bc4e2494d953c332efa))
* Correct uploader to allow txt submissions ([1376716](https://github.com/doubtfire-lms/doubtfire-deploy/commit/13767167a63af75e96f98a7408b2d86d0ad09013))
* Correct use of project tutorial id in summary email ([ded0868](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ded0868074592c35362aeb4eaaea8912d62a9d02))
* Correct use of tutorial enrolments for tutor assessments ([0fff45d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0fff45dd0d2240794c1c1e6548031527fd83c135))
* Correct user import to avoid error on blank row ([1761c57](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1761c57a91d0d8fccbd0ebf61f5048a1d75619cf))
* Correct username from Deakin STAR import ([7332810](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7332810d2cc07a4df848aabee1038d460974f077))
* Correct validation for tasks past deadline ([58e02b3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/58e02b3f51b97d43833611231c76144c2d903040))
* Correct variable name for allow revert ([8a4272c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8a4272c4c03592c44c1e7ce9477777377aa0888c))
* Correct variable name in task def tests ([6a6591e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6a6591edae50df06b61235624fb08c0534a5017b))
* Correctly reference host symbol ([5af5c3d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5af5c3d8615da37c5e06e89f2b48584b542e1cf5))
* Create 1 enrolment to avoid duplicate error ([908a455](https://github.com/doubtfire-lms/doubtfire-deploy/commit/908a45535da6ceeed87f5e07a603914e4aa17320))
* Create Teaching Period before rolling over ([f5a3e8a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f5a3e8a284e53334a7c862815ee2433a47e6c3e7))
* Create tmp portfolio dir when copying ([08ba248](https://github.com/doubtfire-lms/doubtfire-deploy/commit/08ba2482783ef474583ffca728edc6d5a53a112f))
* Create unique username and password ([4584380](https://github.com/doubtfire-lms/doubtfire-deploy/commit/45843804d32fcb8f0b524c6c25656143408e9353))
* Date format in latex ([26b36b5](https://github.com/doubtfire-lms/doubtfire-deploy/commit/26b36b5f7a9dd9b865950680cda7d3c5fc19949d))
* Delay redirect for token time out ([176d407](https://github.com/doubtfire-lms/doubtfire-deploy/commit/176d407dd334a51cf16786139ae8ce975d02cd00))
* delete useless code and useless test ([8db1523](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8db152336f7b7c5f68cea82d06ad3aa060583a64))
* derp... add migration ([c46b21d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c46b21daf9550e7bdd24d2d28cad488bd0ebf34a))
* Determine the content type of attachment comment ([ef59b02](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ef59b02b62062422f537274d413bf5a7099fa615))
* Do not create tutorial with empty string ([df54b02](https://github.com/doubtfire-lms/doubtfire-deploy/commit/df54b0235d54e67c3afc79c42c99c125ed2fd2c0))
* Do not recreate zip downloads if they exist ([9d6d269](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9d6d269b8f95e2c1b98ab967c8992798af29aa50))
* Do not resubmit name in database ([087f0ce](https://github.com/doubtfire-lms/doubtfire-deploy/commit/087f0ce0a740d78d94ac88ac70951e7f0c5dd6c5))
* docker-compose.yml ([48ec2e6](https://github.com/doubtfire-lms/doubtfire-deploy/commit/48ec2e6f67ef06999755f87cc5beed2e4fc9b7fb))
* Download tasks for task def ([7b163b9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7b163b9df1667208e8cae2fe3d74ff9604f886fa))
* Download the task assessment resources authorisation ([d2ae227](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d2ae2274d9f73067b5972ccf251933e7077773eb))
* Email validation for user model ([b7ef5f2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b7ef5f2eed8a7753ced4662d1feff8d1735ac132))
* Enable comment attachments for group tasks ([9e138c4](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9e138c46611ecc77cad195ef74dfb2f8f32e031f))
* Enable video/webm audio for chrome recordings ([ba9ef6b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ba9ef6bedef9ae5b3dcbb3678d253cbf123085c9))
* Ensure a project only has a portfolio when it is available ([5ec938c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5ec938c69716a2178979f6bfd8a06baaeb1a2e3e))
* ensure achievement stats include 'all' students and work with small numbers of task completions ([21fd3fc](https://github.com/doubtfire-lms/doubtfire-deploy/commit/21fd3fc61a9216b90479183c9aba4ed1dcd1836e))
* Ensure active is returned as a boolean in projects ([98223fe](https://github.com/doubtfire-lms/doubtfire-deploy/commit/98223fee7b85bad297bb4bdccfdd6a65e4723edc))
* Ensure add_auth_token respects user provided ([16e1b17](https://github.com/doubtfire-lms/doubtfire-deploy/commit/16e1b179f4bcc8af606fb79c6756952033a307b6))
* Ensure add_response methods return true and cleanup temp files ([80ad993](https://github.com/doubtfire-lms/doubtfire-deploy/commit/80ad9938e72dadf25aa8b61f8ddac86d92a3d16b))
* Ensure all images are converted to jpg on upload despite filename ([007cb32](https://github.com/doubtfire-lms/doubtfire-deploy/commit/007cb32c2c6812e12f6853b9e1e081d8649e67bc))
* Ensure all latex escaped text is raw in erb ([527185f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/527185f064e66223886d3def0ae12ecf65f6dd8f))
* Ensure backports is only updated ([cb04e40](https://github.com/doubtfire-lms/doubtfire-deploy/commit/cb04e404870f0f6f215d5cab95309731496c7d2e))
* Ensure better timeouts for PDF creation ([810611b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/810611bdfd50802a1eb61bb67165752abc131e2e))
* Ensure better timeouts for PDF creation ([9895773](https://github.com/doubtfire-lms/doubtfire-deploy/commit/98957737c3c4dcd5842dcb7dc5f59b63a92e6198))
* Ensure break is added after save ([59c0e00](https://github.com/doubtfire-lms/doubtfire-deploy/commit/59c0e005e81addef8e601846d048300255398392))
* Ensure campus is correctly cached ([b1d546b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b1d546b46b5872773c252e8d94f615684dec7f4c))
* Ensure comment type defaults to text ([52531ce](https://github.com/doubtfire-lms/doubtfire-deploy/commit/52531cee0ddda765d87872414d25eb8620a7c715))
* Ensure comments are not saved in transcode fails ([869cb9e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/869cb9ee0969c6de0ca76e0adf55a02cd91dea5a))
* Ensure comments are propogates for comments when group ([769cc13](https://github.com/doubtfire-lms/doubtfire-deploy/commit/769cc13cc1d465aafc20ca164182555f532b51a4))
* Ensure comments can be deleted across project teams by tutors ([8dca331](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8dca331969d00f0f6562edc77546a113e2962a16))
* Ensure compress returns false if zip does not exist ([3a261ee](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3a261ee508d7cdee910eae3e7f7b9f67fdb23a7e))
* Ensure correct files in the zip download of tasks ([16f3035](https://github.com/doubtfire-lms/doubtfire-deploy/commit/16f3035501989f5211607112b072776fcb1283df))
* Ensure correct propogation of status comments for tasks ([6acc140](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6acc1409ac73e5806cce4f3e8df3ee5cadac53e0))
* Ensure count is before date in should revert test ([7dbce57](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7dbce57b156a89d9e06b0cdc3336382353f294f2))
* Ensure created messages are read correctly ([da3984c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/da3984cb2636ded1fbce96bac7ba5e9e632423f8))
* Ensure created_at is only accessed if the comment receipt exists ([5b8a6d1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5b8a6d111e88d869885fa055dd5917928044ed57))
* Ensure CSV check works with Tempfiles ([1349ca2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1349ca29825f249a1a316f64fccd21f7b3b2faa4))
* Ensure date checks work in invalid cases ([87a8d09](https://github.com/doubtfire-lms/doubtfire-deploy/commit/87a8d09f90e3e727226540a84bc5b1339bbbe0ba))
* Ensure db populate can create user roles and task status ([e030f1c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e030f1c52f7ae710a7f866192118f4d828491229))
* Ensure db populator has ULO ratings between 1 and 5 ([04e4689](https://github.com/doubtfire-lms/doubtfire-deploy/commit/04e4689df5f64edea2582dc23e44aadf4007f1f4))
* Ensure deleting a stream deletes tutorials ([f089700](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f0897007fa3e6aef4dfb3fc68a1038279ad34091))
* Ensure DiscussionComment is returned in post ([4556d50](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4556d501440b3846d7465aa2bd2ff1e8f3df88a8))
* Ensure docker image installs bundler ([26110d7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/26110d7eddae3e490c76ff3b6363912bd82ab2ea))
* Ensure DoubtfireLogger initialises with nil ([04fe736](https://github.com/doubtfire-lms/doubtfire-deploy/commit/04fe736f35d29db67f29bb6afe1d58ad52b6fadc))
* Ensure DoubtfireLogger initialises with nil ([f52816d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f52816ddf0e1ddab90b8f8b40bcacc882e4cb9c2))
* Ensure duplicate student ids raise exceptions on csv import ([e039b84](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e039b84b7fa3fb0ec5d5430ab919f24c7ebe7157))
* Ensure empty groups can be returned ([aa305cc](https://github.com/doubtfire-lms/doubtfire-deploy/commit/aa305cc81ad786e7211878100e2383ded8d3e71c))
* Ensure enroling in tutorial replaces other enrolments if needed ([aa854a9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/aa854a935e6e17521f595f610718ad0ecc9b364f))
* Ensure enrolment updates tutorial ([092faa2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/092faa25390d7d37315ea7b8303d94fef4f2f86c))
* Ensure enrolments are encapsulated in an object on post ([3bf2abe](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3bf2abe3cb01a98e09bf739d9ec11fd34727db1d))
* Ensure enrolments correctly returned when no stream ([47402cf](https://github.com/doubtfire-lms/doubtfire-deploy/commit/47402cf74dd140fe1e9f2712f3e77ad8b97f09fb))
* Ensure error handling of rollover to past occurs ([9f3d5d5](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9f3d5d54cc8f69c173f35b8f3931ddcb8d029d52))
* Ensure errors are handled ([f18b12b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f18b12b910ae8880dbd67f71f9e9d717bccf5274))
* ensure feedback tasks have has_pdf attribute ([ce60acb](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ce60acb1eb56f64c78bb16c2f701aec58a24624a))
* Ensure file checking of audio uses list of allowed types ([8a4b7df](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8a4b7dff1ce2d7d0e99b8c76e8239668736e1514))
* Ensure file only checked when provided in comment ([d72f08f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d72f08f0cda5b1b9c00a18259ee13a69bedddbf6))
* Ensure FileHelper uses extend rather than include for logger ([55dc966](https://github.com/doubtfire-lms/doubtfire-deploy/commit/55dc9665ee562b798f5f07de2545b69a00689031))
* Ensure force_ssl production config is false ([ff10c7b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ff10c7bdd9ffd2de1c998bf9b52c93cc665bfa02))
* Ensure group capacity checks project enrolment ([6fb7c76](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6fb7c7640007847ca8a58091161c3396fb369ad6))
* Ensure group capacity is checked on re-enrolment of students ([4cecbd1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4cecbd1d1b8a0ed884dbaa0e69b1486c455c5ca4))
* Ensure group membership checks project enrolment on validate ([1526cb8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1526cb897e7b838299f85bfa2944533bc7c93531))
* Ensure group saves on switch tutorial ([0650920](https://github.com/doubtfire-lms/doubtfire-deploy/commit/06509206ba111b72591d3fab2d1010cf2839a50e))
* Ensure group set api works when tutorial nil for group ([cf2cd8a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/cf2cd8ab5e3680990a5ede22c9b4d8c8521b1d7e))
* Ensure group submissions cleared when group removed from td ([5927711](https://github.com/doubtfire-lms/doubtfire-deploy/commit/59277115664c28b59ee0a33400353de329e6881d))
* Ensure group switch tutorial validates membership tutorial appropriately ([d4386ce](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d4386ce33eff11cc36fae9e42846387c8d47a70f))
* Ensure group task marking uploads work ([e33f3ca](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e33f3ca17fee458e3411256b524822de1651b13e))
* Ensure groups are mapped correctly to task completion CSV ([b2574cb](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b2574cb975422ef7b6554eb1ebc9975ca5f018d0))
* Ensure groups delete memberships on destroy ([079c905](https://github.com/doubtfire-lms/doubtfire-deploy/commit/079c905a3df9451ca0ad837ec1fb03e89a40345a))
* Ensure headers in CSV parsing are in lowercase ([7fc9180](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7fc91809cdb3c4e47f1ced11dd9a1cba3cafc2c4))
* Ensure import works with campus and streams ([6de8cac](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6de8cac63144472ed2901af56669242015445d25))
* Ensure institution config can be overriden by ENV ([92af516](https://github.com/doubtfire-lms/doubtfire-deploy/commit/92af516629638d91e09762a4bd1bfd1d6c93d391))
* Ensure institution config can be overriden by ENV ([7abb482](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7abb4822a12038b87bdc3da3446f4c6dd33e81a2))
* Ensure left outer join is used on get_all_tasks ([a361f34](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a361f3417608bd1000d503e26a67ec003b0e0068))
* Ensure lists are cloned in unit factory ([d802e30](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d802e30cf20688d87cb394a93997e989d92a5a08))
* Ensure localhost used for AAF in development only ([9ece7af](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9ece7af8ae72198ff73b718feaf40a6c4150739c))
* Ensure localhost used for AAF in development only ([7b49bae](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7b49baed1b03f8f97955f9ce74d77a196bd0f5a8))
* Ensure logger writes to default log file ([ca8d5e4](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ca8d5e43027be6315422de5d60b727458466d9e6))
* ensure median works when there are no task alignment details ([e44e152](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e44e152e0aa6347c4c67bd16097b405ae2c76ef4))
* Ensure member exists and is active before add ([8c2fc54](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8c2fc54a3a50da751b32ddf83191acb9350d35e8))
* Ensure minitest framework is used for all test files ([5b77519](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5b77519846a5af8543a241e10f8ae135b11af814))
* Ensure names are always capitalized ([09313ce](https://github.com/doubtfire-lms/doubtfire-deploy/commit/09313cecc74c67d43d289e4d9557ffd364ba645d))
* Ensure new checks dont override dismissed ([a011fc8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a011fc8cb2b9eb15a46191ab2a94e0de16431781))
* Ensure new comment creates read receipt ([4db68b3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4db68b358aa4e9fa85d3e6399d32ed81047385af))
* Ensure new comment creates read receipt ([6eb665f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6eb665f2a1af015fe505c7b0809a1c6d0f4802db))
* Ensure new files override unprocessed files ([d89fa20](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d89fa20ebad21c9e1d10f09487f58d6692de408e))
* Ensure new group number is dependent on previous num ([ea993da](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ea993dadb8d0c1a53428e1e09022c8a03b475dfd))
* Ensure new group submissions do not override marked work ([0d7cf91](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0d7cf91a9d6880671f990cae9c64f3fb32ac57ed))
* Ensure only staff can change group tutorial ([487d022](https://github.com/doubtfire-lms/doubtfire-deploy/commit/487d022cf2e485970ffa1c440cef0f08191295ef))
* ensure only started projects are included in ilo progress stats ([4673e0c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4673e0c9dd94e38f4b443541406292b80e0cf279))
* Ensure only tutors with classes reported in convenor summary email ([5560491](https://github.com/doubtfire-lms/doubtfire-deploy/commit/55604916920877fcaa04cf0e6b54456965211941))
* Ensure password fields checked on user creation ([8cfbdbd](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8cfbdbd1a37463ea8491d8e0fc0e20f5aac8f79a))
* Ensure PDF seek checks file size ([c232ae1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c232ae1dcfc85a6f1d9b144cd4e0eebcafc017de))
* Ensure plagiarism links are removed on task updates ([7ac5b90](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7ac5b90911c469afcbb4caf1cff4bef1bfe0a623))
* Ensure populate works as expected ([a43540e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a43540e31f20b239c4cc6597f60c8e797ce886bd))
* Ensure portfolio can compile ([eb95576](https://github.com/doubtfire-lms/doubtfire-deploy/commit/eb95576a61c5d456af89f1e07e1211f840acc60a))
* Ensure portfolio compiles if no additional files ([cb0c0e4](https://github.com/doubtfire-lms/doubtfire-deploy/commit/cb0c0e4cbdf86f3d069090d850358554c3c97b99))
* Ensure portfolio creation works with dnr color ([49e21f9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/49e21f9f49dd400242f9513a29765f3c59537154))
* Ensure portfolio includes additional files ([69b6ff8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/69b6ff841357fa759cdd076d3540cfe40278c8bf))
* Ensure portfolio zip uses tutor details ([362777b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/362777b0479a30a143fda976d02840261024e34a))
* Ensure project select only returns distinct units ([449e6d5](https://github.com/doubtfire-lms/doubtfire-deploy/commit/449e6d5fb1321e646cb5a690f9a0ca0cdf65f0c0))
* ensure project stats are updated when tasks are added or removed ([c3eddcf](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c3eddcfa1ece76336b8bfab117a8d5303a26d3da))
* Ensure relation order to allow unit destroy ([470d04a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/470d04a834040a32d7f1fa322bd4a6ce80577a09))
* Ensure reply_to is an integer in database ([01935b2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/01935b25725163716d66e20136bed91f31d88181))
* Ensure resources work with sanatised paths ([06e1374](https://github.com/doubtfire-lms/doubtfire-deploy/commit/06e1374df4bb1e315beb7c448e10ad6a9e9f1df4))
* Ensure resources work with sanatised paths ([ae5f51f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ae5f51f6eb96d220f165ccb35abce7c9f86e6d62))
* Ensure rever to pass uses dates ([33820b2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/33820b2c1af914891b0de9604d8e33ea976e8cc7))
* Ensure revert does not occur at start or end of unit ([67f45db](https://github.com/doubtfire-lms/doubtfire-deploy/commit/67f45db64587b8ee3eec2fa8ddee65fd3dd1cceb))
* Ensure scans only run once until next upload ([188341f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/188341f1709c90ce78a2ff929de6fe8f3c3176d4))
* Ensure Star day test is not case sensitive ([c2ab887](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c2ab88797f6654643d897744b1bfce050f2cfc63))
* Ensure start and end executing use correct scope ([510e2b2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/510e2b278c5805f3f701ee592e53a84fa49be435))
* Ensure status emails are not sent after the unit ends or before it starts ([5aecd0f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5aecd0f31401846934a3e03097f1b7aac814ba68))
* Ensure status key is returned in task mappings ([dc7ee7a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/dc7ee7a241ec7fe5a749e31f5fe371603513b699))
* Ensure student download only includes active students ([1465bb4](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1465bb4e399213cafa66b3c9ded70ec4ed43197c))
* Ensure student grades does include student id ([e76c5ea](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e76c5ea3368b2ba66237c54a67400f7b35ab6f3d))
* Ensure student id is added if not present ([dae20a7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/dae20a706035b01b8fda17e7cd5818c5d0cf3ae0))
* Ensure students from the right tutorial can only be add ([54a574d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/54a574d17c09bb0c4705d624572d4f2d4f6b9aeb))
* Ensure students only get feedback emails if option selected ([421bd28](https://github.com/doubtfire-lms/doubtfire-deploy/commit/421bd281cf14191918190fd6cc7590e39dba100d))
* Ensure students without tasks are include in unit student list ([b9fd92d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b9fd92d6348d5721c1d3928a7efb613093e8229a))
* Ensure target grade used in task stats on student query ([85c3e82](https://github.com/doubtfire-lms/doubtfire-deploy/commit/85c3e821b2411cd4fb29531f968dda5b31a8bfa4))
* Ensure task assessment csv works with streams ([b0a09e3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b0a09e3516e74bbd9922dbd141619630704fb835))
* Ensure task completion CSV works when no tasks for one stream ([8f18139](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8f18139548529ea25870b3754553657f0460cb5a))
* ensure task ILO stats only include enrolled students, and round values to 1 decimal place ([7839925](https://github.com/doubtfire-lms/doubtfire-deploy/commit/783992543657f9fabbf49b1b976a1b7c804e160a))
* Ensure task is stored before using it in endpoints ([04188dd](https://github.com/doubtfire-lms/doubtfire-deploy/commit/04188dd3f68ef0dbbc148f2795174c528363e289))
* Ensure task sheet can be viewed ([6303f57](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6303f57a21d4137f5a31e9ac3c577a5fb3667ce1))
* Ensure task sheets are copied on definition copy ([f863e7e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f863e7ecc927ba0d0626786851f8d2ef3fbfabd8))
* ensure task stats have correct values on new student enrolement and remove progress stat values ([97592e1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/97592e184b75cd4895e8619405dac93f0eb00e12))
* Ensure task status id in selection for task inbox ([8f34f68](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8f34f6813a4d7bfa2037f9e975ba66ae065b0ca9))
* Ensure task status is not case sensitive ([87f4cd9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/87f4cd93832122d04877d93c2f361cf93e43fac7))
* Ensure task status only notified to students ([9c3ed72](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9c3ed72f99eddcbd5cc2f250bd42308749557fcc))
* Ensure task uploads work when no group set ([3954a1d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3954a1db5a9e492ffd9396cc1777d26010ab51eb))
* Ensure task validation does not need due date ([17c28c0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/17c28c01bb40fc7d7201505013010b55c1ef7f23))
* ensure tasks can be switched using demo for demonstrate ([ea09dda](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ea09dda900e52d47ec764e02b5eb9c70fa724d30))
* Ensure tasks have dismissed similar count ([cd1c674](https://github.com/doubtfire-lms/doubtfire-deploy/commit/cd1c674e927637a30734c2b761aa839b0f04846c))
* Ensure tasks un/pinnable only by tutors or convenors of relevant unit ([f3b5dca](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f3b5dcadc619b18bd0b6926b9c741b7bf090a621))
* ensure tasks with assessments can be destroyed cleanly ([e322b8d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e322b8d21bbc99a63a928ef9b5b6b7e4bed34bc8))
* Ensure teaching periods can be retrieved without auth token ([56bed7a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/56bed7a26eb0d1ff6cadd560033a7e59c0ccc292))
* Ensure that activity type cache works ([2d9fa42](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2d9fa423efdb0b8518098214e3c3daacace56c82))
* Ensure that add text comment is used to add automated comments ([4c2e6d9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4c2e6d9e125ba6156a2d537d9d20d30d1fabdead))
* Ensure that additional files dont include "." ([c3c35c0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c3c35c03ffe7b6fc3877e2dbe8167d0778d39512))
* Ensure that all escaped latex text removes non-printable characters ([3a2f6e2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3a2f6e2aab9bf47228471601c9642cde03bc21d9))
* ensure that all group members can see comments ([ca56e2e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ca56e2e596e5b525c8342ca22df4975dbef58b58))
* Ensure that campus is correctly synched for units ([9386073](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9386073dd1009b4480ec9b4bb77e64b1a62474af))
* Ensure that capacity adjustment works on group import ([55611d6](https://github.com/doubtfire-lms/doubtfire-deploy/commit/55611d663a67a16cda802571fefeabdeb5547b1a))
* Ensure that code files are UTF8 in portfolio creation ([1c2cd9b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1c2cd9bc51e0c1637ae1619cf1297281cba0958f))
* Ensure that comment recipient uses correct email ([7d36e8a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7d36e8a59c0fd59a45278b15c2c454b6112cb560))
* Ensure that convenors can create tutors ([eedafb3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/eedafb3b11f2ed4e810077b800943ca00b655347))
* Ensure that CSVs are ascii without BOM ([34fd070](https://github.com/doubtfire-lms/doubtfire-deploy/commit/34fd0703289861c60685f20221fb984142570169))
* Ensure that date changes for teaching periods are propogated to units ([e99401a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e99401a864f5c90a4d4633c6c448d970d633d528))
* Ensure that deny records a extension response ([f941bb3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f941bb3d33f291b9411c7ca2875d11c4f2ee19f3))
* Ensure that Doubtfire logger does not rotate ([ceeed68](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ceeed686f096fc6024ffcb502d9f52d9b43a5067))
* ensure that end of week processing updates both discuss and demonstrate tasks ([197899e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/197899e56f7b44085ed14297a18d4fd3476d6f9d))
* Ensure that grade details can be downloaded with task data ([d96eb75](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d96eb75555f140713a7ba2ee4ee6e9ce98464722))
* Ensure that grade details can be downloaded with task data ([7df917e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7df917e991dac370a594e4ca0f5e4020694fbf56))
* Ensure that group status of task cannot change after submissions ([ce1ac7a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ce1ac7a8cae239d4849bca16e4b6952da3348345))
* Ensure that group submissions do not replace complete tasks ([25dfe25](https://github.com/doubtfire-lms/doubtfire-deploy/commit/25dfe25127c46256cf752b8f8258173be275c7cc))
* Ensure that importing does not change tutorials if any tutorial present ([cff31e4](https://github.com/doubtfire-lms/doubtfire-deploy/commit/cff31e4fd88bff80385098699f745fd0f47f19e7))
* ensure that init does not add task status twice ([86d9dd4](https://github.com/doubtfire-lms/doubtfire-deploy/commit/86d9dd41605fea50d30a4a07bc742ab123d74b8c))
* Ensure that languages map to pygments lexers ([0073cb2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0073cb26679c64902b94d79fce1b4f07af1f899b))
* Ensure that main convenor is cleared on destroy of unit ([2b6eab3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2b6eab3e009d7a1ea0f2902ab00d3cb8d0be543f))
* ensure that members are restricted to the group tutorial on group change ([12da642](https://github.com/doubtfire-lms/doubtfire-deploy/commit/12da642a30e3cdd5cc556206c76bc09ce702f23f))
* Ensure that multipel assessments create multiple submission ([5190845](https://github.com/doubtfire-lms/doubtfire-deploy/commit/519084594de385f91245da2501ffbeada9222b38))
* Ensure that mutli-unit handles withdrawal from one unit while enrolled in the other ([6edc8b8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6edc8b864143d4e5e3d76d2332daea47fc97b0a5))
* Ensure that new tutorial streams check for name or abbreviation uniqueness ([19df3e2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/19df3e212c1a15e533a566620696e1f2f072162e))
* ensure that null header on CSV import succeeds without error. ([c6f43e2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c6f43e2426cb0a967a582f2b0f1abf70eeed9875))
* Ensure that plagiarism data is json in csv ([1591cab](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1591cab171921ef7a8afa44590d18548c65220db))
* Ensure that role for works with nil user in project ([33cf184](https://github.com/doubtfire-lms/doubtfire-deploy/commit/33cf1845b32ca31653e98ac3ac73d01f3113aafb))
* Ensure that save of task definition raises any exceptions ([a7b833e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a7b833e2157752c579ec1602b3b60ef8ea19260e))
* Ensure that status emails are send with better date range ([4c19983](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4c19983e540ed0ddc8459a2465b023093d94d385))
* Ensure that student CSV import promotes enrol over withdraw ([e9e289e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e9e289ec9e335ba16fea5b788bedc1edfe3a6c32))
* ensure that student project query only returns active projects ([a6b9215](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a6b9215d126704f13b283b0d385f8aa55864d716))
* ensure that student tasks only includes tasks that students will attempt based on their target grade. ([6275455](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6275455bf67b3826b73ffb34d5333a7868eae349))
* ensure that students are in a group before updating task state, and allow student to change tutorial when in a group (removes them from the group if restricted to same tutorial) ([d1c2fba](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d1c2fbaf761b2081f0d1df4901c70767acf9374d))
* Ensure that students can change tutorials ([85b2b22](https://github.com/doubtfire-lms/doubtfire-deploy/commit/85b2b2232aaecc673ffa3e316f2c6c299eff6fb1))
* Ensure that students include those with no tasks ([1d92a74](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1d92a740a48580b7158abf363ecf76118b629e53))
* Ensure that task can return zip path when definition group changed ([2ac1ca3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2ac1ca3460911802acfac214aa0eb9ce8f2648c8))
* ensure that task definition CSV contains is_graded for import/export ([b7d388c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b7d388c15ba568f2bbea71935d10e61dde401559))
* ensure that task outcome alignments can be updated by students even if a task id is not provided -- we know it is related from the link details ([3b6b43b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3b6b43bf3513a28bffd831d3520155fb7d7bfba6))
* ensure that task resoures and task sheets can be uploaded if the task folder does not yet exist ([d9593b1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d9593b16e7cfbcd54747df25d0d0b5be39ccea9e))
* ensure that task transition triggers work with fix and include as well as do not resubmit ([5f60fd3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5f60fd38959bd8031406f2718f126e96afb00fad))
* Ensure that tasks can have -1 quality pts ([1b4a1fb](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1b4a1fb7245ec790a123ba410f03a55f1cb18a80))
* Ensure that teaching period destroy is graceful ([56018d2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/56018d2cb8cb97b7cc4a0c6b4157437599f5e7a7))
* Ensure that tutorial enrolment changes are present for project validation on enrol ([3e20a40](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3e20a403680979fd25cee9805374bc80b4092ad9))
* Ensure that tutorial enrolment checked on for enrolled students ([9ddf35a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9ddf35aaac2b87e6dea18402ccfe62d142bf2e57))
* Ensure that unit can add student when multi code ([88711d1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/88711d1329dd18a97076276c7d86dd7017c21f73))
* Ensure that units with tutorial enrolments can be destroyed ([56a82c7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/56a82c7e8c562ba9d505f540ab95f18c3b3350f7))
* Ensure the server pid is only removed if it exists ([0c2c522](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0c2c52261a3a28b9c30967e03db082256533d592))
* Ensure time exceeded can be resubmitted ([434f00a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/434f00a90ad1fa3a7431ee8649fae87c54011875))
* Ensure titleize retains text where possible ([7285f2a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7285f2aed611a2daee893d0463389e7c292ce54a))
* Ensure top tasks are correctly calculated and displayed ([9358c9f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9358c9fca6e7cad29ba8d157d63134b1829d6bfa))
* Ensure tutorial abbreviation works on group import ([2f0c636](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2f0c63630260409ea32f1ea22b2faad5d1c4c52a))
* Ensure tutorial change check uses project ([a531e2b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a531e2b2a2cb9ee7dc9ee2d1444920fd7393e4e8))
* Ensure tutorial enrolment changes validate project ([bdd4642](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bdd4642481f5201d7e68aa0cf43dbee2b2497055))
* Ensure tutorial returns id when no streams ([f0d368d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f0d368d031a099ddc3deae0b154cb35207ce9521))
* ensure tutorial validations raise errors on creation ([1c9df6c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1c9df6c1a89f050053f24c1dae022e9e70940c5b))
* Ensure tutorials are correctly linked in task completion CSV ([f58dea0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f58dea018dd856a24d0d87144680a6f1dd735c1b))
* ensure two newlines between comment text in assessment comment ([3dd7021](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3dd7021ea5c1bc1329f674669ef7f95a6f96fb2e))
* Ensure unit role tasks awaiting feedback matches details from unit ([8396d36](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8396d36c69c6f1444929e94b7aae4c711b8c8dea))
* Ensure unit shows students when no tasks interacted with ([9c47175](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9c47175a3cf7ec790705503ee0b27dbc1e2111ed))
* Ensure upload group can update group details ([a85a10d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a85a10d0b87034f58b8649615e4e0049782d5e34))
* Ensure upload of users works with xlsx ([bf4a7d0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bf4a7d06727df86bbd6f2f4a6aa33a6c61ca7c37))
* Ensure upload task definitions uses exported CSV for xlsx ([8f80197](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8f801979c3babab37a59a611eb319636aac8e70d))
* Ensure urls are encoded for tests ([0245aca](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0245acaa3410b23cd88e12923df23117154ac070))
* Ensure user notification preferences must be set ([f5da5a1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f5da5a15152446b74b75ce2a9be2c0180b0b7158))
* Ensure we have the campus for tutorial sync ([e288d6b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e288d6beb143e649a0ad79cd7f85609260e2fc8d))
* Ensure withdraw on sync checks if student is enrolled ([48574dd](https://github.com/doubtfire-lms/doubtfire-deploy/commit/48574dd7a227ca3db5689b91ad3671ae633826af))
* Ensure withdraw only occurs for existing users on sync ([8f5b307](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8f5b3077ff9553f21500edf8b1593cb1cf48024e))
* Ensure withdrawn students are correctly reported on csv sync ([bb757a8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bb757a855d080e1d0848a6c4979f38ecb769266e))
* Ensure you can delete tutorials without enrolled students ([ed28c43](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ed28c439b1ec17c902fee7a4106ef27fa1920232))
* Ensure you can remove a tutorial from an unenrolled student ([1340b55](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1340b55d9c463ef8c20207beed2451b8dfbfc6b3))
* Entend burndown 3 weeks past the end of the unit ([5a9108f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5a9108ffd02301c9803b9029b0111b9e6f998a41))
* Error reporting fail in portfolio evidence ([152ea6b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/152ea6be20dd036e5c0f6b18da321959c08b0785))
* Expand search for EOF in PDFs ([8125a54](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8125a543d5b3a805a24cb10fe0d16fa6817ce52f))
* Expose postgres port for database container ([243ac9c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/243ac9c41c51c1a84183fa5af8bbfc850035c8f0))
* Expose user id of author and recipient of comment ([aaa3ef3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/aaa3ef323749b0df0427d0e2fef0be6896a079ae))
* extend the size of the description for an ILO ([5003ebc](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5003ebc0d3b7baa196984f31a4d7a9f0519912c0))
* extend the size of the description for an ILO ([a7338fa](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a7338faf3f506caff3213353e4ba6092be2cae00))
* Extend time for ffmpeg conversion ([888f0a2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/888f0a2a4332617e7a2f0b07588ea0a8b7764233))
* Fetch loop for single project/unit users ([71a2d60](https://github.com/doubtfire-lms/doubtfire-deploy/commit/71a2d60e5802a2d1b0357c0f3c305ca7926dcafe))
* File permissions for overseer to operate upon ([e3708aa](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e3708aa03f0fb273a0642b7544115b842d97e8d7))
* Find correct task definition when updating draft task definition ([125a9f1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/125a9f11e867a2eb23f120484646dcfc641b6071))
* Fix allocation of number to group ([905b519](https://github.com/doubtfire-lms/doubtfire-deploy/commit/905b51918670459faa1e7245d8c3003f88091999))
* Fix bug where grading a task was not persisting new grade ([331cb79](https://github.com/doubtfire-lms/doubtfire-deploy/commit/331cb797f5de924f4dafbad4c63138d55d3fecd6))
* Fix buggy serialisation of student nickname ([55aa5f4](https://github.com/doubtfire-lms/doubtfire-deploy/commit/55aa5f46f472de340bef147709bfdbaac31686fc))
* Fix corrupted web deploy in 45077dd ([ff49ce0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ff49ce05cb0041e2557f539e2b71360846d57aeb))
* Fix cyclic stack overflow when referring to self.logger ([38386ae](https://github.com/doubtfire-lms/doubtfire-deploy/commit/38386ae3d360ba8aa7a71a3c7246ecd47b1ddade))
* Fix dependency of last group if no groups ([9c602ff](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9c602ff138d000afca159b62afad94cb0c0fc97f))
* Fix deprecated all call with order ([dd94fc9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/dd94fc96389fb4c1ef7a81b3e0567aa5fba24b89))
* Fix discussion variable names ([8585be8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8585be82f344a1b07ab6512da5705875ae202a21))
* Fix error in string formatting for test_auth_put ([7ae25c9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7ae25c973023859c109141aedaee4059ccd3d91b))
* Fix error with generating unit data properly ([014874c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/014874cbf38a9bf75ac24183acbdd087a83c4ef9))
* fix errors ([092dc1c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/092dc1cd3f35c1c0faf0cd450f451739e66f1de9))
* Fix get all tasks and comments ([6e775f8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6e775f809a6d2b702c8d3a628cf54ac0d43ed18b))
* Fix incorrectly replaced find_by_auth_token ([c9c5790](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c9c5790bf7e2d057d8f6b850a366f3df333c0fc4))
* Fix indetation issue ([1eda74a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1eda74aa71967e022c2b964f3c51b23201891165))
* fix indetation issues ([352eb29](https://github.com/doubtfire-lms/doubtfire-deploy/commit/352eb29bbfba3e7606be42500f479b7441753ad4))
* Fix installation script for Sierra compatibility ([229ca9b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/229ca9b25dde384f60bafeba15d68d16e7bc8fe7))
* Fix issue with getting units from get /api/units ([893e9dc](https://github.com/doubtfire-lms/doubtfire-deploy/commit/893e9dc7cbc8022455d7d375f39e00bc2b1e456a))
* Fix issue with webcal primary key being defined as an integer upon `db:schema:load` ([9c6c147](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9c6c1476772d20237837a45023c970d76bf07d47))
* Fix manifest merge issues ([06146a0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/06146a081a4fe2551b332f12bbcf19bfe42f3bae))
* Fix name and ensure file helper test uses temp dir ([0848a97](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0848a97c9f1c884e91ae32bf606b7e31892335eb))
* Fix populate rake task for unused extend argument ([076a45a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/076a45aa9ab09e3db35fa38541718d4b7512d355))
* Fix problem with sorting ([f3556b0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f3556b090e3f79a255c2945755496d3d58909830))
* Fix rubocop breaking portfolio PDF generation ([3cc865e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3cc865e1797284c6666eaec6f71d3e3bd3531db3))
* Fix rubocop breaking portfolio PDF generation ([647f247](https://github.com/doubtfire-lms/doubtfire-deploy/commit/647f24713d9aabf3e2e7c049edda9517adb10cc0))
* Fix rubocop syntax change which breaks authorise? ([7fb3967](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7fb3967982d5b176740c2c6db33c782ebe49235b))
* Fix spelling mistake in API error message ([38f76a1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/38f76a1982c474746dd16472db0308781606e00c))
* Fix submission with extensions for group tasks ([22a5c0e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/22a5c0e42427197f88cc0dbd3758dd0d762de572))
* Fix switching group tutorials with group members in it ([4332598](https://github.com/doubtfire-lms/doubtfire-deploy/commit/43325983bd6722131183e3beaf2d7d80da403f2a))
* Fix task comment_by field to user name ([b749253](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b749253b0fb707393b9a70774dc568436bb41e24))
* Fix tests to user appropriate data in feedback test ([2684fc6](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2684fc61d243f218e0e0c24345e52ef3c6e7a041))
* Fix tutor permissions to download statistics for units/users ([eee7b6c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/eee7b6cde6b10e6d1995d2c465a1358d62487518))
* Gemfile.lock revision for bunny-pub-sub ([c5b137a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c5b137afe473e4a23da4857f81eb87b715dda904))
* Get campus from tutorial ([afe357b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/afe357be96713bc7e17327358a7c4b60a0459cc4))
* Get the campus from tute in expand first unit ([ebc1d21](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ebc1d216f50f378cb85cba86040f5f24b8ae842c))
* Get the campus in the tutorial enrolment factory ([fdfb24d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/fdfb24d54481d36ff6cee8ee7af5dc80c35df84b))
* Get tutorial and tutorial enrolment in target grade stats ([9e6367d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9e6367d6882dd77e1c74a3fc7592d42cc49beb3c))
* Get tutorial for all tasks ([1a50d92](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1a50d9257623aa2c2bde31dff3a54e650b33e31c))
* grade range in task completion stats ([2af36ed](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2af36edfc0b432cc730a5bae7e6068e5e7e2ebf3))
* Group capacity checks on reenrolment check beyond capacity ([0b939a6](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0b939a680ec58c1fe02600b3117906a9dc87b8b3))
* Group factory names to enaure unique ([7e65fa4](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7e65fa4d2569c8197b426c617241b7b2cd903a81))
* Handle additional grape exceptions ([90119e0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/90119e02553d3e582a35212e3e1311d0ed7baf90))
* Have generate pdfs check pid of process ([aebcbdf](https://github.com/doubtfire-lms/doubtfire-deploy/commit/aebcbdf94cc8ce906ba6d1adef7098dbf6a2fedf))
* Helper name ([551727e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/551727ef164ad2879e8512a02f35ac580e2f9a2f))
* ILO progress summary stat calculation ([a025c98](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a025c98e71afcfb03cfeb50db4c07df728a3c45d))
* ilo_progress_summary will not return an error ([a761592](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a7615928f443d8592af31e6fbbe5a356d844e213))
* Implement WIP fix for tutorial delete ([c72cbb5](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c72cbb52e93cef5fab31d1dfa5d67f3dd2c7fefd))
* Include _current_ units in webcal ([e7ee874](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e7ee8744da398bb0458445c8c0fe0eb4d34a39b4))
* Include :has_task_assessment_resources? ([6975790](https://github.com/doubtfire-lms/doubtfire-deploy/commit/69757903ab217f4f96efdb6f9c095523ffd03953))
* Include delete frames and use jpg on compress of images ([8c8bd27](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8c8bd278c7772de7329598445b5f9b457a682793))
* Include only tasks of the user whose webcal is retrieved ([b2d97c9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b2d97c990f0f82031f613d95af693a1a65c4c6c1))
* Include Rails `ID` in `WebcalUnitExclusion` entity ([869b416](https://github.com/doubtfire-lms/doubtfire-deploy/commit/869b41696f9c035e8aefc1cfeb66d9caa1fdeb91))
* Include time exceeded color in portfolio creation ([e4956b0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e4956b039b988462fa392e0aab825f5f4b41815a))
* Incorrect return in task transition ([dbd2794](https://github.com/doubtfire-lms/doubtfire-deploy/commit/dbd2794c3f6d21e237a605094fe77f4b631b494b))
* Incorrect use of .nil ([41be46c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/41be46c014dd709a4eecd7b00f670be7cb571cb6))
* Incorrectly using environment variables in config YAML ([9c47948](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9c47948522c42f068fe8b95af94fdc1af0619558))
* Incorrectly using environment variables in config YAML ([04c870d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/04c870d1f76db2d8216b5eb724f5769629db4d2d))
* Increase teaching period length ([65a45e0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/65a45e06be1eab4aec3367ea61bf9a3d7fb3eb07))
* Increase year window to 1000 ([0bb730a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0bb730a4b0327b176dec48a343ed5d3d9bc9e694))
* Increment times submitted only if status not ready to mark ([af0611a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/af0611ac39b33b3fcf0aeb0a86c8557bd8103c6c))
* Install ffmpeg which is required by newer api server ([d40ec4b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d40ec4b2ff0f51ee3e159489c73c267aba7fcb07))
* Issue exporting grades with not started tasks ([b4781b2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b4781b270856ec45ad6fc60df182587d2709ae85))
* Issue exporting grades with not started tasks ([5083cc8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5083cc809d1a76f5da7734d67a96899671983f11))
* Issue with comments for not submitted tasks ([f6d19ce](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f6d19ce37bae9a8a4bdb46a9a6a42837fb3eb1fb))
* Issue with directory check ([ecbd14c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ecbd14cbe7291887fa50bd5c8c9ed9aa473e3d02))
* Issue with import of student campus data ([3ddf25d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3ddf25dad166d63fce29acade0984098dcb48884))
* issue with importing tasks from CSV due to column consgtraints ([8f0a0b8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8f0a0b802cf0f870fc6674039ef57cfb87dff2cd))
* Issue with main_tutor if student tutorial has no tutor ([1f3158c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1f3158c15221d45e5cf54dbd7b7693943fb8e71f))
* Issue with re-uploading evidence ([6ed5cdf](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6ed5cdf7bef3614ab6e944f59a749c58139fadd8))
* issue with task completion stats when low submissions ([6d3e930](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6d3e9309cf03f81021aa5bdac1b7c6bb83fe0748))
* issues identified by lack of tasks for student projects ([08c9807](https://github.com/doubtfire-lms/doubtfire-deploy/commit/08c98078824409771dfec611e6090eb4f760bf9f))
* issues with ILO progress stats. ([8b3fb82](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8b3fb822a0a04ec738ceed527244cc493d0deee1))
* issues with unit_role on student CSV import ([7ce89b9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7ce89b951bac76e4d559c82755c4e2883af91e4d))
* Join tutorial enrolment in task completion data base ([8047aad](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8047aad3c8e7abd1110be7a29d08da97f0fadc0d))
* Join tutorial enrolment when task def matches tutorial stream or it is null ([4d9f213](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4d9f213bb9bb8f8a08c6881821b3dac2f42b4dcf))
* Join tutorial enrolments for student ilo progress stats ([4ccbd08](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4ccbd08f8f132429cd1feb3b894981659ca3a993))
* Join tutorial enrolments in get all projects ([ceedf80](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ceedf80df88682e549c09bbb2e64ee53451dc1e5))
* Let config.overseer_images exist without OVERSEER_ENABLED flag ([56e6874](https://github.com/doubtfire-lms/doubtfire-deploy/commit/56e687422e9987858058b078688603f0835d4b04))
* Limit project list to only enrolled units ([462a9c4](https://github.com/doubtfire-lms/doubtfire-deploy/commit/462a9c4d8144c85280349d26626ea9512789e8b1))
* Limit the access of return teaching period information ([1929e94](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1929e943f4bdc5e85a43c7f7416e2069072ac82e))
* Mailer url in notifications ([eed80c7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/eed80c788920e278b474fea659e1a8018f9a7844))
* Make action_date use last student comment date ([8a3e1e6](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8a3e1e6d5714559148f23c24f3d15ad4e21ca3d3))
* Make campus and activity type factory unique ([fbb32e6](https://github.com/doubtfire-lms/doubtfire-deploy/commit/fbb32e65a3b2b99efe351cbd9977ec8669d6026c))
* Make delete of group member consistent with POST ([f14822b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f14822b516ad86ae9fe2718f86eeef77f09c5df7))
* Make docker-compose working again ([29abae8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/29abae8d9978a1fd2216b8491f9615a8337b916c))
* Make grade's default value nil not 0 ([d0b4149](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d0b4149a74408ed9ad5e35e43b0edd7bb8fb6feb))
* Make login_id nullable ([cb8ce3a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/cb8ce3a2ab2d19c4538849a93029cc06226f1a4f))
* Make plagiarism_warn_pct optional ([031d624](https://github.com/doubtfire-lms/doubtfire-deploy/commit/031d62414a2b7076966f522f8cc6ea5aa57a0417))
* Make sure combination of year and period is unique ([cc0d900](https://github.com/doubtfire-lms/doubtfire-deploy/commit/cc0d9007721b7a2f9e3393eac9d9c3c7081bdfef))
* Make sure that only admin and unit convenor can rollover unit ([118430f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/118430f3b8be5c31577e00f57e791ebd47754f31))
* Make Teaching period hash require instead of optional ([33566fc](https://github.com/doubtfire-lms/doubtfire-deploy/commit/33566fcdcc308e5442ee57ed6299e46c5d851702))
* Make use of new id to status in task ([46500d5](https://github.com/doubtfire-lms/doubtfire-deploy/commit/46500d53fea7f26068b5782d5248e93333036493))
* Mark discussion comments as read when replied ([e8f603d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e8f603d1aae169dac9ae4a41ebe0e3c50cc4cd8d))
* Mark discussion comments as read when replied ([1b36acc](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1b36acce420deaccf00b91ec84969d96a07d271a))
* Max one validation when tutorial stream is null ([dfdfae8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/dfdfae8fb643898d6c42d9854c2feeae7f6c9ae6))
* Merge in UI fixes for portfolio, alerts, and filters ([7dec01b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7dec01b9fed0c087e1f70b45051ddcc32f810083))
* Messages from task processing fail ([f6e86b3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f6e86b364581e25afcef191a645dafb06ae6214a))
* migration that removed students from unit role -- cannot use project link once unit role code removed ([b779a0a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b779a0a0d1d0cf9c0c26930f601888b2e11b8067))
* migration that removed students from unit role -- cannot use project link once unit role code removed -- attempt 2 ([b87b67b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b87b67bf65b723a8b514790c2b3e85f94309e16d))
* Minor issues with UI for task status and plagiarism ([f077f61](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f077f61acf4e6b386b38754ea668d18dcecdabd0))
* Minor UI fixes for task signoff ([97300c0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/97300c0e7caafe6abf7bb9d8d542ee3f280b1222))
* minor ui issue related to portfolio not showing in grading ([c86b312](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c86b312fa9871fabd16276a2c8ea06f828c6997a))
* minor ui issue related to task url location ([1ce5ee4](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1ce5ee493b9a35b02e8b75e908097f7d829010a9))
* Minted output to add line breaks and change tab size ([c73373c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c73373c36a6f2d7a0734cf4c6418e5c4876766ff))
* Missing `sm_instance` method error ([94fd461](https://github.com/doubtfire-lms/doubtfire-deploy/commit/94fd46166a4bfe96ce988f323c309d040a6fe73e))
* missing details for fetching a unit role ([a0c2c91](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a0c2c91c03eba98b11608e815ba5e346748a6f40))
* Missing do in mailer action ([722bf19](https://github.com/doubtfire-lms/doubtfire-deploy/commit/722bf19a79db271a2fd1589690664b9c59cdc785))
* Missing end in unit sync code ([70910b0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/70910b01cbc2a25886f51f1af5ee2f9f0f7bc66c))
* Missing reference to grade parameter fixed ([5b73228](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5b732286e4f6462160452abeaf51b6aff550ac1d))
* Missing user in non-AAF POST /auth ([c8214d7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c8214d7a9d2699e6a9b16bbbd5ec21d633db7909))
* Move convert output params to before out file ([80f4aef](https://github.com/doubtfire-lms/doubtfire-deploy/commit/80f4aefec8e15ecadb1833c6e6f316df42178971))
* move reloads of tasks on group submission ([221b1f8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/221b1f8bd97c4dfd4538bd9495c425e9662403dd))
* Move the roll_over method to unit.rb ([9e604c9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9e604c96d25a792c3fcd5fa5234001c2f1166254))
* Move the rollover unit API call to units.rb ([486483d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/486483d87042279d572b639353aa70a6e626d7a9))
* Move the teaching period info to settings ([5b3a305](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5b3a3050580d0d056930250d402814574348edc2))
* Move tmp files out of tmp ([d1af91e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d1af91ef9c84b6bd344b00062d89333f723247fa))
* Move todo comment on top ([ebc6912](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ebc6912d1f925947e759a02ae162852104bc093d))
* Moved dev only gems to dev and test ([21465f2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/21465f2830676e3fcc84525fe7c4bef38102033c))
* Moved email validation to User model from User API ([3c6871a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3c6871a1868cb40e3dd45df461a24d433e823d6c))
* New assessment API bugs ([0f4273c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0f4273c3a39d8fd8d0117720f9fc3e18c076ae84))
* Only check that require AAF config vars are set ([9f3c167](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9f3c16782c1e5609a0a5fbaf80beb3284a3b051f))
* Only send tutorial stream in task def if it is present ([073124d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/073124d36b12dd364e73a5802989b2fba06f49a7))
* Only use password field in User if AAF is not enabled ([e0ea3d7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e0ea3d7fa29c92652fd0b78b5a277493e6d78fa6))
* Output to cron on skip generating to help identify cases when processing fails to run ([8f8f9ff](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8f8f9ff85f1222ffdfada8aa395e3bf02987dbea))
* Overcommit excludes ([218d6bf](https://github.com/doubtfire-lms/doubtfire-deploy/commit/218d6bfe6dcb8ed0e40f718d397e3bda6d7732b0))
* pass week paramter to grant_exztension ([bdb225c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bdb225c756944e9d35c6efb20f30d6d024df5d68))
* Patch issue with text comments ([7d2ad8c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7d2ad8c82853ceeb5147e6bb6763454091e97f7b))
* Permit `tutorial_id`, `capacity_adjustment` params when updating groups ([a80501c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a80501cf58d0748d58a7c24cebd1e3ef95f0153e))
* Portfolio creation to support more outcome names ([c2cca19](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c2cca1961c89f5b9ff4dba51335244a612265998))
* Portfolio creation with odd abbreviations ([4d1ac3e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4d1ac3e356cd0c7fb249663def7f2785e69c47a9))
* Portfolio review step UI ([abe9ff1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/abe9ff18dd3f66c1ecd0593d604d18bae8e7f358))
* Portfolio review step UI ([606d1f6](https://github.com/doubtfire-lms/doubtfire-deploy/commit/606d1f6b91b9a3ff9ff1fbef85ebaaa8e5c94244))
* Prevent different institutions from signing in ([2adc19b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2adc19b34f82144f447569757c015d78a23d9ed5))
* Prevent group member from being added to group twice ([a578a19](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a578a194072bb865a98866bfbd6c75b77d524d14))
* Prevent member from being removed if not in group ([02e823b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/02e823b4f8e0d92554400d15f4772f69e6cd8553))
* Prevent submitted grade update after portfolio submission ([797765f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/797765fc1073d2fd2360ea44c527d7f3968c1093))
* Prevent task def check when id is null ([091b7d7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/091b7d7dc9d25d50e67d68a0f5fb5345cff82031))
* project serialiser if there are 0 tasks ([619f329](https://github.com/doubtfire-lms/doubtfire-deploy/commit/619f32953fbce240321a3db6409e0711a7ce198e))
* Project task stats when not started ([9cbf395](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9cbf395c3a8aa7cbad9a2b6f3181b11667766c1b))
* propagate grade updates then update current task's grade. ([ed11d61](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ed11d612725e80253de7384ca144b6f827ea5dc9))
* provide a new tasks csv with start dates added ([4fd3fbd](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4fd3fbd6b32d063467f597db571f7a109cd5a8ec))
* Provide current user via stubbing first user ([7b35118](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7b35118b8e3087dbd51c961c6c6d73e68361c27e))
* Push lazy project tasks to project.tasks if created ([1acc7c4](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1acc7c4bb74a8a2851cecd3d757ee7793d55bb62))
* Quotes in application.rb ([d55ec13](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d55ec134928bc5994dd4539d2144c71532e9b9b9))
* Raise error when break is not added ([884b6a9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/884b6a92d57679f407cc000a7fdcba26e6e0651f))
* Randomly stub if a task is new for a user ([5f33bff](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5f33bffb27c00c1c8ba2df3a45e85b4af8bdec68))
* Read CSV data from file outside of CSV parse ([ef90adc](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ef90adcadc5eff526988887d6d685309df5bf88f))
* Redirect users back to front end after validating JWT ([78d3e6f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/78d3e6f8f081064a817473dd6f387e12373523ff))
* Reinstate seeds from master ([31376f3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/31376f3ca333d5cc307d1d46b735e08be82a8f5b))
* Reject authorisation where role_obj is nil ([1eb9e2c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1eb9e2c4e1c650eecac7fbe973c65480d8a12ce2))
* Remove add_teaching_period from teaching_period.rb ([23bac26](https://github.com/doubtfire-lms/doubtfire-deploy/commit/23bac26b44669248349049fdcbe470d6afedb172))
* remove additional awaiting signoff references ([4af4603](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4af46036259a881f76fc2790d40669db2d0f8a39))
* Remove an unavailable gem minitest-osx ([899671f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/899671f54317f49e5ae29d97d10bec81913a021f))
* Remove an unavailable gem minitest-osx ([6aa5d5d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6aa5d5d399a15e7cd6ccb9430cf0c6a48360079c))
* Remove attachment comment type from task comments ([ff473b6](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ff473b61e3b281a091d0deed1d307da1c072e5c3))
* Remove bad auth method calls ([455e9a0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/455e9a0845e1bf715b6c0c3f6c694500aa2a7f5a))
* Remove bad table drop from migration ([2d9021f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2d9021f365800cc6309bc0bd41a4f32dad0354bc))
* Remove belongs to relation between project and tutorial ([839cc76](https://github.com/doubtfire-lms/doubtfire-deploy/commit/839cc76720c4025be472c48210c5107c1d7e3c8b))
* Remove breaking empty test ([97a9c3d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/97a9c3df1025aa7587f4c5fce5929fe2271a8ebc))
* Remove bundle exec rake db:setup step ([fcc7e26](https://github.com/doubtfire-lms/doubtfire-deploy/commit/fcc7e267227a5d6238fd817d1d480b71f9dc3082))
* Remove bundled with command in Gemfile.lock ([1227d40](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1227d4010566614ee53af7a178cd493682b941c9))
* Remove calls to puts for debugging ([c588c6b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c588c6b4e34da4e36f21d482cb6b323d6b12002d))
* Remove campus from tutorial sync search ([c461968](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c4619680005b3e4b47d8448d430952019616bf4f))
* Remove ci/reporter/rake/rspec from Rakefile ([0b0dff8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0b0dff840e139ccf49d77d20831a4c887bd1ced8))
* Remove clutter from submission API ([15f0361](https://github.com/doubtfire-lms/doubtfire-deploy/commit/15f0361d8a15dd8885a0dfc082ac5af9e1f8ec02))
* Remove comma from Get all teaching periods ([ff39c42](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ff39c426555bfd1bdf10869deca6c78923773783))
* Remove creation of any user on init ([de2af7a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/de2af7a92b1ce6d3bcb09e332f0b4b28e401a3eb))
* Remove destroy tutorial enrolments on tutorial delete ([8ce1afc](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8ce1afcc8c5c68f57eb949458bf83738e132b159))
* Remove duplciate count method ([8765903](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8765903971f276c1dc8b29b2f5942719f992108e))
* Remove duplicate task inbox ([8cddbea](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8cddbeaf1a9a0512e879e87a0331ea016241c1f2))
* Remove duplicated libmagic-dev ([e829554](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e829554f1d8349d91ceafc23da1f2822e2bcbeea))
* Remove empty .gitmodules file ([ff99a7c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ff99a7c47e0f5e68c53740c0799107842d493da2))
* Remove extra param to fix circular dependency warning ([6dd5d4b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6dd5d4b2169db8d7a1df9512360e7a3990631db4))
* Remove git modules to fix Travis error ([a18d7a1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a18d7a1f9096a003b7c004f2bafb1b966965909e))
* Remove group number from group import ([d99aaf1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d99aaf16a22e8d7caa6f029bd3c5f82ffd84d2ef))
* Remove has_draft_summary_task from project serializer ([25eb27b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/25eb27b6e93fc18f970d890725a982dc0fc7863b))
* Remove limit on stats for low student numbers ([fe9e395](https://github.com/doubtfire-lms/doubtfire-deploy/commit/fe9e39588853e9cd6e25377c547a20843b4496c6))
* Remove main tutor from PlagiarismMatchLink ([f9bb866](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f9bb866a8b84fb18ab6b62328142f92b9abb9ee1))
* Remove main tutor from portfolio evidence ([5ee4f8f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5ee4f8fe6ced9a724a562573ea3616a95d0a4c86))
* Remove main tutor in test cases ([39acd18](https://github.com/doubtfire-lms/doubtfire-deploy/commit/39acd182a5810420f75d4a0857f28b6a386e526a))
* Remove multiple loggers as it is a helper to the Api class ([ad140ea](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ad140ea8527f06fb20fcdcbfab2291f09aeac47f))
* Remove need for cached similar to and task stats ([50016ba](https://github.com/doubtfire-lms/doubtfire-deploy/commit/50016bac69c7c830a10730142285e8a32b426940))
* Remove need for PDFTK ([7b9cb00](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7b9cb00a5e8f35e3c15daa0e54284cba9d55a162))
* Remove need for PDFTK ([08f456f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/08f456fca8277d6b93068803124e28da75331937))
* Remove non-printable characters from comments in portfolio ([cfe0947](https://github.com/doubtfire-lms/doubtfire-deploy/commit/cfe09477e28d11f387c1a16092287eb723864a6e))
* Remove old code that copied files into place ([639e12f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/639e12f9209b628caaa30ae69b1e30bccbe0ed50))
* Remove old spec ([185df83](https://github.com/doubtfire-lms/doubtfire-deploy/commit/185df831ad4f3d7e54e6147add361605aec90ae1))
* Remove old Task serialisers to fix task comments read in projects ([8e8299a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8e8299a677951ac9f25684a768d8d24a95268f99))
* Remove output from db helper ([5f5f14f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5f5f14f57b69f88ffc878776934be353db48e904))
* Remove paperclip extension from gemfile ([bc049b0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bc049b08d9598bb394eadf408c22fb0ce358f9b1))
* Remove populate command from Dockerfile ([142ff28](https://github.com/doubtfire-lms/doubtfire-deploy/commit/142ff28ea9dc23a9a75fcf1107ae7d185b588db3))
* Remove populator and faker gem for production ([0f15cca](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0f15cca92bcf8b7941832270993280a5ea954966))
* Remove portfolio compression ([eb28fa2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/eb28fa26f170c611c34bcdc7478a524952e9fa9a))
* Remove puts from task def post ([3580f30](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3580f30ac6bfb768749ca1a6e1018baf814498c0))
* remove reference to awaiting signoff in enrol student ([9f7ddf5](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9f7ddf599909f48766328cbf9dd7bdc9ef5b4e88))
* Remove referer check due to inconsistent browser behaviour ([2c91834](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2c91834691283bbe900235696c37bbf6ee78b801))
* Remove replica environment ([29c19ca](https://github.com/doubtfire-lms/doubtfire-deploy/commit/29c19caa3d744b6a689c2d78888bcb93fe7c0850))
* Remove student from group when withdrawn from unit ([4f2b72f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4f2b72f073717063a4389834709d38161cc461b6))
* Remove symbols to use values correctly ([95e4e41](https://github.com/doubtfire-lms/doubtfire-deploy/commit/95e4e416eb1440ffdda22ef5547f8cf324ac822a))
* Remove symbols to use values correctly ([ea764ad](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ea764ada5f7408495cc9631d4e44db21115757a2))
* Remove the authentication for teaching period information ([17b3f6d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/17b3f6db8b5f50df43bb9be423b927bfbb53f5c7))
* Remove the extra assignment line from add_task_definitions ([394a4af](https://github.com/doubtfire-lms/doubtfire-deploy/commit/394a4af778d6800f2a5d7523a97c1b619afd71cf))
* Remove theunit associations from teaching period ([21915b8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/21915b81492215d8043ffa568d550307024a6770))
* Remove tracing code from teaching period ([3084182](https://github.com/doubtfire-lms/doubtfire-deploy/commit/30841826e5ffe082bbed191b28f1e1e03a9398b2))
* Remove tracing statement from image compression ([47e0674](https://github.com/doubtfire-lms/doubtfire-deploy/commit/47e06742c4bb4bf7d1fa28206dec1683f373f5bc))
* Remove tracing statements from tex debugging ([3b33542](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3b33542f38cb04319d8176bfcd8285437ac2a6ab))
* Remove tutor name from project serialize ([e0603c4](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e0603c4669020844dc41a7bbae49bbeb8ba115e8))
* Remove tutor name from projects api ([9d89d47](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9d89d47417b3bd3dc33e0726a193ebdc18302e2f))
* Remove tutorial email and main tutor from email ([60fb2e8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/60fb2e8a3c8717f233269392f74ae882cbcde3e8))
* Remove tutorial id from project serializer ([60b28b3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/60b28b33d9b546a017ba655dce1f05cdcfffa21c))
* Remove un-needed code from project.rb ([f3f84e8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f3f84e85b25959e66d3a91e1643afa3c719e63c2))
* Remove unnecessary test code from previous commit ([528c897](https://github.com/doubtfire-lms/doubtfire-deploy/commit/528c8977fbd9e77fbd5d523532f732d5aba8f975))
* Remove unused 'notasks' ([0be129f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0be129fa3f52250dbb442b7ace28d5516d2ed34d))
* Remove unused replica tag from gemfile and install ([8001a3f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8001a3ff84f05bc9f97a347d20768741b97530fe))
* Remove unused replica tag from gemfile and install ([0dfd46c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0dfd46c84a17d894c86823e8d297379fba76ea0a))
* Remove unwanted spaces ([96b6a3f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/96b6a3f2fa9641698f0c2c199d1ea7409121bc26))
* Remove unwanted spaces from task.rb ([711eda2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/711eda2d6f0aaaceaac18667112b8d60b4de30dc))
* Remove unwanted spaces from units API ([6db3971](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6db3971df027c30f2a18eb15252fa4e70b9959d9))
* Remove unwanted spaces from user.rb ([0e3e095](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0e3e0953e3138230983bdecb52b830049ba60bd5))
* Remove use of Student Project Serialiser ([642ff86](https://github.com/doubtfire-lms/doubtfire-deploy/commit/642ff86bfa6ec109896118c9e96eee4c0daa5e72))
* Rename column group_number to number ([c83a62c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c83a62c1b5e1736b2ae32d95bbe1bf3febed7812))
* Rename setting to config.serve_static_files in production ([c811da8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c811da8183ca0565a048775b39337966a0e1b56f))
* Replace all Doubtfire references in the erb files ([f9c5f41](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f9c5f415016f8799796941ef8f2814cfada6a4f9))
* Replace assert with assert_equal ([efed739](https://github.com/doubtfire-lms/doubtfire-deploy/commit/efed739d8ff63a9899d1203720f16326216f3344))
* Replace has_one relationship with belongs_to ([5848588](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5848588f7844495a1f2593ac56601d5c46a8fb83))
* Replace main tutor with convenor in mailers ([1b5f9ae](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1b5f9ae8c3382d3669e7e71df45f9cf6eb3fd0cf))
* Replace main tutor with tutor for task def in erb ([6a505cd](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6a505cd063c2e0e3d88f79078c72ccee2da8a616))
* Replace not equal with greater than in max one tute enrolment ([59d1d89](https://github.com/doubtfire-lms/doubtfire-deploy/commit/59d1d8944ce8e5ed0efa7925d6ea8e0ef0b13aa5))
* Replace OnTrack with the doubtfire product name ([0d1239a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0d1239ae8ba560bcc89d34c0429a864a0fd39516))
* Replace roll_over with rollover ([696e495](https://github.com/doubtfire-lms/doubtfire-deploy/commit/696e495e6460432fb3b6884b7c090fdedd523292))
* Replace type with activity_type in the model ([8b5536d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8b5536dc5a754146c26a1b2ed9c9f940e5c59245))
* Require bunny-pub-sub in all environments ([bf75374](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bf753749b99a58e2af5731b8519c54b5fa7a5d3d))
* Restart postgres after Linux installation via setup script ([9dec0bf](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9dec0bf6d1c770f625a174c4ac1ba50db7ae1ee8))
* Retry code convert on fail using ascii ([1e22eca](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1e22eca2954f795ff7138f3ea5206c16f9649921))
* Return error if replying to invalid comment ([045e2f4](https://github.com/doubtfire-lms/doubtfire-deploy/commit/045e2f4d64c46081b38ed5c7c29b00c494d7f434))
* Return main convenor when tutor is nil ([39ddce5](https://github.com/doubtfire-lms/doubtfire-deploy/commit/39ddce5686c38069b40172868bff342ec010c2bb))
* Return result in teaching period information ([30a6b2e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/30a6b2ea2de3549f737aa99a594f5e286013d7a4))
* return start_date for unit role and project. Move authorisation to helper location ([a36e934](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a36e93400cdec04d527ce7f7e88a68c86f4df37b))
* Revert "EHHANCE: Modify api to support ..." ([41ba3ec](https://github.com/doubtfire-lms/doubtfire-deploy/commit/41ba3ec279a7605f14f4e2a985271f56946fc0cd))
* Revert changes to Gemfile.lock ([30e7e41](https://github.com/doubtfire-lms/doubtfire-deploy/commit/30e7e4199eff2d42d0ff346c947a4e70d253e2fb))
* Revert changes to schema ([22a58f1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/22a58f1ac22d8c84a44d2dcc9aeb6fbc66f54d9a))
* Revert error related to submission date ([623e5ec](https://github.com/doubtfire-lms/doubtfire-deploy/commit/623e5ec64b4ff7d926c6364469535e48c2624249))
* Rollback all db changes ([4eb5351](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4eb53516feafae51076f00fe1d5de684665c2d82))
* Routes param description for docker_image_name_tag ([eec9ed3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/eec9ed399407d1b2d7fd9bd4f8e8e06ef4faea88))
* Save the task def after current break ([1de336f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1de336f07c2291bfd0b07842c55f1daa6eb70f89))
* Serialise main convenor id ([f93054f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f93054fe5edb9bb8058a13a713ed57612dfb9dd7))
* Serialise main convenor id ([ce45dae](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ce45daed0cd3d3180379c3023b23ceda0d620e3e))
* Serialise main convenor id ([d627e34](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d627e3401d0b137c35655584653e95be29b56751))
* Set content type of discussion audio responses ([c4b9aef](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c4b9aef545d5f7b4ad03eeba3ff5c149447b8b48))
* Set default RAILS_ENV in Gemfile to be development ([b16943b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b16943b5fa9f1147c88b2fb6f71f7dba52c1383e))
* Set default units.assessment_enabled to true ([d2b1c89](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d2b1c89211daf4d746d1b753bcbc7dd40b924507))
* Simplify creation of streams based on activity type ([724255b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/724255b077ebd2ab417bbf0b52a66c8df70fd564))
* Simplify fetching a tutorial ([1959196](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1959196fe24b484c94440613893cc477af4f6c66))
* Simplify test for validation of extension ([1010eb0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1010eb0387297c0bd7709809092185cf08e02cad))
* simulate signoff to better represent real usage ([e2b79db](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e2b79db36b09add5bc0c7946c89aaf729e0e7fbe))
* some performance issues and add task completion stats ([bfb002c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bfb002ca98b318c0e64994c1c56f0f7b885b81ea))
* Staff count in tutor for task test using new factory ([7d93e9b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7d93e9bf148fbc2d74531243d3dfa7db512a01e0))
* Start and end dates for weekly emails ([e0fdedb](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e0fdedb4bbc09eb35b3b978f7650f1dd40d65eb1))
* Store the campus created by Factory girl inside unit factory ([fc5dc11](https://github.com/doubtfire-lms/doubtfire-deploy/commit/fc5dc119ab76df50efbd033dc4c4564f8c626c33))
* Strip path till submission history for easy mounting ([c3d43b0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c3d43b01c1a4d9fdc2b68ca048c4a364bdf03f4a))
* Strip till /doubtfire-api instead ([e0b599c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e0b599c9012fcf7f24d4166e22119e4d23d27103))
* Student returned on enrol ([13d7b91](https://github.com/doubtfire-lms/doubtfire-deploy/commit/13d7b91ba606a3b505c33401b8f47287359f1e45))
* Submission date check in burndown data ([1aef3e5](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1aef3e5513a262c3d797421f8fbc3ee9326af877))
* Submission for needs help sets submission date ([32641a9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/32641a96af0b432aa1232a0a12cc752c3a4f63e0))
* Switch gsub in lesc to ensure running on text ([6084c45](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6084c454aaef28c2db66874c184574a7cd36863a))
* Switch Portfolio generation to Latex ([c0de443](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c0de443d8b312e49d86f147486de22635e0514d9))
* Switch queries to fetch tasks based on id rather than name ([e24248b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e24248b3d3a2b2b29de302eb167071134f045e03))
* Switch rollover to use day/week for task defsSimplify the logic to make use of the date for week and daycode. Going forward this should be the way oftracking task dates. ([38cb540](https://github.com/doubtfire-lms/doubtfire-deploy/commit/38cb5408476ee76e690b5642369f27c385086469))
* Switch task definition to use docker image model ([68212eb](https://github.com/doubtfire-lms/doubtfire-deploy/commit/68212eb7093cdb4b36b678e8125a770cb64e29b3))
* Switch to error code 400 for known client errors ([70a42a0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/70a42a0c903f7281ea897059a0c834bc44098333))
* Switch to hashed resources to help keep clients up to date ([1bfedbf](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1bfedbfeaa165678fb9770e8daa0253eaeb10ecb))
* Switch to lualatex to better support UTF input ([65ba465](https://github.com/doubtfire-lms/doubtfire-deploy/commit/65ba46569a203920fb8a55eba3f4493cef07c91b))
* switch to rails logger in log helper. Ensure failures in pdf generation are written to the terminal for cron to email admin. ([662cc4c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/662cc4cd369cf37ff9ccb5e16e11e7bc8d748e16))
* Switch to unoptimised and hashed output ([3b47d0e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3b47d0ed59a9e60faf456646557d93cde7e4209a))
* Switch to use due date in burndown chart ([46f4b9e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/46f4b9e29da9920e5226347edef86bc73dffa12b))
* Switch to use new portfolio creation with latex ([abccb6a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/abccb6a1ed74cd13e3ef50b2728c6f87962d3080))
* Take dates either from period or manually ([3946574](https://github.com/doubtfire-lms/doubtfire-deploy/commit/39465741ac9d21f260694cd3c8ea0211ab7013cd))
* Task comments generation ([91eacae](https://github.com/doubtfire-lms/doubtfire-deploy/commit/91eacae50a5b5989e975034421bf65378efef963))
* Task csv columns to match student task status ([bb534f6](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bb534f643fc1897b88ae67668f752cf2970cbace))
* task for task definition to use object ([339ba2b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/339ba2bd8bf176f5c8e24a3c0b2c5640c45ca7a5))
* Task inbox to return unique with multiple streams ([0e2eaab](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0e2eaab16dc59e329a4e2366eac49a6ed3365de7))
* Task PDF importer report success and be more flexible ([fa3d667](https://github.com/doubtfire-lms/doubtfire-deploy/commit/fa3d667ef53e9a85706c574e6f57eee70fbf9d72))
* Task status changes bug and limitations ([2b4b09b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2b4b09bc4d4a7e85f5c16015790ebc58bdbda5bc))
* Task status error ([01a0f9e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/01a0f9edceae11674898abf1700f055ba20d97f9))
* Teaching Period create method ([8dd2681](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8dd2681c20093944d9034c0a572c00f4623ace7f))
* Teaching Period create method ([9f1dfbd](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9f1dfbd7f114626f013f629f72ba203edc71b6fc))
* Teaching Period errors ([23b25df](https://github.com/doubtfire-lms/doubtfire-deploy/commit/23b25df97d7f11e5e92c2004ca193e9174aaad97))
* Teaching Period Indentation ([b5c96ed](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b5c96edf4a5a2ec247b923dd263d3e651c29134f))
* Teaching period typo throwing error ([9df4c96](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9df4c96cc06fa60905135766dc67d0f119655bf4))
* Teaching Period update return value ([0456ead](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0456eadc282d90f31d733e553e05503ad9ab8107))
* Ternary operator in plagiarism match link ([595a65a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/595a65a45a74e36b5b262aa67090de8ca4bc631d))
* Test for file upload in task def csvs ([1939c91](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1939c91377df961582d6ab99a751048e3238b741))
* test moving file into place ([fe0681d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/fe0681d5c40965f64ac481255106bbeb340bbf49))
* Test task csv with new columns ([5f893ee](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5f893ee47812fd85e8d5a582e0ad23b254e45420))
* The error statement in add break ([6c7eb01](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6c7eb01d2d14e288ab6cba6f21f00beb443184ef))
* The preliminary line in the summary ([4b7694a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4b7694a836880ce62c21e216f099070ece0ba58c))
* Timeout of token should redirect to sign in ([bb9b0d8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bb9b0d889cbf9150203b50a87141c450b0e4f174))
* transitions on tasks propagate even when no prior group submission -- assumes even distribution ([b2a53d0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b2a53d0af7ab072998fcf65cfaddfe5912b767b6))
* Trial CI PDF creation fix ([e5f8248](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e5f8248dcc27189c56c4bbf29f4ba3ffee3e14bb))
* Tutorial check in groups validation ([27b4835](https://github.com/doubtfire-lms/doubtfire-deploy/commit/27b4835702fed90debb41cc722b8b4bd956b2508))
* Tutorials without streams mapping in student query ([2341ba5](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2341ba5c9a071bbbf3a14a24062e9af47dbd6fb7))
* Typo in application.rb ([9e8e930](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9e8e9301e6a437f8b7705eacd059ea19c9c92599))
* Typo in grades url on frontend ([23521d0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/23521d0fce2b87bccdadb45adbc61572ef17c405))
* Typo in grades url on frontend ([aea3829](https://github.com/doubtfire-lms/doubtfire-deploy/commit/aea382992e1f46e2de0bd1452bd3e2a2aba88a01))
* Typo in Tasks.rb ([dfc3517](https://github.com/doubtfire-lms/doubtfire-deploy/commit/dfc3517569f76176fb2b50e5379b84c30f176345))
* UI fix to add missing enrol modal ([8655809](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8655809daee6f6294a35cf5c861a159ac880adc1))
* ui issues related to pdf viewer size, and pagination on grading tab ([96fb606](https://github.com/doubtfire-lms/doubtfire-deploy/commit/96fb6066171bfa5a8e23465383d51220cd3476d1))
* Unit dates accessor ([0aeb4a8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0aeb4a8f595bb7f9410b0bcdc4d434eab45192a5))
* Units start date errors ([204a0e1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/204a0e18d73410a00d29a43b21951c13694a5095))
* Update ./setup.sh ([c693a88](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c693a880c8062e1a38f2596ab920967a8715617a))
* Update ./setup.sh git source for rbenv ([5ad2a64](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5ad2a646044dc32c3a21a59e030158d3c3ce7167))
* Update adding and removing to active group members ([bb0d405](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bb0d405f65d4f37c766a2c36baed704092a9220a))
* Update bunny-pub-sub version ([6e3cbe5](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6e3cbe557959e28823b558ec7bdc514beb4579bf))
* Update bunny-pub-sub version in Gemfile.lock ([971eb80](https://github.com/doubtfire-lms/doubtfire-deploy/commit/971eb802a37871296228fdfca02a8347f85f1fa6))
* Update calculation of task status ([b2cfef1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b2cfef162070f72786fb2110f7c6f1727570467d))
* Update callista data import format ([6dd489e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/6dd489e8e0d059c4287e58d1f915af08edfeb971))
* Update compress image use of convert ([ae597d9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ae597d956bb38c62340c692143ecf2208c6039a0))
* Update config in compose to include production ([941ea1c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/941ea1c2b760f5a4fdcda9f80632f16471efcfca))
* Update database schema ([dd5dbf9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/dd5dbf91d1e63fb217dff576b348f0ee8ba1f8e4))
* Update docker-compose run command to use rails ([97c45df](https://github.com/doubtfire-lms/doubtfire-deploy/commit/97c45dfefd13a1063d5c3e082c9e2b112cf7c754))
* Update error message in unit details editor ([3f7b71c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3f7b71c6517be74d7dbf5c9a6635eeb6ac8f1e08))
* Update exception handling to capture exceptions ([5086a19](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5086a19c0b6a7d97515686ad23dbf67c54e62af4))
* Update font awesome ([b509be3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b509be32cff51deea1765579fb3734e424bd6d45))
* Update get campus to avoid duplicate error ([27fc53c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/27fc53cb1812367878d9c77c40d056fc4eeb48e5))
* Update message before stats in html email ([3662193](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3662193abd70d018bfa74faaeac2051383e9c5d7))
* Update message before stats in text emails ([be0cff3](https://github.com/doubtfire-lms/doubtfire-deploy/commit/be0cff3fbeb04c7a9e8ec615b6c1b64a06e4d680))
* Update overseer actions to work with new structure ([96836d2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/96836d200dbcdc9bc1c11e4e99dc09e71890b7c4))
* Update overseer config to use new fixed settings ([a520b64](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a520b64a53e026caa8828777ac998fd5218a01f8))
* Update path checking in files for submission test ([295d7f6](https://github.com/doubtfire-lms/doubtfire-deploy/commit/295d7f6c4ff6f5e8529e4cfe097d5c31a3a1ac42))
* Update PDF viewer api ([a0ead5a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a0ead5a3abb0a112bc64e20d579b205b14e5550f))
* Update production server API URL to root ([ba8f9b9](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ba8f9b97e59d2469d31d079a1b887415d436d43a))
* Update production server API URL to root ([34d4d99](https://github.com/doubtfire-lms/doubtfire-deploy/commit/34d4d991e6af705d7c67e98040a0dc34615dfa6f))
* Update some log messages to include additional info ([7406ee2](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7406ee2ea6ca6039a1729ca048e5c524e1dd3e91))
* Update sync script for importing students ([b11d9cd](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b11d9cdbd90b1224ce26e766fd49df85a7d6b422))
* Update task completion csv with group and stars ([0f74fa6](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0f74fa607e65ba9dd3d90ba0bf431d5e5c23f64a))
* Update task dependencies ([c59bc20](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c59bc207f7c046d068b13bf08ece5276e78e11b0))
* Update task returns a value to indicate success ([e1243cc](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e1243cc52a4462d893fdc2a726a2ed645b96ad04))
* update task stats to have fail and demonstrate ([1a4a43a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/1a4a43a37e68e3ce92ed5634835f84e3d2be90a0))
* Update task status trigger text ([813c31c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/813c31c64ffbe04f1c5632e8be99025a1ba3af9d))
* update task status weights for ILO progress calculations ([ca9c1fe](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ca9c1fef5b8d1127f639c9eb45cbfddb518bfe7b))
* Update text size to 4096 ([b0c989f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b0c989f15c1a13ecb34bf38f0a7f8deed45d8c1b))
* Update tutorial enrolment factory to ensure unit and campus are same ([8dde407](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8dde407b18f701126a5cd356b1f709ca82b6851a))
* Update tutorial should not stream ([138af9b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/138af9b617181adadd3eeac2468dfbf2be9cf6ab))
* update UI resolving duplicate enrolments ([96aa913](https://github.com/doubtfire-lms/doubtfire-deploy/commit/96aa913e20b1116440ddfe39d9afe4cfe47536ec))
* Update UI to accept text code files ([db34f90](https://github.com/doubtfire-lms/doubtfire-deploy/commit/db34f909dbaa005712209d34b55cbf60a1567556))
* update ui to fix issue with unit creation start dates/times ([acc8446](https://github.com/doubtfire-lms/doubtfire-deploy/commit/acc844619f1f5fe9c74d032782f150be49be2416))
* update UI with changes to fix issues identified with task admin ([9014afd](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9014afd29dc86640ef896bffd8809ddbbc79c029))
* Update UI with fixes ([5535199](https://github.com/doubtfire-lms/doubtfire-deploy/commit/55351992232ba0f3dd73b0dbc3b274bbcfe70552))
* Update UI with fixes and new portfolio process ([e74c02b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e74c02b64375b82d660feecdafc16429af8ecf87))
* Update ui with fixes for publishing comments ([9238bc5](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9238bc5cb99b73732b6c34cfcbd6afeab126b0f8))
* Update UI with fixes for the Task list ([ab03ede](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ab03ede4e7ce9e46cde4343c2fe08040bb5b6643))
* update ui with fixes from usability tests ([cb0a19e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/cb0a19e2f039c6b89d349a4eb9262a554ab5bc81))
* update ui with fixes from usability tests ([7c8dab7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7c8dab76e5b951fd8de89b35988765e17b822a8e))
* Update UI with grading improvements ([8932381](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8932381024f558162e81b6a1e675c6afea1311e2))
* Update UI with gview or object for PDF ([91b7347](https://github.com/doubtfire-lms/doubtfire-deploy/commit/91b7347fbd8224d26f24bc29934f2b6fa6c76c19))
* Update UI with new portfolio assessment pages ([2253a9a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2253a9aba85c7530fc0cb4e47882a622210ee1ad))
* Update UI with new task assessment details ([95864b1](https://github.com/doubtfire-lms/doubtfire-deploy/commit/95864b1408e4f74907bbb3dc3fba1ee4c2839ca7))
* Update UI with new task assessment details ([5c9a53d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5c9a53df73f84055ebeea51abc3a30d69b3e395e))
* Update UI with safari pdf viewer ([5aa4842](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5aa48425e7cb58668e25dd4bef21a798b1196112))
* Update UI with task pdf upload changes ([9900f1a](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9900f1a17d6105fad92084f938c1bdcaec8ed808))
* update UI with unit dates for home page ([ec4afc0](https://github.com/doubtfire-lms/doubtfire-deploy/commit/ec4afc04ba10bd8201f793821ad1ee92a0f31506))
* Update urls to use https in mailer tasks ([c68e13c](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c68e13cad521fdad64dedc4bc88eb8d4cd159c94))
* Update web command to npm start in docker-compose ([554be09](https://github.com/doubtfire-lms/doubtfire-deploy/commit/554be09f9e1277b10493032e2724b2f01c6e1b32))
* Update weekly student status email. Only if no portfolio ([94a7d43](https://github.com/doubtfire-lms/doubtfire-deploy/commit/94a7d430099d9870e8ddadbbeb807427aced52e5))
* updating grade calculates project task stats ([b1b925d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b1b925d5c9190b2410866784a78211fbc2999b54))
* Uploading new files replaces existing files in student_work/new/task_id folder ([a8a4563](https://github.com/doubtfire-lms/doubtfire-deploy/commit/a8a4563fa372479e4b61c4a9646d19753e711702))
* Use auth_helper methods in api endpoint tests for auth ([9bed401](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9bed4018fed3a2caa00677ce62a2782931ff565c))
* Use campus instead of campus_id ([17f464e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/17f464eed680ccdd5d184eff51a5a83d1580bcef))
* Use correct host path for cover page ([bee7dab](https://github.com/doubtfire-lms/doubtfire-deploy/commit/bee7dab964017c9d42e05a6983f5d55fb5ee5a05))
* Use correct institutional host for mailers ([2497802](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2497802e7fc060af7599b72cec1e64aef2393463))
* Use correct key for plagiarism file data ([b937d9d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b937d9d35b79de89b6570257c5c6f8408ebfe03d))
* Use correct uniqueness validator in activity type model ([9292051](https://github.com/doubtfire-lms/doubtfire-deploy/commit/9292051ec529bf9002c996e83c68701e63aa9a56))
* Use correct values in methods ([248cf69](https://github.com/doubtfire-lms/doubtfire-deploy/commit/248cf692245f4079b4e7aa78761b8b419c1a125c))
* Use correct values in methods ([4d92357](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4d92357aeb61e011b3b85b416077f4fe8786de00))
* Use cross institutional domain for default user ([de06416](https://github.com/doubtfire-lms/doubtfire-deploy/commit/de06416d016d3db51e621850719bbb762db77717))
* Use Doubtfire logger as rails logger ([b6e4a6e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/b6e4a6ef47dee7007d372fc1062dbe3bd95140a2))
* Use file helper directly from within user model ([c104110](https://github.com/doubtfire-lms/doubtfire-deploy/commit/c1041103db20d720d07a53b5fd195ac7c7ac2953))
* Use first administrator email if no convenors ([0f445f8](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0f445f8de9f29012b56e2a853fc8b75b2f1fe243))
* Use id lookup for another case of status lookup ([37c2b0b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/37c2b0bebd6b48af31757061e1b1b2efc40b78d8))
* Use institution name for task and portfolio generation ([92269b4](https://github.com/doubtfire-lms/doubtfire-deploy/commit/92269b4c61ea0032a6761551e6800566f76811ac))
* Use just the filename for the image in tex ([2bce49e](https://github.com/doubtfire-lms/doubtfire-deploy/commit/2bce49e6371581a501828339b7e62c8357f0c2a1))
* Use name instead of nickname for comments GET ([4d56c26](https://github.com/doubtfire-lms/doubtfire-deploy/commit/4d56c26ce385ae4029ccf9a371ab1e6cd8257c43))
* Use name instead of nickname for comments GET ([cb58d46](https://github.com/doubtfire-lms/doubtfire-deploy/commit/cb58d46c85ffb5248e9ee9c2c815030756472b81))
* Use new to create Breaks ([55a2280](https://github.com/doubtfire-lms/doubtfire-deploy/commit/55a2280ad746c4456ad635e7086fee11469bc173))
* Use outer join in get all projects ([baad4bd](https://github.com/doubtfire-lms/doubtfire-deploy/commit/baad4bdf0adb03052994e80ecee5d430e99808b3))
* Use single query to retrieve webcal tasks, fix webcal MIME type ([8253e15](https://github.com/doubtfire-lms/doubtfire-deploy/commit/8253e15a82dc076e7f53e3d9957b865ef0e284d4))
* Use time_created of receipt for read time ([86ba70d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/86ba70d6c4bfa81c8e7bbfb92b85ebb99f810129))
* Use tutorial enrolments for checking group tutorial ([d5cb9ad](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d5cb9adcb9cbae046946f5940eb9c4c0c60338db))
* Use unit for enroling project in a tutorial ([7e33418](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7e334189dbf207e5e7b4f76f420877fb3324bdae))
* Use updated enrol student for populator ([71e9d59](https://github.com/doubtfire-lms/doubtfire-deploy/commit/71e9d591e7e3e37e150de2a512a203510230321b))
* use validations in tutorial creation to ensure tutorial abbreviation is unique. ([3855591](https://github.com/doubtfire-lms/doubtfire-deploy/commit/38555919cb00cedd113a8dd93c8ea5d6926e5395))
* Validate exactly one of teaching_period or dates must be present ([0edaaef](https://github.com/doubtfire-lms/doubtfire-deploy/commit/0edaaefd5fed3be95c1229237e0b2f3f9782cd7a))
* Validate text length in rails to avoid sql errors ([7f78668](https://github.com/doubtfire-lms/doubtfire-deploy/commit/7f7866883d1156cf2d4e7c76e1c809cb51a85fca))
* Validate that active is true or false ([d71c944](https://github.com/doubtfire-lms/doubtfire-deploy/commit/d71c9442121a0aedc562ce7d7fa0e4158425a43d))
* Validation failed msg in break not colliding ([f7a9cce](https://github.com/doubtfire-lms/doubtfire-deploy/commit/f7a9cce2d1f0d3c0fddc0cb6a3c4fd48aa420bc3))
* Validation for docker_image_name_tag now respects nil values ([23408f7](https://github.com/doubtfire-lms/doubtfire-deploy/commit/23408f76b6d173ff5e36c8a8072096f234e8af1b))
* Validators for docker_image_name_tag ([372fe97](https://github.com/doubtfire-lms/doubtfire-deploy/commit/372fe97235584a291b4a8ddb97d109d4cfe50595))
* Variable name ([5303ceb](https://github.com/doubtfire-lms/doubtfire-deploy/commit/5303ceb48be6d9e768a67560b84bd5a8e20c2f7c))
* Weekly Email Summary ([145a48d](https://github.com/doubtfire-lms/doubtfire-deploy/commit/145a48d6e2ad81eff1fb8e15df0bdb17aa5127d9))
* Whitelist Tutorial.find_by_user ([e74760f](https://github.com/doubtfire-lms/doubtfire-deploy/commit/e74760f4627720738e0b0c71b4ef891d1b073077))
* YAML Docker image name, disable image ([3fe985b](https://github.com/doubtfire-lms/doubtfire-deploy/commit/3fe985bc6fc8b223eb9e6f8c5927d0def4612f64))

MindMup - Zero Friction Mind Map Canvas
=======================================

[![Build Status](https://api.travis-ci.org/mindmup/mindmup.png)](http://travis-ci.org/mindmup/mindmup)

MindMup is a zero-friction mind map canvas. Our aim is to create the most productive mind mapping environment out there, removing
all the distractions and providing powerful editing shortcuts.

This git project is the server-side portion of MindMup. It provides a web interface that serves maps, allows users to edit and save them,
provides menus and feedback forms and links to analytics. You can see an example of this live on http://www.mindmup.com.

Dependencies
-------------

- This app is designed to run in the Heroku cloud or as a standalone [Sinatra application](https://github.com/sinatra/sinatra/).
- It depends on the [MapJS](http://github.com/mindmup/mapjs) javascript canvas for client side rendering, and imports a compiled
single-file version of that project as /public/mapjs-compiled.js
- It uses Google Drive and Amazon S3 AWS service to store maps
- It uses Google analytics to track feature votes, usage patterns and report error rates
- It uses Google URL shortener to produce short links for sharing

Configuration
-------------

The server depends on the following environment variables:
- GOOGLE_SHORTENER_API_KEY _Google shortener API key_
- GOOGLE_CLIENT_ID _Google Drive Client Id_
- GOOGLE_ANALYTICS_ACCOUNT _Google analytics ID to use for tracking. Don't use the production IDs in staging. Not used in dev and testing_
- S3_BUCKET_NAME _Only the name of S3 Bucket where files are located (eg mindmup)_
- S3_KEY_ID _AWS Access key ID that has write access for the bucket_
- S3_SECRET_KEY _AWS Secret key corresponding to the ID above_
- S3_UPLOAD_FOLDER _folder within the bucket where user maps are stored. (eg map). Avoid using the same folder for production and testing_
- S3_WEBSITE _website domain name where user files are publicly accessible. Don't specify protocol or slashes (eg mindmup.s3.amazonaws.com)_
- SITE_URL _public URL for the web site instance, used to get S3 to redirect back to us. Include protocol and slashes (eg http://localhost:5000/)_
- DEFAULT_MAP _name or key of the map to be shown on homepage (eg default)_
- RACK_SESSION_SECRET _hashing key for rack sessions (should be relatively random, alphanumeric)_
- MAX_UPLOAD_SIZE _in KB, maximum size allowed for the users to upload. If not defined, 100 is the default value_
- NETWORK_TIMEOUT_MILLIS _number of milliseconds before we start reporting to users that there is a problem, in case of a timeout. Default is 10000._
- CURRENT_MAP_DATA_VERSION _prefix for files signaling the data format. For now, we use a1. This is to help in the future with format versioning_

Running standalone
------------------

To run the application in standalone mode (without Heroku), create a .env configuration file (_don't commit this to git_) and put your S3 account info
and other stuff mentioned above into that. You don't need a JotForm account to run the site (but sharing and feedback won't work without it). Then
execute:


    gem install foreman
    bundle install
    foreman start

For offline use You also need to either setup your own CDN (see [issue 69](https://github.com/mindmup/mindmup/issues/69)) or deploy the ```content/{img,font,<datetimestamp>}``` folders from [the static.mindmup.com repo](https://github.com/mindmup/static.mindmup.com) to ```public/``` here. i.e. 
* clone or checkout https://github.com/mindmup/static.mindmup.com,
* cd to that checkout and run ```sh pack.sh```. 
* Then copy with ```cp -pr content/{img,font,20*} <path to mindmup>/public``` (NB: do this before the year 2100 or the command won't work).
* Then edit ```web.rb``` and set ```public_host``` to ```0.0.0.0:5000``` and ```static_ts``` to the output of the command ```(cd public && echo 20*|sort|tail -n1))```.
* Finally restart the mindmup server ```foreman start```.

See [Heroku Configiration Local Setup](https://devcenter.heroku.com/articles/config-vars#local-setup) for more information.

Note: Unless RACK_ENV is production, Google analytics is not used, the analytics information is instead logged to the JavaScript console.

Executing tests
---------------

We do a bunch of exploratory tests and some manual sanity tests before each release,
and use this [ACC Matrix](https://github.com/mindmup/mindmup/wiki/Attribute%2C-Component%2C-Capability-matrix) to guide testing. Most client tests
are in the MapJS project, so see that as well. This server does very little apart from some basic routing, so there are not many automated tests
in this project. For server testing, there are a few RSpec tests that should run before commiting. Execute them with:

    rspec test/*.rb

The tests don't depend on the .env file intentionally. Supply your own config as part of the test if needed.

All JavaScript widgets are tested using Jasmine, here are two ways of running tests:

- Visual: Open SpecRunner.html in a browser, this will run all Jasmine tests

- Automated: Using [PhantomJs](phantomjs.org), in the test folder, run

    sh runtests.sh

Please note that the CI server uses phantomjs, so make sure that tests run with phantom before committing.


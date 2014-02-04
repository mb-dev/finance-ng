# global install: nodejs, gulp, forever, coffee-script, bower
# copy config
sudo stop site-finance
git pull
npm install --production
bower install --config.interactive=false
gulp build
sudo start site-finance

homeSection = require('../sections/home/home')
userSection = require('../sections/user/user')
dataSection = require('../sections/data/data')

module.exports = (app, passport) ->
  app.get('/auth/google', passport.authenticate('google', {
    successRedirect: '/login_success',
    failureRedirect: '/login'
    scope: [ 'https://www.googleapis.com/auth/plus.login', 'https://www.googleapis.com/auth/userinfo.email' ]
  }))

  app.get '/auth/google/callback', passport.authenticate('google', {
      successRedirect: '/login_success',
      failureRedirect: '/login'
    })

  app.get '/auth/check_login', userSection.isLoggedIn

  app.get '/data/authenticate', dataSection.authenticate
  app.get '/data/:appName/:tableName', dataSection.getDataSet
  app.post '/data/:appName/:tableName', dataSection.postDataSet
  app.all '/*', homeSection.index

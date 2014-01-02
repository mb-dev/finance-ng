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

  app.get '/data/datasets', dataSection.getDataSets
  app.get '/data/authenticate', dataSection.authenticate
  app.post '/data/datasets', dataSection.postDataSets

  app.get '/data2/:appName/:tableName', dataSection.getDataSet2
  app.post '/data2/:appName/:tableName', dataSection.postDataSet2
  app.all '/*', homeSection.index

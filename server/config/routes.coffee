homeSection = require('../sections/home/home')
userSection = require('../sections/user/user')
dataSection = require('../sections/data/data')

module.exports = (app, passport) ->
  app.get '/auth/google', passport.authenticate('google', {
    successRedirect: '/login_success',
    failureRedirect: '/login'
    scope: [ 'https://www.googleapis.com/auth/plus.login', 'https://www.googleapis.com/auth/userinfo.email' ]
  })

  app.get '/auth/google/callback', passport.authenticate('google', {
    successRedirect: '/login_success',
    failureRedirect: '/login'
  })

  app.post '/auth/login', (req, res, next) ->
    passport.authenticate('local', ((err, user, info) ->
      return next(err) if err
      if !user
        res.json 401, {message: info.message}
        return
      req.logIn user, (err) ->
        if err
          console.log err
          return next(err) 
        next(null)
    ))(req, res, next)    
  , userSection.login

  app.post '/auth/register', userSection.register
  app.post '/auth/logout', userSection.logout

  app.get '/auth/check_login', userSection.checkLogin

  app.get '/data/authenticate', dataSection.authenticate
  app.get '/data/:appName/:tableName', dataSection.getDataSet
  app.post '/data/:appName/:tableName', dataSection.postDataSet
  app.get '/*', homeSection.index

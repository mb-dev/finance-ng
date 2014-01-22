mongoose = require('mongoose')
GoogleStrategy = require('passport-google-oauth').OAuth2Strategy
User = mongoose.model('User')
LocalStrategy = require('passport-local').Strategy
# googleapis = require('googleapis')
# OAuth2 = googleapis.auth.OAuth2Client

# oauth2Client = new OAuth2(config.google.clientID, config.google.clientSecret, config.google.callbackURL)
# oauth2Client.credentials = {
# access_token: accessToken,
# refresh_token: refreshToken
# }
# googleapis.discover('plus','v1').execute (err, client) ->
# client.plus.people.get({'userId': 'me'}).withAuthClient(oauth2Client).execute (err, result) ->
# if err
#   done(error)
#   return

request = require('request')

module.exports = (passport, config) ->
  passport.serializeUser (user, done) ->
    done(null, user.id)

  passport.deserializeUser (id, done) ->
    User.findById id, (err, user) ->
      done(err, user)

  passport.use(new LocalStrategy({
      usernameField: 'email'
    },
    (username, password, done) ->
      User.findOne { email: username }, (err, user) ->
        return done(err) if err
        return done(null, false, { message: 'Unknown user ' + username }) if !user
        user.comparePassword password, (err, isMatch) ->
          return done(err) if err
          if isMatch
            if !user.approved
              done(null, false, { message: 'User not approved'}) 
            else
              done(null, user)
          else
            done(null, false, { message: 'Invalid password' })
  ))

  passport.use(new GoogleStrategy({
    clientID: config.google.clientID
    clientSecret: config.google.clientSecret
    callbackURL: config.google.callbackURL
  },  
  (accessToken, refreshToken, profile, done) ->
    console.log 'user profile'
    console.log profile
    User.findOne { googleId: profile.id }, (err, user) ->
      if !user
        user = new User({
          name: profile.displayName,
          email: profile.emails[0].value,
          provider: 'google',
          googleId: profile.id,
          authToken: accessToken
        })
        user.save (err) ->
          if (err) 
            console.log(err)
          else
            console.log 'saved user for session', user
            done(err, user)
      else
        user.name = profile.displayName
        user.email = profile.emails[0].value
        user.authToken = accessToken
        user.save (err) ->
          done(err, user)
  ))

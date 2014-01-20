mongoose = require('mongoose')
GoogleStrategy = require('passport-google-oauth').OAuth2Strategy
User = mongoose.model('User')
LocalStrategy = require('passport-local').Strategy

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
          googleId: profile.id
        })
        user.save (err) ->
          if (err) 
            console.log(err)
          else
            console.log 'saved user for session', user
            done(err, user)
      else
        user.accessToken
        done(err, user)
  ))

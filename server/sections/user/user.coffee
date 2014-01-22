mongoose = require('mongoose')
User = mongoose.model('User')

exports.checkLogin = (req, res) ->
  if req.isAuthenticated()
    res.json 200, {user: {id: req.user.id, email: req.user.email, lastModifiedDate: req.user.lastModifiedDate, name: req.user.name }}
  else
    res.json 401, {reason: 'not_logged_in'}


exports.register = (req, res) ->
  if !req.body.email || !req.body.password  || !req.body.name
    res.json 400, { error: 'Missing any of the following: email, password, name' }

  User.findOne { 'email' :  req.body.email }, (err, user) ->
    if (err)
      res.json 500, { error: err }
      return   
    
    if (user) 
      res.json 400, { error: 'Email is already taken' }
      return
    
    newUser = new User()
    newUser.email    = req.body.email
    newUser.password = req.body.password
    newUser.name = req.body.name

    newUser.save (err) ->
      if (err)
        res.json 500, { error: err }
        return         
      else
        res.json 200, { success: true }

exports.login = (req, res) ->
  res.json 200, {user: {id: req.user.id, email: req.user.email, lastModifiedDate: req.user.lastModifiedDate, name: req.user.name }}

exports.logout = (req, res) ->
  req.logout()
  res.json 200, { success: true }    
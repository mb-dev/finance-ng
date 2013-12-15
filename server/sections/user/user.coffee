exports.isLoggedIn = (req, res) ->
  req.isAuthenticated()
  res.json 200, { "email": req.user.username }
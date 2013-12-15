exports.partials = (req, res) ->
  console.log "render #{req.params[0]}"
  res.render('../../app/views/partials/' + req.params[0])

exports.index = (req, res) ->
  console.log 'rendering home index'
  res.render('home/index')

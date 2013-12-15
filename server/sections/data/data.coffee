fs = require('fs')
async = require('async')
path = require('path')

filePrefix = path.normalize(__dirname + '../../../../data_files')

fileLocation = (userId, fileName) ->
  folder = filePrefix 
  if !fs.existsSync(folder)
    fs.mkdirSync(folder)
  folder = folder + '/' + userId.toString()
  if !fs.existsSync(folder)
    fs.mkdirSync(folder)

  folder + '/' + fileName + '.data'

exports.getDataSets = (req, res) ->
  if !req.isAuthenticated()
    res.json 403, { reason: 'not_logged_in' }
    return

  dataSets = req.query.dataSets || []
  
  readFile = (dataSet, callback) -> 
    fs.readFile fileLocation(req.user.id, dataSet), (err, data) ->
      if(err && err.errno == 34)
        console.log 'return empty content for file', dataSet
        callback(null, {name: dataSet, content: null})
      else if(err)
        console.log 'error reading file', err
        callback(err)
      else
        callback(null, {name: dataSet, content: data})

  async.map dataSets, readFile, (err, dataSets) ->
    if err
      console.log('read failed', err)
      res.json 400, {reason: "read_failed"}
    else
      res.json 200, {data: dataSets, user: {email: req.user.email}}

exports.postDataSets = (req, res) ->
  if !req.isAuthenticated()
    res.json 403, { reason: 'not_logged_in' }
    return

  if !req.body
    res.json 400, { reason: 'data_sets_missing' }
    return

  saveFile = (dataSet, callback) -> fs.writeFile fileLocation(req.user.id, dataSet.name), dataSet.content, callback
  async.each req.body, saveFile, (err) ->
    if err
      console.log('Write failed', err)
      res.json 400, {reason: "write_failed"}
    else
      res.json 200, {message: "write_ok"}

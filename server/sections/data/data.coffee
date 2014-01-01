fs = require('fs')
async = require('async')
path = require('path')
Lazy = require('lazy.js')

filePrefix = path.normalize(__dirname + '../../../../data_files')

fileLocation = (appName, userId, fileName, createIfMissing) ->
  folder = filePrefix 
  if !fs.existsSync(folder) && createIfMissing
    fs.mkdirSync(folder)
  folder = folder + '/' + userId.toString()
  if !fs.existsSync(folder) && createIfMissing
    fs.mkdirSync(folder)
  folder = folder + '/' + appName
  if !fs.existsSync(folder) && createIfMissing
    fs.mkdirSync(folder)

  folder + '/' + fileName + '.data'

validLocation = (appName, userId, fileName) ->
  location = fileLocation(appName, userId, fileName, false)
  location = path.normalize(location)

  if(!Lazy(location).startsWith(filePrefix))
    console.log('invalid location: ' + location)
    return false

  return true


exports.authenticate = (req, res) ->
  if !req.isAuthenticated()
    res.json 403, { reason: 'not_logged_in' }
    return

  res.json 200, {user: {email: req.user.email, lastModifiedByApp: req.user.lastModifiedByApp }}

exports.getDataSets = (req, res) ->
  if !req.isAuthenticated()
    res.json 403, { reason: 'not_logged_in' }
    return

  tableList = req.query.tableList || []
  
  readFile = (tableName, callback) -> 
    if(!validLocation(req.query.appName, req.user.id, tableName))
      callback({ reason: 'invalid_location' })
      return

    fs.readFile fileLocation(req.query.appName, req.user.id, tableName, true), 'utf8', (err, data) ->
      if(err && err.errno == 34)
        console.log 'return empty content for file', tableName
        callback(null, {name: tableName, content: null})
      else if(err)
        console.log 'error reading file: ' + err
        callback(err)
      else
        callback(null, {name: tableName, content: data})

  async.map tableList, readFile, (err, dataSets) ->
    if err
      res.json 400, {reason: "read_failed"}
    else
      res.json 200, {tablesResponse: dataSets}

exports.postDataSets = (req, res) ->
  saveFile = (dataSet, callback) -> fs.writeFile fileLocation(req.query.appName, req.user.id, dataSet.name, true), dataSet.content, callback

  if !req.isAuthenticated()
    res.json 403, { reason: 'not_logged_in' }
    return

  if !req.body
    res.json 400, { reason: 'data_sets_missing' }
    return

  if !req.query.appName
    res.json 400, { reason: 'app_name_missing' }
    return
  
  async.each req.body, saveFile, (err) ->
    if err
      console.log('Write failed', err)
      res.json 400, {reason: "write_failed"}
    else
      req.user.lastModifiedByApp[req.query.appName] = req.query.lastModifiedDate
      req.user.markModified('lastModifiedByApp')
      req.user.save (err) ->
        if(err) then res.json 400, {reason: "write_failed"}
        else res.json 200, {message: "write_ok"}

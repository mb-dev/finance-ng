fs = require('fs')
async = require('async')
path = require('path')
Lazy = require('lazy.js')

mongoose = require('mongoose')
dataSetModels = require('../../models/dataset')

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


exports.getDataSet2 = (req, res) ->
  if !req.isAuthenticated()
    res.json 403, { reason: 'not_logged_in' }
    return

  modelName = "data_#{req.user.id}_#{req.params.appName}_#{req.params.tableName}"
  Model = mongoose.model(modelName, dataSetModels.DataSetSchema)

  actions = []

  loadFrom = new Date(parseInt(req.query.updatedAt, 10))
  console.log loadFrom

  Model.find {updatedAt: {$gt: loadFrom}}, (err, items) ->
    items.forEach (item) ->
      if item.deleted
        actions.push({action: 'delete', id: item.id, updatedAt: item.updatedAt.getTime()})
      else
        actions.push({action: 'update', id: item.id, item: item.jsonData, updatedAt: item.updatedAt.getTime()})
    res.json 200, {actions: actions}
  

exports.postDataSet2 = (req, res) ->
  if !req.isAuthenticated()
    res.json 403, { reason: 'not_logged_in' }
    return
  modelName = "data_#{req.user.id}_#{req.params.appName}_#{req.params.tableName}"
  Model = mongoose.model(modelName, dataSetModels.DataSetSchema)  

  performOperation = (op, callback) ->
    console.log(op.id)
    Model.findById op.id, (err, entry) =>
      if err && op.action != 'insert'
        callback(err)
        return

      if op.action == 'insert' && entry != null
        callback('attempt to insert item that already exists')
        return

      if(op.action == 'update')
        console.log(entry)
        entry.jsonData = entry.item
      else if(op.action == 'insert')
        entry = new Model()
        entry._id = op.id
        entry.jsonData = op.item
        entry.deleted = false
      else if(op.action == 'delete')
        entry.deleted = true
      entry.save(callback) 

  performPost = ->
    async.each req.body, performOperation, (err) ->
      if err
        console.log('Write failed', err)
        res.json 400, {reason: "write_failed"}
      else
        # req.user.lastModifiedByApp[req.query.appName] = req.query.lastModifiedDate
        # req.user.markModified('lastModifiedByApp')
        req.user.save (err) ->
          if(err) then res.json 400, {reason: "write_failed"}
          else res.json 200, {message: "write_ok"}

  if !req.body
    res.json 400, { reason: 'data_sets_missing' }
    return

  console.log(req.query.all)
  if req.query.all == 'true'
    Model.remove {}, (err) ->
      performPost()
  else
    performPost()

  
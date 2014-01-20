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

  res.json 200, {user: {id: req.user.id, email: req.user.email, lastModifiedDate: req.user.lastModifiedDate }}

exports.getDataSet = (req, res) ->
  if !req.isAuthenticated()
    res.json 403, { reason: 'not_logged_in' }
    return

  modelName = "data_#{req.user.id}_#{req.params.appName}_#{req.params.tableName}"
  Model = mongoose.model(modelName, dataSetModels.DataSetSchema)

  actions = []

  loadFrom = new Date(parseInt(req.query.updatedAt, 10))

  Model.find {updatedAt: {$gt: loadFrom}}, (err, items) ->
    items.forEach (item) ->
      if item.deleted
        actions.push({action: 'delete', id: item.id, updatedAt: item.updatedAt.getTime()})
      else
        actions.push({action: 'update', id: item.id, item: item.jsonData, updatedAt: item.updatedAt.getTime()})
    res.json 200, {actions: actions}
  

exports.postDataSet = (req, res) ->
  if !req.isAuthenticated()
    res.json 403, { reason: 'not_logged_in' }
    return

  modelName = "data_#{req.user.id}_#{req.params.appName}_#{req.params.tableName}"
  Model = mongoose.model(modelName, dataSetModels.DataSetSchema)  

  performOperation = (op, callback) ->
    Model.findById op.id, (err, entry) =>
      if err && op.action != 'insert'
        callback(err)
        return

      if op.action == 'insert' && entry != null
        console.log 'attempt to insert item that already exists', req.params.tableName, op
        callback('attempt to insert item that already exists')
        return

      if op.action == 'update' && !entry
        console.log 'attempt to update item that does not exist', req.params.tableName, op
        callback('attempt to update item that does not exist')
        return

      if(op.action == 'update')
        entry.jsonData = op.item
      else if(op.action == 'insert')
        entry = new Model()
        entry._id = op.id
        entry.jsonData = op.item
        entry.deleted = false
      else if(op.action == 'delete')
        entry.deleted = true
      entry.save (err) =>
        callback(err, entry.updatedAt.getTime()) 
      

  performPost = ->
    async.mapSeries req.body, performOperation, (err, results) ->
      if err
        console.log('Write failed', err)
        res.json 400, {reason: "write_failed", details: 'performing operations failed', err: err}
      else
        mostUpdatedAt = Lazy(results).max()
        req.user.lastModifiedDate["#{req.params.appName}-#{req.params.tableName}"] = mostUpdatedAt
        req.user.markModified("lastModifiedDate.#{req.params.appName}-#{req.params.tableName}")
        req.user.save (err) ->
          if(err) then res.json 400, {reason: "write_failed", details: 'saving user failed', err: err}
          else res.json 200, {message: "write_ok", updatedAt: mostUpdatedAt}

  if !req.body
    res.json 400, { reason: 'no_operations' }
    return

  if req.body.length == 0
    res.json 200, {message: "write_ok", updatedAt: req.user.lastModifiedDate["#{req.params.appName}-#{req.params.tableName}"]}
    return

  if req.query.all == 'true'
    Model.remove {}, (err) ->
      performPost()
  else
    performPost()

  
# weird functions to fix issues:
# convertId = function(id) { return parseInt(id[0], 10) + id.length - 1 }
# angular.element('.list-group').injector().get('mdb').events().collection.forEach(function(item, index) { if(item.participantIds && item.participantIds[0]) { console.log(item.participantIds[0], convertId(item.participantIds[0])); } })

class window.Collection
  VERSION = '1.0'

  constructor: ($q, sortColumn, extendFunc) ->
    @$q = $q
    @collection = []
    @sortColumn = sortColumn
    @lastInsertedId = null
    @modifiedAt = 0
    @actionsLog = []
    @idIndex = {}
    if extendFunc
      extendFunc(this)

  @doNotConvertFunc = (item) -> item

  version: -> VERSION

  migrateIfNeeded: (fromVersion) ->
    # no migrations are available yet

  setItemExtendFunc: (extendFunc) ->
    @itemExtendFunc = extendFunc

  extendItem: (item) ->
    @itemExtendFunc(item) if @itemExtendFunc

  reExtendItems: ->
    return if !@itemExtendFunc
    @collection.forEach (item) =>
      @itemExtendFunc(item)

  getAvailableId: ->
    return 1 if @collection.length == 0
    lastId = @collection[@collection.length - 1].id
    parseInt(lastId, 10) + 1

  findById: (id) ->
    result = Lazy(@collection).find (item) -> item.id.toString() == id.toString()
    result = angular.copy(result) if result
    result

  findByIds: (ids) ->
    return [] if !ids
    ids = ids.map (id) -> id.toString()
    result = Lazy(@collection).filter((item) -> ids.indexOf(item.id.toString()) >= 0).toArray()
    result = angular.copy(result) if result
    result

  getAll: (sortBy) ->
    if !sortBy && @sortColumn
      sortBy = @defaultSortFunction

    result = Lazy(angular.copy(@collection))
    result = result.sortBy sortBy if sortBy
    result

  defaultSortFunction: (item) =>
    if @sortColumn instanceof Array && @sortColumn.length == 2
      item[@sortColumn[0]] + '-' + item[@sortColumn[1]]
    else
      item[@sortColumn]

  getItemsByYear: (column, year, convertFunc, sortBy) ->
    if !sortBy && @sortColumn
      sortBy = @defaultSortFunction
    if !convertFunc
      convertFunc = (value) -> moment(value).year()

    step1 = Lazy(@collection).filter((item) -> 
      value = item[column]
      value = convertFunc(value) if convertFunc
      value == year
    )
    if sortBy
      step1.sortBy sortBy
    else
      step1

  insert: (details) =>
    deferred = @$q.defer()
    if !details.id
      id = @getAvailableId()
      details.id = id.toString()
      details.createdAt = moment().valueOf()
      details.modifiedAt = moment().valueOf()
      @lastInsertedId = details.id
    else if @findById(details.id)
      deferred.reject("ID already exists")

    @itemExtendFunc(details) if @itemExtendFunc
    @collection.push(details)
    @onModified()

    # update index
    @idIndex[details.id] = @collection.length - 1

    # add to log
    @actionsLog.push({action: 'insert', id: details.id, item: details})

    deferred.resolve(details.id)
    deferred.promise

  editById: (details) =>
    deferred = @$q.defer()
    item = Lazy(@collection).find (item) -> item.id.toString() == details.id.toString()
    angular.copy(details, item)
    item.modifiedAt = moment().valueOf()
    @onModified()

    # add to log
    @actionsLog.push({action: 'update', id: details.id, item: details})

    deferred.resolve()
    deferred.promise

  deleteById: (itemId) =>
    itemIndex = Lazy(@collection).pluck('id').indexOf(itemId.toString())
    if itemIndex >= 0
      @collection.splice(itemIndex, 1)
      delete @idIndex[itemId]
      @actionsLog.push({action: 'delete', id: itemId})
      @onModified()

  length: =>
    @collection.length

  reset: =>
    @collection = []

  onModified: =>
    @modifiedAt = Date.now()

  $buildIndex: =>
    indexItem = (result, item, index) -> 
      result[item.id] = index
      result
    @idIndex = Lazy(@collection).reduce(indexItem, {})

  $updateOrSet: (item, updatedAt) =>
    if !@idIndex[item.id]
      @collection.push(item)
      @idIndex[item.id] = @collection.length - 1
    else
      @collection[@idIndex[item.id]] = item
    @extendItem(item)
    if updatedAt > @modifiedAt
      @modifiedAt = updatedAt

  afterLoadCollection: =>
    @$buildIndex()


class window.SimpleCollection
  VERSION = '1.0'

  constructor:  ($q) ->
    @collection = []
    @actualCollection = {}
    @idIndex = []
    @actionsLog = []
    @modifiedAt = 0

  getAvailableId: ->
    return 1 if @collection.length == 0
    lastId = @collection[@collection.length - 1].id
    parseInt(lastId, 10) + 1

  version: -> VERSION

  migrateIfNeeded: =>

  reExtendItems: =>

  getAll: =>
    Lazy(@actualCollection).keys()

  has: (key) =>
    !!@actualCollection[key]

  get: (key) =>
    angular.copy(@actualCollection[key].value)

  set: (key, value, isLoadingProcess, loadedId) =>
    if @actualCollection[key]
      item = @actualCollection[key]
      @actionsLog.push({action: 'update', id: item.id, item: item.value}) if !isLoadingProcess
      @actualCollection[key].value = value
    else
      if isLoadingProcess && loadedId
        newId = loadedId
      else
        newId = @getAvailableId()
      @actualCollection[key] = {id: newId, value: value}
      entry = {id: newId, key: key, value: value}
      @idIndex[newId] = @collection.length - 1
      @collection.push(entry)
      @actionsLog.push({action: 'insert', id: newId, item:  entry})  if !isLoadingProcess
    @onModified() if !isLoadingProcess

  delete: (key) =>
    item = @actualCollection[key]
    index = @idIndex[item.id]
    delete @idIndex[item.id]
    @collection.splice(index, 1)
    delete @actualCollection[key]
    actionsLog.push({action: 'delete', id: item.id})
    @onModified()

  findOrCreate: (items) =>
    return if !items
    items = [items] if !(items instanceof Array)
    items.forEach (item) =>
      @set(item, true)  

  onModified: =>
    @modifiedAt = Date.now()

  $buildIndex: =>
    indexItem = (result, item, index) -> 
      result[item.id] = index
      result
    @idIndex = Lazy(@collection).reduce(indexItem, {})

  $updateOrSet: (item, updatedAt) =>
    @set(item.key, item.value, true, item.id)
    if updatedAt > @modifiedAt
      @modifiedAt = updatedAt  

  afterLoadCollection: =>
    if @collection instanceof Array
      @$buildIndex()
      @collection.forEach (item) =>
        @actualCollection[item.key] = {id: item.id, value: item.value}
    else
      items = @collection
      @collection = []
      Lazy(items).keys().each (key) =>
        @set(key, items[key])
      @actionsLog = []

class window.Database
  constructor: (appName, $http, $q, $sessionStorage, $localStorage, fileSystem) ->
    @$http = $http
    @$q = $q
    @$sessionStorage = $sessionStorage
    @$localStorage = $localStorage
    @appName = appName
    @fileSystem = fileSystem

    @db = {
      user: {config: {incomeCategories: ['Income:Salary', 'Income:Dividend', 'Income:Misc']}} 
    }

  user: =>
    @db.user

  createCollection: (name, collectionInstance) =>
    @db[name] = collectionInstance
    collectionInstance


  # file system API
  fileName: (tableName) ->
    "#{@appName}-#{tableName}.json"

  readTablesFromFS: (tableNames) =>
    promises = tableNames.map (tableName) => 
      @fileSystem.readFile('/db/' + @fileName(tableName)).then (content) ->
        {name: tableName, content: JSON.parse(content)}

    @$q.all(promises)

  writeTablesToFS: (tableNames) =>
    promises = tableNames.map (tableName) =>
      @fileSystem.writeText('/db/' + @fileName(tableName), angular.toJson(@collectionToStorage(tableName))).then () ->
        console.log('write', tableName, 'to FS')
      , (err) ->
        console.log('failed to write', tableName, 'to FS', err)

    @$q.all(promises)
  
  collectionToStorage: (tableName) =>
    dbModel = @db[tableName]
    {
      version: dbModel.version()
      data: dbModel.collection
      modifiedAt: dbModel.modifiedAt
    }

  dumpAllCollections: (tableList) =>
    result = {}
    result[@appName] = Lazy(tableList).map((tableName) =>
      {
        name: tableName
        content: @collectionToStorage(tableName)
      }
    ).toArray()
    result

  authenticate: =>
    defer = @$q.defer()

    @$http.get('/data/authenticate')
      .success (response, status, headers) =>
        @db.user.email = response.user.email
        @db.user.lastModifiedByApp = response.user.lastModifiedByApp
        @$sessionStorage.user = {email: response.user.email, lastModifiedByApp: response.user.lastModifiedByApp}
        defer.resolve()
      .error (data, status, headers) ->
        console.log(data)
        defer.reject({data: data, status: status, headers: headers})

    defer.promise

  readTablesFromWeb: (tableList) =>
    defer = @$q.defer()
    
    @$http.get('/data/datasets?' + $.param({appName: @appName, tableList: tableList}))
      .success (response, status, headers) =>
        defer.resolve(response.tablesResponse)
      .error (data, status, headers) ->
        console.log(data)
        defer.reject({data: data, status: status, headers: headers})

    defer.promise
      
  getTables: (tableList, version) ->
    deferred = @$q.defer();
    
    onAuthenticated = =>
      if !@$localStorage.encryptionKey
        defer.reject({data: {reason: 'missing_key'}, status: 403})
      else
        @readTablesFromFS(tableList).then(onReadTablesFromFS, onFailedReadTablesFromFS)

    onFailedAuthenticate = (response) =>
      deferred.reject(response)

    onReadTablesFromFS = (fileContents) =>
      if !@db.user.lastModifiedByApp[@appName] || (moment(@db.user.lastModifiedByApp[@appName]).valueOf() > Lazy(fileContents).pluck('content').pluck('modifiedAt').max())  # if the web has more up to date version of data
        if version && version == 2
          @load2(tableList).then(onReadTablesFromWebV2, onFailedReadTablesFromWeb)
        else
          @readTablesFromWeb(tableList).then(onReadTablesFromWeb, onFailedReadTablesFromWeb)
      else
        fileContents.forEach(loadDataSet)
        console.log 'all data sets ', tableList, ' found in file system - resolving'
        deferred.resolve(this)

    onFailedReadTablesFromFS = () =>
      @readTablesFromWeb(tableList).then(onReadTablesFromWeb, onFailedReadTablesFromWeb)

    onReadTablesFromWeb = (fileContents) =>
      fileContents.forEach(loadDataSet)
      @writeTablesToFS(tableList)
      console.log 'all data sets ', tableList, ' were retrieved from the web - resolving'
      deferred.resolve(this)

    onReadTablesFromWebV2 = (fileContents) =>
      @writeTablesToFS(tableList)
      console.log 'all data sets ', tableList, ' were retrieved from the web v2 - resolving'
      deferred.resolve(this)

    onFailedReadTablesFromWeb = (response) =>
      deferred.reject(response)

    loadDataSet = (dataSet) =>
      dbModel = @db[dataSet.name]
      if !dataSet.content
        console.log('failed to load ' + dataSet.name)
        return
      
      if typeof(dataSet.content) == 'string'
        try
          dataSet.content = JSON.parse(sjcl.decrypt(@$localStorage.encryptionKey, dataSet.content))
        catch err
          console.log('failed to decrypt ' + dataSet.name)
          return

      if !dataSet.content.version
        console.log('failed to load ' + dataSet.name + ' - version missing')
        return
    
      dbModel.modifiedAt = dataSet.content.modifiedAt
      dbModel.collection = dataSet.content.data
      dbModel.afterLoadCollection()
      dbModel.migrateIfNeeded()
      dbModel.reExtendItems()
      
    # actual getTables code start shere
    @authenticate().then(onAuthenticated, onFailedAuthenticate)
    deferred.promise

  saveTables: (tableList, version) =>
    deferred = @$q.defer();

    dataSets = @dumpAllCollections(tableList)[@appName]
    lastModifiedDate = Lazy(dataSets).pluck('content').pluck('modifiedAt').max() - 10
    dataSets.forEach (dataSet) =>
      dataSet.content = sjcl.encrypt(@$localStorage.encryptionKey, angular.toJson(dataSet.content))

    if version && version == 2
      @save2(tableList).then =>
        @writeTablesToFS(tableList).then ->
          deferred.resolve(true)
        , (error) ->
          console.log('failed to write files to file system', error)
          deferred.reject('failed to write to file system')
    else
      @$http.post('/data/datasets?' + $.param({appName: @appName, lastModifiedDate: lastModifiedDate}), dataSets)
        .success (data, status, headers) =>
          console.log 'saving datasets:', tableList, 'to file system'
          @writeTablesToFS(tableList).then ->
            deferred.resolve(data)
          , (error) ->
            console.log('failed to write files to file system', error)
            deferred.reject('failed to write to file system')
        .error (data, status, headers) ->
          deferred.reject({data: data, status: status, headers: headers})

    deferred.promise

  load2: (tableList, all) =>
    deferred = @$q.defer();

    promises = []
    tableList.forEach (tableName) =>
      dbModel = @db[tableName]
      if all
        dbModel.collection = []
        getDataFrom = 0
      else
        getDataFrom = dbModel.modifiedAt

      promise = @$http.get("/data2/#{@appName}/#{tableName}?" + $.param({updatedAt: getDataFrom})).then (response) =>
        dbModel.actionsLog = []
        response.data.actions.forEach (op) =>
          if op.action == 'update'
            dbModel.$updateOrSet(JSON.parse(sjcl.decrypt(@$localStorage.encryptionKey, op.item)))
          else if op.action == 'delete'
            a = 1
            # delete item

      promises.push(promise)
    
    @$q.all(promises).then (actions) =>
      deferred.resolve(true)
    , (fail) =>
      console.log 'fail', fail
      deferred.reject({data: fail.data, status: fail.status, headers: fail.headers})

    deferred.promise

  save2: (tableList, all) =>
    deferred = @$q.defer();

    promises = []
    tableList.forEach (tableName) =>
      dbModel = @db[tableName]

      actions = []
      if all
        dbModel.collection.forEach (item) =>
          actions.push({action: 'insert', id: item.id, item: sjcl.encrypt(@$localStorage.encryptionKey, angular.toJson(item))})
      else
        actions = dbModel.actionsLog
        actions.forEach (action) =>
          action.item = sjcl.encrypt(@$localStorage.encryptionKey, angular.toJson(action.item))

      promise = @$http.post("/data2/#{@appName}/#{tableName}?all=#{!!all}", actions).then () =>
        dbModel.actionsLog = []

      promises.push(promise)
    
    @$q.all(promises).then (actions) =>
      deferred.resolve(true)
    , (fail) =>
      console.log 'fail', fail
      deferred.reject({data: fail.data, status: fail.status, headers: fail.headers})

    deferred.promise

class window.Box
  constructor: ->
    @rows = []
    @rowByHash = {}
  
  addRow: (item) ->
    row = {columns: {}, totals: {}}
    @rows.push row
    @rowByHash[item] = row
  
  setColumns: (columns, valueTypes) ->
    Lazy(@rows).each (row) ->
      Lazy(columns).each (colValue) ->
        column = row['columns'][colValue] = {}
        column['values'] = {}
        Lazy(valueTypes).each (type) ->
          column['values'][type] ?= new BigNumber(0)
      Lazy(valueTypes).each (type) ->
        row['totals'][type] = new BigNumber(0)
      

  setValues: (row, col, type, value) ->

  addToValue: (row, col, type, value) ->
    return if !row
    column = @rowByHash[row]['columns'][col]
    column['values'][type] = column['values'][type].plus(value)
    @rowByHash[row]['totals'][type] = @rowByHash[row]['totals'][type].plus(value)
  
  columnAmount: ->
    @rows[0]['values'].length
  
  rowColumnValues: (row) =>
    return [] if !@rowByHash[row]
    Lazy(@rowByHash[row]['columns']).pairs().map((item) -> {column: item[0], values: item[1].values }).toArray()

  rowTotals: (row) =>
    @rowByHash[row]['totals']
  
  # private
  columnValues = (column) ->
    return 0 if column.blank?
    column['values'] || 0


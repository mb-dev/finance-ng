###
weird functions to fix issues:
convertId = function(id) { return parseInt(id[0], 10) + id.length - 1 }
events:
angular.element('.list-group').injector().get('mdb').events().collection.forEach(function(item, index) { if(item.participantIds && item.participantIds[0]) { console.log(item.participantIds[0], convertId(item.participantIds[0])); } })
angular.element('.list-group').injector().get('mdb').events().collection.forEach(function(item, index) { item.participants && item.participants.forEach(function(item, index) {item.participants[index] = parseInt(item.participants[index], 10) }) })
angular.element('.list-group').injector().get('mdb').events().collection.forEach(function(item, index) { item.associatedMemories && item.associatedMemories.forEach(function(item, index) {item.associatedMemories[index] = parseInt(item.associatedMemories[index], 10) }) })
--
events:
angular.element('.list-group').injector().get('mdb').events().collection.forEach(function(item, index) { 
  if(item.participants) { 
   item.participants.forEach(function(association, index) {
     item.participants[index] = parseInt(item.participants[index], 10); 
   }) 
  }
  if(item.associatedMemories) {
    item.associatedMemories.forEach(function(association, index) {
     item.associatedMemories[index] = parseInt(item.associatedMemories[index], 10); 
   })  
  }
}) 
angular.element('.list-group').injector().get('mdb').saveTables(['events'], true)
---
memories:
angular.element('.list-group').injector().get('mdb').memories().collection.forEach(function(item, index) { 
 if(item.events) { 
   item.events.forEach(function(association, index) {
     item.events[index] = parseInt(item.events[index], 10); 
   }) 
 }
 if(item.people) { 
   item.people.forEach(function(association, index) {
     item.people[index] = parseInt(item.people[index], 10); 
   }) 
 }
 if(item.parentMemoryId) {
    item.parentMemoryId = parseInt(parentMemoryId, 10);
 }
}) 
angular.element('.list-group').injector().get('mdb').saveTables(['memories'], true)
--
line items:
angular.element('.list-group').injector().get('fdb').lineItems().collection.forEach(function(item, index) { 
   item.accountId = parseInt(item.accountId, 10);
   item.importId = parseInt(item.importId, 10);
})
angular.element('.list-group').injector().get('fdb').saveTables(['lineItems'], true) 
--
processing rules:
angular.element('ng-view').injector().get('fdb').processingRules().collection.forEach(function(item, index) { 
   item.id = index + 1;
   angular.element('ng-view').injector().get('fdb').processingRules().actualCollection[item.key].id = index + 1;
})
###
class window.Collection
  VERSION = '1.0'

  constructor: ($q, sortColumn) ->
    @$q = $q
    @sortColumn = sortColumn
    @reset()

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

  getAvailableId: =>
    currentTime = moment().unix()
    if @lastIssuedId >= currentTime
      @lastIssuedId = @lastIssuedId + 1
    else
      @lastIssuedId = currentTime

  findById: (id) ->
    result = @collection[@idIndex[id]]
    result = angular.copy(result) if result
    result

  findByIds: (ids) ->
    return [] if !ids
    result = Lazy(ids).map((id) => @collection[@idIndex[id]]).toArray()
    result = angular.copy(result) if result
    result

  getAll: (sortColumns) ->
    result = Lazy(angular.copy(@collection))
    result = @sortLazy(result, sortColumns)
    result

  sortLazy: (items, columns) =>
    if !columns && @sortColumn
      columns = @sortColumn

    if columns
      if columns instanceof Array && columns.length == 2
        items.sortBy((item) -> [item[columns[0]], item[columns[1]]])
      else
        items.sortBy((item) -> item[columns])
    else
      items

  getItemsByYear: (column, year, sortColumns) ->
    results = Lazy(@collection).filter (item) -> 
      if item[column] < 10000
        item[column] == year
      else
        moment(item[column]).year() == year 
      
    @sortLazy(results, sortColumns)

  insert: (details) =>
    deferred = @$q.defer()
    @correctId(details)
    if !details.id
      id = @getAvailableId()
      details.id = id
      details.createdAt = moment().valueOf()
      details.updatedAt = moment().valueOf()
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
    @correctId(details)
    index = @idIndex[details.id]
    throw 'not found' if index == undefined
    item = @collection[index]
    angular.copy(details, item)
    item.updatedAt = moment().valueOf()
    @onModified()

    # add to log
    @actionsLog.push({action: 'update', id: details.id, item: details})

    deferred.resolve()
    deferred.promise

  deleteById: (itemId, loadingProcess) =>
    throw 'not found' if @idIndex[itemId] == undefined
    @collection.splice(@idIndex[itemId], 1)
    delete @idIndex[itemId]
    if !loadingProcess
      @actionsLog.push({action: 'delete', id: itemId})
      @onModified()

  length: =>
    @collection.length

  reset: =>
    @collection = []
    @lastInsertedId = null
    @updatedAt = 0
    @actionsLog = []
    @idIndex = {}
    @lastIssuedId = 0

  correctId: (item) =>
    if item.id && typeof item.id != 'number'
      item.id = parseInt(item.id, 10)

  onModified: =>
    @updatedAt = Date.now()

  # sync actions
  $buildIndex: =>
    indexItem = (result, item, index) -> 
      result[item.id] = index
      result
    @idIndex = Lazy(@collection).reduce(indexItem, {})

  $updateOrSet: (item, updatedAt) =>
    @correctId(item)
    if !@idIndex[item.id]
      @collection.push(item)
      @idIndex[item.id] = @collection.length - 1
    else
      @collection[@idIndex[item.id]] = item
    @extendItem(item)
    item.updatedAt = updatedAt
    if updatedAt > @updatedAt
      @updatedAt = updatedAt

  $deleteItem: (itemId, updatedAt) =>
    @deleteById(itemId, true)
    if updatedAt > @updatedAt
      @updatedAt = updatedAt

  afterLoadCollection: =>
    @collection.forEach (item) =>
      @correctId(item)
    @$buildIndex()
    @migrateIfNeeded()


class window.SimpleCollection
  VERSION = '1.0'

  constructor:  ($q) ->
    @reset()

  getAvailableId: =>
    currentTime = moment().unix()
    if @lastIssuedId >= currentTime
      @lastIssuedId = @lastIssuedId + 1
    else
      @lastIssuedId = currentTime

  version: -> VERSION

  migrateIfNeeded: =>

  reExtendItems: =>

  getAll: =>
    Lazy(@actualCollection).keys()

  has: (key) =>
    !!@actualCollection[key]

  get: (key) =>
    return undefined if !@actualCollection[key]
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
      @collection.push(entry)
      @actionsLog.push({action: 'insert', id: newId, item:  entry})  if !isLoadingProcess
      @idIndex[newId] = @collection.length - 1
    @onModified() if !isLoadingProcess

  delete: (key, isLoadingProcess) =>
    item = @actualCollection[key]
    throw 'not found' if !item
    index = @idIndex[item.id]
    throw 'not found' if index == undefined
    delete @idIndex[item.id]
    @collection.splice(index, 1)
    delete @actualCollection[key]
    if !isLoadingProcess
      @actionsLog.push({action: 'delete', id: item.id})
      @onModified()

  findOrCreate: (items) =>
    return if !items
    items = [items] if !(items instanceof Array)
    items.forEach (item) =>
      @set(item, true)  

  onModified: =>
    @updatedAt = Date.now()

  correctId: (item) =>
    if item.id && typeof item.id != 'number'
      item.id = parseInt(item.id, 10)

  # sync actions
  reset: =>
    @idIndex = []
    @collection = []
    @actualCollection = {}
    @actionsLog = []
    @updatedAt = 0
    @lastIssuedId = 0

  $buildIndex: =>
    indexItem = (result, item, index) -> 
      result[item.id] = index
      result
    @idIndex = Lazy(@collection).reduce(indexItem, {})

  $updateOrSet: (item, updatedAt) =>
    @correctId(item)
    @set(item.key, item.value, true, item.id)
    if updatedAt > @updatedAt
      @updatedAt = updatedAt 

  $deleteItem: (itemId, updatedAt) =>
    @delete(itemId, true)
    if updatedAt > @updatedAt
      @updatedAt = updatedAt

  afterLoadCollection: =>
    if @collection instanceof Array
      @collection.forEach (item) =>
        @correctId(item)
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
      updatedAt: dbModel.updatedAt
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
        @$localStorage.user = {email: response.user.email, lastModifiedDate: response.user.lastModifiedDate}
        defer.resolve()
      .error (data, status, headers) ->
        defer.reject({data: data, status: status, headers: headers})

    defer.promise

  readTablesFromWeb: (tableList, forceLoadAll) =>
    # which tables require reading?
    staleTableList = []
    if forceLoadAll
      staleTableList = tableList
    else
      tableList.forEach (tableName) =>
        dbModel = @db[tableName]
        lastModifiedServerTime = @db.user.lastModifiedDate["#{@appName}-#{tableName}"]
        if lastModifiedServerTime && lastModifiedServerTime > dbModel.updatedAt
          staleTableList.push(tableName)

    # load them
    deferred = @$q.defer();

    promises = []
    staleTableList.forEach (tableName) =>
      dbModel = @db[tableName]
      if forceLoadAll
        dbModel.reset()
        getDataFrom = 0
      else
        getDataFrom = dbModel.updatedAt

      promise = @$http.get("/data/#{@appName}/#{tableName}?" + $.param({updatedAt: getDataFrom})).then (response) =>
        dbModel.actionsLog = []
        response.data.actions.forEach (op) =>
          if op.action == 'update'
            try
              dbModel.$updateOrSet(JSON.parse(sjcl.decrypt(@$localStorage.encryptionKey, op.item)), op.updatedAt)
            catch
              console.log 'failed to decrypt', tableName, op
              throw 'failed to decrypt'
          else if op.action == 'delete'
            dbModel.$deleteItem(op.id, op.updatedAt)

      promises.push(promise)
    
    @$q.all(promises).then (actions) =>
      deferred.resolve(staleTableList)
    , (fail) =>
      console.log 'fail', fail
      deferred.reject({data: fail.data, status: fail.status, headers: fail.headers})

    deferred.promise

  performGet: (tableList, options) ->
    deferred = @$q.defer();
    loadedDataFromFS = false

    copyUserDataFromSession = =>
      @db.user.email = @$localStorage.user.email
      @db.user.lastModifiedDate = @$localStorage.user.lastModifiedDate

    onAuthenticated = =>
      if !@$localStorage.encryptionKey
        deferred.reject({data: {reason: 'missing_key'}, status: 403})
      else
        copyUserDataFromSession()
        if options.initialState == 'authenticate'
          @readTablesFromWeb(tableList).then(onReadTablesFromWeb, onFailedReadTablesFromWeb)
        else
          @readTablesFromFS(tableList).then(onReadTablesFromFS, onFailedReadTablesFromFS)

    onFailedAuthenticate = (response) =>
      deferred.reject(response)

    onReadTablesFromWeb = (staleTables) =>
      @writeTablesToFS(staleTables)
      if staleTables.length > 0
        console.log 'stale data sets ', staleTables, ' were updated from the web - resolving'
      deferred.resolve(this)

    onFailedReadTablesFromWeb = (response) =>
      deferred.reject(response)

    onReadTablesFromFS = (fileContents) =>
      loadedDataFromFS = true
      fileContents.forEach(loadDataSet)
      console.log 'read data sets ', tableList, ' from file system - resolving'
      deferred.resolve(this)

    onFailedReadTablesFromFS = () =>
      @readTablesFromWeb(tableList).then(onReadTablesFromWeb, onFailedReadTablesFromWeb)

    loadDataSet = (dataSet) =>
      dbModel = @db[dataSet.name]
      if !dataSet.content
        console.log('failed to load ' + dataSet.name)
        return
      
      if !dataSet.content.version
        console.log('failed to load ' + dataSet.name + ' - version missing')
        return
      
      dbModel.updatedAt = dataSet.content.updatedAt
      dbModel.collection = dataSet.content.data
      dbModel.afterLoadCollection()
      dbModel.reExtendItems()

    if options.initialState == 'authenticate'
      # actual getTables code start shere
      @authenticate().then(onAuthenticated, onFailedAuthenticate)
    else if options.initialState == 'readFromWeb'
      copyUserDataFromSession()
      @readTablesFromWeb(tableList, options.forceRefreshAll).then(onReadTablesFromWeb, onFailedReadTablesFromWeb)
    else if options.initialState == 'readFromFS'
      copyUserDataFromSession()
      @readTablesFromFS(tableList).then(onReadTablesFromFS, onFailedReadTablesFromFS)
  
    deferred.promise

  authAndCheckData: (tableList) ->
    @performGet(tableList, {initialState: 'authenticate', forceRefreshAll: false})

  getTables: (tableList, forceRefreshAll = false) ->
    # actual getTables code start shere
    if @$localStorage.user && forceRefreshAll
      @performGet(tableList, {initialState: 'readFromWeb', forceRefreshAll: true})
    else if @$localStorage.user && !forceRefreshAll
      @performGet(tableList, {initialState: 'readFromFS', forceRefreshAll: false})  
    else
      @performGet(tableList, {initialState: 'authenticate', forceRefreshAll: false})  

  saveTables: (tableList, forceServerCleanAndSaveAll = false) =>
    deferred = @$q.defer();
    
    promises = []
    tableList.forEach (tableName) =>
      dbModel = @db[tableName]

      actions = []
      if forceServerCleanAndSaveAll
        dbModel.collection.forEach (item) =>
          actions.push({action: 'insert', id: item.id, item: sjcl.encrypt(@$localStorage.encryptionKey, angular.toJson(item))})
      else
        actions = dbModel.actionsLog
        actions.forEach (action) =>
          if action.item
            action.item = sjcl.encrypt(@$localStorage.encryptionKey, angular.toJson(action.item))

      promise = @$http.post("/data/#{@appName}/#{tableName}?all=#{!!forceServerCleanAndSaveAll}", actions).then (response) =>
        dbModel.updatedAt = response.data.updatedAt
        @db.user.lastModifiedDate["#{@appName}-#{tableName}"] = dbModel.updatedAt
        @$localStorage.user.lastModifiedDate["#{@appName}-#{tableName}"] = dbModel.updatedAt
        dbModel.actionsLog = []

      promises.push(promise)
    
    @$q.all(promises).then (actions) =>
      @writeTablesToFS(tableList).then ->
        deferred.resolve(true)
      , (error) ->
        console.log('failed to write files to file system', error)
        deferred.reject('failed to write to file system')
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


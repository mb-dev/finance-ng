class window.Collection
  VERSION = '1.0'

  constructor: ($q, sortColumn, extendFunc) ->
    @$q = $q
    @collection = []
    @sortColumn = sortColumn
    @lastInsertedId = null
    @modifiedAt = Date.now()
    if extendFunc
      extendFunc(this)

  @doNotConvertFunc = (item) -> item

  version: -> VERSION

  migrateIfNeeded: (fromVersion) ->
    # no migrations are available yet

  setItemExtendFunc: (extendFunc) ->
    @itemExtendFunc = extendFunc

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
    result = Lazy(@collection).filter((item) -> ids.indexOf(item.id) >= 0).toArray()
    result = angular.copy(result) if result
    result

  getAll: (sortBy) ->
    if !sortBy && @sortColumn
      sortBy = @defaultSortFunction

    result = Lazy(angular.copy(@collection))
    result = result.sortBy sortBy if sortBy
    result

  defaultSortFunction: (item) ->
    (item) -> (item) item[@sortColumn]

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

    deferred.resolve(details.id)
    deferred.promise

  editById: (details) =>
    deferred = @$q.defer()
    item = Lazy(@collection).find (item) -> item.id == details.id
    angular.copy(details, item)
    item.modifiedAt = moment().valueOf()
    @onModified()
    deferred.resolve()
    deferred.promise

  deleteById: (itemId) =>
    itemIndex = Lazy(@collection).pluck('id').indexOf(itemId)
    if itemIndex >= 0
      @collection.splice(itemIndex, 1)
    @onModified()

  length: =>
    @collection.length

  reset: =>
    @collection = []

  onModified: =>
    @modifiedAt = Date.now()

class window.SimpleCollection
  VERSION = '1.0'

  constructor:  ($q) ->
    @collection = {}

  version: -> VERSION

  migrateIfNeeded: =>

  reExtendItems: =>

  getAll: =>
    Lazy(@collection).keys()

  findOrCreate: (items) =>
    items.forEach (item) =>
      if(!@collection[item])
        @collection[item] = true
        @onModified()

  onModified: =>
    @modifiedAt = Date.now()  

# Graph DB
class GraphCollection
  constructor: ($q, graphs) ->
    @$q = $q
    @collection = {}

  reset: =>
    @collection = {}

  associate: (graph, sourceId, destId) =>
    @collection[graph] = @collection[graph] || {}
    @collection[graph][sourceId] = @collection[graph][sourceId] || {}
    @collection[graph][sourceId][destId] = true

  isAssociated: (graph, sourceId, destId) =>
    return false if !@collection[graph] || !@collection[graph][sourceId]
    return @collection[graph][sourceId][destId] == true

  getAssociated: (graph, sourceId) =>
    sourceId = sourceId.toString()
    return [] if !@collection[graph] || !@collection[graph][sourceId]
    return Lazy(@collection[graph][sourceId]).keys().toArray()

class window.Database
  constructor: (appName, $http, $q, $sessionStorage, $localStorage, fileSystem) ->
    @$http = $http
    @$q = $q
    @$sessionStorage = $sessionStorage
    @$localStorage = $localStorage
    @appName = appName
    @fileSystem = fileSystem

    @db = {
      user: {config: {incomeCategories: ['Salary', 'Investments:Dividend', 'Income:Misc']}} 
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
  

  # importDatabase: ($q, $sessionStorage) ->
  #   dateToJsStorage = (dateString) -> 
  #     moment(dateString).valueOf()

  #   cleanItem = (item) ->
  #     item.id = item['_id']
  #     item.created_at = moment(item.created_at).valueOf() if item.created_at
  #     item.updated_at = moment(item.updated_at).valueOf() if item.updated_at

  #     delete item['_id']
  #     delete item['processing_rule_ids']
  #     delete item['encrypted_password']

  #   importFile = (fileName, collectionModel, itemConvert) ->
  #     deferred = $q.defer();
  #     $.getJSON fileName, (data) ->
  #       Lazy(data).each (item) ->
  #         cleanItem(item)
  #         itemConvert(item) if itemConvert
  #         collectionModel.insert(item)
        
  #       deferred.resolve(true)
  #     deferred.promise

  #   importDeferred = $q.defer()

  #   @loadStateFromLocalStorage($sessionStorage)
  #   if @db.lineItems.collection && @db.lineItems.collection.length > 1
  #     importDeferred.resolve(this)
  #   else
  #     file1 = importFile '/dumps/Account.json', @accounts()
  #     file2 = importFile '/dumps/LineItem.json', @lineItems(), (item) ->
  #       item.event_date = dateToJsStorage(item.event_date)
  #       if item.original_event_date
  #         item.original_event_date = dateToJsStorage(item.original_event_date) 
  #       else
  #         item.original_event_date = item.event_date
  #     file3 = importFile '/dumps/BudgetItem.json', @budgetItems()
  #     file4 = importFile '/dumps/PlannedItem.json', @plannedItems(), (item) ->
  #       item.event_date_start = dateToJsStorage(item.event_date)
  #       item.event_date_end = dateToJsStorage(item.event_date)

  #     $q.all([file1, file2, file3, file4]).then (values) => 
  #       @saveStateToLocalStorage($sessionStorage)
  #       importDeferred.resolve(this)
    
  #   importDeferred.promise
  
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
        @$sessionStorage.user = {email: response.user.email, lastModifiedDate: response.user.lastModifiedDate}
        defer.resolve()
      .error (data, status, headers) ->
        console.log(data)
        deferred.reject({data: data, status: status, headers: headers})

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
      
  getTables: (tableList) ->
    deferred = @$q.defer();
    
    onAuthenticated = =>
      if !@$localStorage.encryptionKey
        defer.reject({data: {reason: 'missing_key'}, status: 403})
      else
        @readTablesFromFS(tableList).then(onReadTablesFromFS, onFailedReadTablesFromFS)

    onFailedAuthenticate = (response) =>
      deferred.reject(response)

    onReadTablesFromFS = (fileContents) =>
      if @db.user.lastModifiedDate > Lazy(fileContents).pluck('content').pluck('modifiedAt').max()  # if the web has more up to date version of data
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
      dbModel.migrateIfNeeded()
      dbModel.reExtendItems()
      
    # actual getTables code start shere
    @authenticate().then(onAuthenticated, onFailedAuthenticate)
    deferred.promise

  saveTables: (tableList) =>
    deferred = @$q.defer();

    dataSets = @dumpAllCollections(tableList)[@appName]
    dataSets.forEach (dataSet) =>
      dataSet.content = sjcl.encrypt(@$localStorage.encryptionKey, angular.toJson(dataSet.content))

    @$http.post('/data/datasets?' + $.param({appName: @appName}), dataSets)
      .success (data, status, headers) =>
        console.log 'saving datasets:', tableList, 'to session'
        @writeTablesToFS(tableList).then ->
          deferred.resolve(data)
        , (error) ->
          console.log('failed to write files to file system', error)
          deferred.reject('failed to write to file system')
      .error (data, status, headers) ->
        deferred.reject({data: data, status: status, headers: headers})

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
    Lazy(@rowByHash[row]['columns']).pairs().map((item) -> {column: item[0], values: item[1].values }).toArray()

  rowTotals: (row) =>
    @rowByHash[row]['totals']
  
  # private
  columnValues = (column) ->
    return 0 if column.blank?
    column['values'] || 0


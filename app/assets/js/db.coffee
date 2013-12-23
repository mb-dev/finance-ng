class window.Collection
  VERSION = '1.0'

  constructor: ($q, sortColumn, extendFunc) ->
    @$q = $q
    @collection = []
    @sortColumn = sortColumn
    @lastInsertedId = null
    @associations = {}
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
    Lazy(@collection).each (item) =>
      @itemExtendFunc(item)

  getAvailableId: ->
    return 1 if @collection.length == 0
    lastId = @collection[@collection.length - 1].id
    lastId

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

    deferred.resolve(details.id)
    deferred.promise

  editById: (details) =>
    deferred = @$q.defer()
    item = Lazy(@collection).find (item) -> item.id == details.id
    angular.copy(details, item)
    item.modifiedAt = moment().valueOf()
    deferred.resolve()
    deferred.promise

  deleteById: (itemId) =>
    itemIndex = Lazy(@collection).pluck('id').indexOf(itemId)
    if itemIndex
      @collection.slice(itemIndex, 1)

  length: =>
    @collection.length

  removeById: (id) =>
    item = @findById(id)
    index = @collection.indexOf(item)
    @collection.splice(index, 1)

  reset: =>
    @collection = []

  getAssociatedMany: (itemId, db, dbCollection, associatedCollection) ->
    dbResults = db.getAssociated(dbCollection, itemId)
    if associatedCollection
      return [] if dbResults.length == 0
      associatedCollection.findByIds(dbResults)
    else
      dbResults

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
    Lazy(items).each (item) =>
      if(!@collection[item])
        @collection[item] = true  

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
  constructor: (appName, $http, $q, $sessionStorage, $localStorage) ->
    @$http = $http
    @$q = $q
    @$sessionStorage = $sessionStorage
    @$localStorage = $localStorage
    @appName = appName

    @db = {
      user: {config: {incomeCategories: ['Salary', 'Investments:Dividend', 'Income:Misc']}} 
    }

  user: =>
    @db.user

  createCollection: (name, collectionInstance) =>
    @db[name] = collectionInstance
    collectionInstance

  importDatabase: ($q, $sessionStorage) ->
    dateToJsStorage = (dateString) -> 
      moment(dateString).valueOf()

    cleanItem = (item) ->
      item.id = item['_id']
      item.created_at = moment(item.created_at).valueOf() if item.created_at
      item.updated_at = moment(item.updated_at).valueOf() if item.updated_at

      delete item['_id']
      delete item['processing_rule_ids']
      delete item['encrypted_password']

    importFile = (fileName, collectionModel, itemConvert) ->
      deferred = $q.defer();
      $.getJSON fileName, (data) ->
        Lazy(data).each (item) ->
          cleanItem(item)
          itemConvert(item) if itemConvert
          collectionModel.insert(item)
        
        deferred.resolve(true)
      deferred.promise

    importDeferred = $q.defer()

    @loadStateFromLocalStorage($sessionStorage)
    if @db.lineItems.collection && @db.lineItems.collection.length > 1
      importDeferred.resolve(this)
    else
      file1 = importFile '/dumps/Account.json', @accounts()
      file2 = importFile '/dumps/LineItem.json', @lineItems(), (item) ->
        item.event_date = dateToJsStorage(item.event_date)
        if item.original_event_date
          item.original_event_date = dateToJsStorage(item.original_event_date) 
        else
          item.original_event_date = item.event_date
      file3 = importFile '/dumps/BudgetItem.json', @budgetItems()
      file4 = importFile '/dumps/PlannedItem.json', @plannedItems(), (item) ->
        item.event_date_start = dateToJsStorage(item.event_date)
        item.event_date_end = dateToJsStorage(item.event_date)

      $q.all([file1, file2, file3, file4]).then (values) => 
        @saveStateToLocalStorage($sessionStorage)
        importDeferred.resolve(this)
    
    importDeferred.promise
  
  collectionToStorage: (dbModel) ->
    {
      version: dbModel.version()
      data: dbModel.collection
    }

  getTables: (tableList) ->
    deferred = @$q.defer();
    missingDataSets = []
    Lazy(tableList).each (tableName) =>
      if @$sessionStorage[@appName + '-' + tableName]
        dbModel = @db[tableName]
        collectionFromSession = angular.copy(@$sessionStorage[@appName + '-' + tableName])
        if collectionFromSession
          if collectionFromSession.version
            dbModel.collection = collectionFromSession.data
          else
            dbModel.collection = collectionFromSession
          dbModel.migrateIfNeeded(collectionFromSession.version)
          dbModel.reExtendItems()
      else
        missingDataSets.push(tableName)

    loadDataSet = (dataSet) =>
      dbModel = @db[dataSet.name]
      if !dataSet.content
        console.log('failed to load ' + dataSet.name)
        return
      if dataSet.content.indexOf('"iv":') >= 0
        try
          dataSet.content = JSON.parse(sjcl.decrypt(@$localStorage.encryptionKey, dataSet.content))
        catch err
          console.log('failed to decrypt ' + dataSet.name)
          return
      else
        dataSet.content = JSON.parse(dataSet.content)
      if !dataSet.content.version
        console.log('failed to load ' + dataSet.name + ' - version missing')
        return
      
      dbModel.collection = dataSet.content.data
      dbModel.migrateIfNeeded()
      dbModel.reExtendItems()
      console.log 'saving dataset:', dataSet.name, 'to session'
      @$sessionStorage[@appName + '-' + dataSet.name] = angular.copy(@collectionToStorage(dbModel))

    fetchTables = (tableList) =>
      @$http.get('/data/datasets?' + $.param({appName: @appName, tableList: tableList}))
        .success (response, status, headers) =>
          Lazy(response.tablesResponse).each(loadDataSet)
          @db.user.email = response.user.email
          @$sessionStorage.user = {email: response.user.email}
          if !@$localStorage.encryptionKey
            deferred.reject({data: {reason: 'missing_key'}, status: 403, headers: headers})
          else
            deferred.resolve(this)
        .error (data, status, headers) ->
          console.log(data)
          deferred.reject({data: data, status: status, headers: headers})

    if missingDataSets.length > 0
      console.log 'loading data sets: ', missingDataSets
      fetchTables(missingDataSets)
    else if @$sessionStorage.user
      console.log 'all data sets ', tableList, 'and user found in session - resolving'
      @db.user.email = @$sessionStorage.user.email
      deferred.resolve(this)
    else
      console.log 'user not found in session, loading [] data sets'
      fetchTables([])

    deferred.promise

  saveTables: (tableList) =>
    toParam = (dataSet) =>
      name: dataSet
      content: sjcl.encrypt(@$localStorage.encryptionKey, angular.toJson(@collectionToStorage(@db[dataSet])))

    deferred = @$q.defer();
    dataSets = Lazy(tableList).map(toParam).toArray()

    @$http.post('/data/datasets?' + $.param({appName: @appName}), dataSets)
      .success (data, status, headers) =>
        Lazy(tableList).each (tableName) =>
          console.log 'saving dataset:', tableName, 'to session'
          @$sessionStorage[@appName + '-' + tableName] = angular.copy(@collectionToStorage(@db[tableName]))
        deferred.resolve(data)
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


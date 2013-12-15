class Collection
  constructor: ($q, sortColumn, extendFunc) ->
    @$q = $q
    @collection = []
    @sortColumn = sortColumn
    @lastInsertedId = null
    if extendFunc
      extendFunc(this)

  @doNotConvertFunc = (item) -> item

  setItemExtendFunc: (extendFunc) ->
    @itemExtendFunc = extendFunc

  reExtendItems: ->
    return if !@itemExtendFunc
    Lazy(@collection).each (item) =>
      @itemExtendFunc(item)

  findById: (id) ->
    result = Lazy(@collection).find (item) -> item.id == id
    result = angular.copy(result) if result
    result

  getAll: (sortBy) ->
    if !sortBy && @sortColumn
      sortBy = @defaultSortFunction

    result = angular.copy(@collection)
    result = Lazy(result).sortBy sortBy if sortBy
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
      id = moment().valueOf()
      details.id = id
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
    deferred.resolve()

  length: =>
    @collection.length

  removeById: (id) =>
    item = @findById(id)
    index = @collection.indexOf(item)
    @collection.splice(index, 1)

class LineItemCollection extends Collection
  @EXPENSE = 1
  @INCOME = 0

  getItemsByMonthYear: (month, year, sortBy) ->
    Lazy(@collection).filter((item) -> 
      date = moment(item.event_date)
      date.month() == month && date.year() == year
    ).sortBy(sortBy)

  getCategories: () ->
    Lazy(@collection).map((item) -> item.category_name).uniq().sortBy(Lazy.identity).toArray()

class BudgetItemCollection extends Collection
  getYearRange: ->
    Lazy(@collection).pluck('budget_year').uniq().sortBy(Lazy.identity).toArray()

class Database
  @ACCOUNTS_TBL = "accounts"
  @LINE_ITEMS_TBL = "lineItems"
  @BUDGET_ITEMS_TBL = "budgetItems"
  @PLANNED_ITEMS = "plannedItems"
  constructor: ($http, $q, $sessionStorage) ->
    @$http = $http
    @$q = $q
    @$sessionStorage = $sessionStorage

    @db = {
      accounts: new Collection($q, 'name')
      lineItems: new LineItemCollection($q, 'event_date')
      budgetItems: new BudgetItemCollection($q, 'budget_year')
      plannedItems: new Collection($q)
      user: {config: {incomeCategories: ['Salary', 'Investments:Dividend', 'Income:Misc']}}
    }
    @db.lineItems.setItemExtendFunc (item) ->
      item.$isExpense = ->
        @type == LineItemCollection.EXPENSE
      item.$isIncome = ->
        @type == LineItemCollection.INCOME
      item.$eventDate = ->
        moment(@event_date)
      item.$multiplier = ->
        if @type == LineItemCollection.EXPENSE then -1 else 1
      item.$signedAmount = ->
        parseFloat(@amount) * @$multiplier()

    @db.plannedItems.setItemExtendFunc (item) ->
      item.$isIncome = ->
        @type == 'income'
      item.$isExpense = ->
        @type == 'expense'
      item.$eventDateStart = ->
        moment(@event_date_start)
      item.$eventDateEnd = ->
        moment(@event_date_end)
    
  accounts: ->
    @db.accounts

  lineItems: ->
    @db.lineItems

  budgetItems: ->
    @db.budgetItems

  user: ->
    @db.user

  plannedItems: ->
    @db.plannedItems

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
  
  getTables: (tableList) ->
    deferred = @$q.defer();
    missingDataSets = []
    Lazy(tableList).each (dataSet) =>
      if @$sessionStorage[dataSet]
        dbModel = @db[dataSet]
        dbModel.collection = angular.copy(@$sessionStorage[dataSet])
        dbModel.reExtendItems() if dbModel.reExtendItems
      else
        missingDataSets.push(dataSet)

    loadDataSets = (dataSets) =>
      @$http.get('/data/datasets?' + $.param({dataSets: dataSets}))
        .success (data, status, headers) =>
          Lazy(data.data).each (dataSet) =>
            dbModel = @db[dataSet.name]
            dbModel.collection = JSON.parse(dataSet.content)
            dbModel.collection = [] if dbModel.collection == null
            dbModel.reExtendItems() if dbModel.reExtendItems
            console.log 'saving dataset:', dataSet.name, 'to session'
            @$sessionStorage[dataSet.name] = dbModel.collection
          @db.user.email = data.user.email
          @$sessionStorage.user = {email: data.user.email}
          deferred.resolve(this)
        .error (data, status, headers) ->
          console.log(data)
          deferred.reject({data: data, status: status, headers: headers})

    if missingDataSets.length > 0
      console.log 'loading data sets: ', missingDataSets
      loadDataSets(missingDataSets)
    else if @$sessionStorage.user
      console.log 'all data sets ', tableList, 'and user found in session - resolving'
      @db.user.email = @$sessionStorage.user.email
      deferred.resolve(this)
    else
      console.log 'user not found in session, loading [] data sets'
      loadDataSets([])

    deferred.promise

  saveTables: (tableList) =>
    toParam = (dataSet) =>
      name: dataSet
      content: angular.toJson(@db[dataSet].collection)

    deferred = @$q.defer();
    dataSets = Lazy(tableList).map(toParam).toArray()

    @$http.post('/data/datasets', dataSets)
      .success (data, status, headers) =>
        Lazy(tableList).each (dataSet) =>
          console.log 'saving dataset:', dataSet.name, 'to session'
          @$sessionStorage[dataSet] = @db[dataSet].collection
        deferred.resolve(data)
      .error (data, status, headers) ->
        deferred.reject({data: data, status: status, headers: headers})

    deferred.promise
  
class Box
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


# JS Functions
importDatabase = ($q, db) ->
  dateToJsStorage = (dateString) -> 
    moment(dateString).valueOf()

  importFile = (fileName, itemConvert) ->
    deferred = $q.defer();
    $.getJSON fileName, (data) ->
      data.forEach(itemConvert)
      deferred.resolve(true)
    deferred.promise

    # 0 - Provident Checking
    # 1 - Provident Visa
    # 2 - Chase CC

  accountsMap = {}
  importedLinesMap = {}

  importAccount = ->
    importFile '/dumps/Account.json', (account) ->
      if(account.name  == 'Provident - Checking')
        accountsMap[account._id] = '1'
      else if(account.name  == 'Provident - Credit Card')
        accountsMap[account._id] = '2'
      else if (account.name  == 'Chase - Credit Card')
        accountsMap[account._id] = '3'
    
  amountOfImportLines = 0
  importImportedLines = ->
    console.log('import imported lines')
    importFile '/dumps/ImportedLine.json', (item) ->
      return if !accountsMap[item.account_id]
      amountOfImportLines += 1
      originalLine = JSON.parse(item.imported_line)
      
      originalLine.type = if originalLine.type == 0 then LineItemCollection.INCOME else LineItemCollection.EXPENSE
      originalLine.amount = parseFloat(originalLine.amount).toString()
      originalLine.date = moment(originalLine.event_date).format('L')
      newLine = "#{originalLine.type},#{originalLine.amount},#{originalLine.payee_name||''},#{originalLine.comment || ''},#{originalLine.date}"

      newItem = {content: newLine}
      db.importedLines().insert(newItem)
      importedLinesMap[item.line_item_id] = newItem.id 

  amountOfLineItems = 0
  importLineItem = ->
    console.log(amountOfImportLines)
    console.log('import line items')
    importFile '/dumps/LineItem.json', (item) ->
      newItem = {
        type: if item.type == 0 then LineItemCollection.INCOME else LineItemCollection.EXPENSE,
        date: dateToJsStorage(item.event_date)
        payeeName: item.payee_name
        accountId: accountsMap[item.account_id]
        comment: item.comment
        tags: item.tags
        amount: parseFloat(item.amount).toString()
        createdAt: dateToJsStorage(item.created_at || moment().toString()) 
        updatedAt: dateToJsStorage(item.updated_at || moment().toString()) 
      }
      newItem.amount = (Math.round(parseFloat(item.amount) * 100) / 100).toString()
      if item.category_name == 'Salary'
        newItem.categoryName = 'Income:Salary'
      else if item.category_name == 'Investments:Dividend'
        newItem.categoryName = 'Income:Dividend'
      else
        newItem.categoryName = item.category_name
      if item.original_event_date
        newItem.originalDate = dateToJsStorage(item.original_event_date) 
      else
        newItem.originalDate = newItem.date
      if item.grouped_label
        newItem.groupedLabel = item.grouped_label
      if importedLinesMap[item._id]
        newItem.source = 'import'
        newItem.importId = importedLinesMap[item._id]
      amountOfLineItems+=1
      db.lineItems().insert(newItem)
      db.categories().findOrCreate(newItem.categoryName)
      db.payees().findOrCreate(newItem.payeeName)

  processingRulesMap = {}
  processingRulesMapReverse = {}

  importProcessingRule = ->
    console.log(amountOfLineItems)
    console.log('import processing rules')
    importFile '/dumps/ProcessingRule.json', (item) ->
      return if !item.expression || !item.replacement
      replacingName = null
      processingRule = null
      if item.item_type == 'payee'
        replacingName = item.expression
        processingRule = {payeeName: item.replacement, categoryName: processingRulesMapReverse[item.replacement]}
        processingRulesMap[item.replacement] = item.expression
      else 
        if processingRulesMap[item.expression]
          replacingName = processingRulesMap[item.expression]
          processingRule = {payeeName: item.expression, categoryName: item.replacement}
        else
          processingRulesMapReverse[item.expression] = item.replacement
      if processingRule && processingRule.categoryName && processingRule.payeeName
        db.processingRules().set('name:' + replacingName, processingRule)


  importBudgetItem = ->
    console.log('import budget items')
    importFile '/dumps/BudgetItem.json', (item) ->
      newItem = {
        name: item.name, 
        categories: item.categories
        budgetYear: item.budget_year
        limit: item.limit
        estimatedMinMonthly: item.estimated_min_monthly_amount
      }
      db.budgetItems().insert(newItem)

  emptyItems = ->
    db.lineItems().collection = []
    db.budgetItems().collection = []
    db.importedLines().collection = []
    db.categories().collection = {}
    db.payees().collection = {}
    db.processingRules().collection = {}

  db.getTables(Object.keys(db.tables))
    .then(emptyItems).then(importAccount).then(importImportedLines).then(importLineItem).then(importProcessingRule).then(importBudgetItem).then () ->
      db.accounts().getAll().toArray().forEach (account) =>
        firstItem = db.lineItems().getItemsByAccountId(account.id, (item) -> item.originalDate + '-' + item.id).first()
        db.lineItems().reBalance(firstItem)
      db.saveTables(Object.keys(db.tables))

  true

# Other

class window.LineItemCollection extends Collection
  @EXPENSE = 1
  @INCOME = 2

  @SOURCE_IMPORT = 'import'

  @EXCLUDE_FROM_REPORT = 'Exclude from Reports'
  @TRANSFER_TO_CASH = 'Transfer:Cash'

  @TAG_CASH = 'Cash'
    
  getYearRange: ->
    Lazy(@collection).map((item) -> moment(item.date).year()).uniq().sortBy(Lazy.identity).toArray()

  getByDynamicFilter: (filter, sortColumns) ->
    results = Lazy(@collection).filter((item) -> 
      if filter.date
        date = moment(item.date)
        return false if !(date.month() == filter.date.month && date.year() == filter.date.year)
      if filter.categories
        return false if filter.categories.indexOf(item.categoryName) < 0
      if filter.accountId
        return false if item.accountId != filter.accountId
      true
    )
    @sortLazy(results, sortColumns)

  getItemsByMonthYear: (month, year, sortColumns) ->
    results = Lazy(@collection).filter((item) -> 
      date = moment(item.date)
      date.month() == month && date.year() == year
    )
    @sortLazy(results, sortColumns)

  getItemsByMonthYearAndCategories: (month, year, categories, sortColumns) ->
    results = Lazy(@collection).filter((item) -> 
      date = moment(item.date)
      date.month() == month && date.year() == year && categories.indexOf(item.categoryName) >= 0
    )
    @sortLazy(results, sortColumns)

  getItemsByAccountId: (accountId, sortColumns) ->
    results = Lazy(@collection).filter((item) -> 
      item.accountId == accountId
    )
    @sortLazy(results, sortColumns)

  reBalance: (modifiedItem) =>
    return if !@collection || @collection.length == 0
    return if !modifiedItem || !modifiedItem.accountId
    
    sortedCollection = @getItemsByAccountId(modifiedItem.accountId, ['originalDate', 'id']).toArray()
    currentBalance = new BigNumber(0)

    if !modifiedItem || (modifiedItem.id == sortedCollection[0].id)
      startIndex = 0
    else
      startIndex = Lazy(sortedCollection).pluck('id').indexOf(modifiedItem.id)
      currentBalance = new BigNumber(sortedCollection[startIndex-1].balance)
    
    [startIndex..(sortedCollection.length-1)].forEach (index) =>
      if !(sortedCollection[index].tags && sortedCollection[index].tags.indexOf(LineItemCollection.TAG_CASH) >= 0) # don't increase balance for cash
        currentBalance = currentBalance.plus(sortedCollection[index].$signedAmount())
      sortedCollection[index].balance = currentBalance.toString()

  cloneLineItem: (originalItem) =>
    newItem = {}
    angular.copy(originalItem, newItem)
    delete newItem['id']
    delete newItem['createdAt']
    delete newItem['updatedAt']
    delete newItem['balance']
    newItem

class BudgetItemCollection extends Collection
  getYearRange: ->
    Lazy(@collection).pluck('budget_year').uniq().sortBy(Lazy.identity).toArray()

class ImportedLinesCollection extends Collection
  findByContent: (content) ->
    index = Lazy(@collection).pluck('content').indexOf(content)
    return null if index < 0
    @collection[index]

class MemoriesCollection extends Collection

  migrateIfNeeded: ->

  getItemsByMonthYear: (month, year, sortColumns) ->
    results = Lazy(@collection).filter((item) -> 
      date = moment(item.date)
      date.month() == month && date.year() == year
    )
    @sortLazy(results, sortColumns)

  getItemsByEventId: (eventId, sortColumns) ->
    results = Lazy(@collection).filter((item) -> item.events && item.events.indexOf(eventId) >= 0 )
    @sortLazy(results, sortColumns)

  getItemsByParentMemoryId: (parentMemoryId, sortColumns) ->
    results = Lazy(@collection).filter((item) -> item.parentMemoryId == parentMemoryId)
    @sortLazy(results, sortColumns)

  getMemoriesByPersonId: (personId, sortColumns) ->
    results = Lazy(@collection).filter((item) -> item.people && item.people.indexOf(personId) >= 0 )
    @sortLazy(results, sortColumns)

  getAllParentMemories: (sortColumns) ->
    results = Lazy(@collection).filter((item) -> !item.parentMemoryId && (!item.events || item.events.length == 0) )
    @sortLazy(results, sortColumns)

  getMemoriesMentionedAtEventId: (eventId, sortColumns) ->
    results = Lazy(@collection).filter((item) -> item.mentionedIn && item.mentionedIn.indexOf(eventId) >= 0 )
    @sortLazy(results, sortColumns)

  getMemoriesMentionedToPersonId: (personId, sortColumns) ->
    results = Lazy(@collection).filter((item) -> item.mentionedTo && item.mentionedTo.indexOf(personId) >= 0 )
    @sortLazy(results, sortColumns)

class EventsCollection extends Collection
  getItemsByMonthYear: (month, year, sortColumns) ->
    results = Lazy(@collection).filter((item) -> 
      date = moment(item.date)
      date.month() == month && date.year() == year
    )
    @sortLazy(results, sortColumns)

  getEventsByParticipantId: (participantId, sortColumns) ->
    results = Lazy(@collection).filter((item) -> item.participantIds && item.participantIds.indexOf(participantId) >= 0 )
    @sortLazy(results, sortColumns)

angular.module('app.services', ['ngStorage'])
  .factory 'mdb', ($http, $q, $sessionStorage, $localStorage, $rootScope, fileSystem) ->
    tablesList = {
      memories: 'memories'
      events: 'events'
      people: 'people'
      categories: 'categories'
    }
    db = new Database('memoryng', $http, $q, $sessionStorage, $localStorage, fileSystem)
    tables = {
      memories: db.createCollection(tablesList.memories, new MemoriesCollection($q, ['date', 'id']))
      events: db.createCollection(tablesList.events, new EventsCollection($q, 'date'))
      people: db.createCollection(tablesList.people, new Collection($q,'name')),
      categories: db.createCollection(tablesList.categories, new SimpleCollection($q))
    }

    # events
    tables.events.setItemExtendFunc (item) ->
      item.$participants = ->
        getAll: ->
          tables.people.findByIds(item.participantIds)
      item.$memories = ->
        getAll: ->
          tables.memories.getItemsByEventId(item.id)
      item.$mentioned = ->
        getAll: ->
          tables.memories.getMemoriesMentionedAtEventId(item.id)

    tables.people.setItemExtendFunc (item) ->
      item.$mentioned = ->
        getAll: ->
          tables.memories.getMemoriesMentionedToPersonId(item.id)

    accessFunc = {
      tables: tablesList
      memories: ->
        tables.memories
      events: ->
        tables.events
      people: ->
        tables.people
      categories: ->
        tables.categories
      user: ->
        db.user()
      authAndCheckData: (tableList) =>
        db.authAndCheckData(tableList)
      getTables: (tableList, forceRefreshAll) =>
        defer = $q.defer()
        db.getTables(tableList, forceRefreshAll).then((db) =>
          $rootScope.user = accessFunc.user()
          defer.resolve(accessFunc)
        , (err) =>
          defer.reject(err)
        )
        defer.promise

      saveTables: (tableList, forceServerCleanAndSaveAll) ->
        db.saveTables(tableList, forceServerCleanAndSaveAll)
      dumpAllCollections: (tableList) -> 
        db.dumpAllCollections(tableList)
    }

  .factory 'fdb', ($http, $q, $sessionStorage, $localStorage, $rootScope, fileSystem) ->
    db = new Database('financeng', $http, $q, $sessionStorage, $localStorage, fileSystem)

    tablesList = {
      accounts: 'accounts',
      lineItems: 'lineItems',
      budgetItems: 'budgetItems',
      plannedItems: 'plannedItems'
      categories: 'categories'
      payees: 'payees'
      importedLines: 'importedLines'
      processingRules: 'processingRules'
    }
    tables = {
      accounts: db.createCollection(tablesList.accounts, new Collection($q, 'name'))
      lineItems: db.createCollection(tablesList.lineItems, new LineItemCollection($q, ['date', 'id']))
      budgetItems: db.createCollection(tablesList.budgetItems, new BudgetItemCollection($q, 'budget_year'))
      plannedItems: db.createCollection(tablesList.plannedItems, new Collection($q))
      categories: db.createCollection(tablesList.categories, new SimpleCollection($q))
      payees: db.createCollection(tablesList.payees, new SimpleCollection($q))
      importedLines: db.createCollection(tablesList.importedLines, new ImportedLinesCollection($q))
      processingRules: db.createCollection(tablesList.processingRules, new SimpleCollection($q))
    }
    
    tables.lineItems.setItemExtendFunc (item) ->
      item.$isExpense = ->
        @type == LineItemCollection.EXPENSE
      item.$isIncome = ->
        @type == LineItemCollection.INCOME
      item.$date = ->
        moment(@date)
      item.$multiplier = ->
        if @type == LineItemCollection.EXPENSE then -1 else 1
      item.$signedAmount = ->
        parseFloat(@amount) * @$multiplier()
      item.$signedAmountAbs = ->
        Math.abs(parseFloat(@amount) * @$multiplier())
      item.$addProcessingRule = ->
        return if !@categoryName || !@payeeName
        if @$originalPayeeName
          tables.processingRules.set('name:' + @$originalPayeeName, {payeeName: @payeeName, categoryName: @categoryName})
        else
          tables.processingRules.set('amount:' + @amount, {payeeName: @payeeName, categoryName: @categoryName})
          
      item.$process = ->
        processingRule = null
        if @payeeName && tables.processingRules.has('name:' + @payeeName)
          processingRule = tables.processingRules.get('name:' + @payeeName)
        else if tables.processingRules.has('amount:' + @amount)
          processingRule = tables.processingRules.get('amount:' + @amount)

        if processingRule
          @payeeName = processingRule.payeeName
          @categoryName = processingRule.categoryName
          true
        else
          false

    tables.plannedItems.setItemExtendFunc (item) ->
      item.$isIncome = ->
        @type == 'income'
      item.$isExpense = ->
        @type == 'expense'
      item.$eventDateStart = ->
        moment(@event_date_start)
      item.$eventDateEnd = ->
        moment(@event_date_end)

    
    accessFunc = {
      tables: tablesList
      importDatabase: ->
        importDatabase($q, accessFunc)
      lineItems: ->
        tables.lineItems
      accounts: ->
        tables.accounts
      budgetItems: ->
        tables.budgetItems
      user: ->
        db.user()
      plannedItems: ->
        tables.plannedItems
      categories: ->
        tables.categories
      payees: ->
        tables.payees
      importedLines: ->
        tables.importedLines
      processingRules: ->
        tables.processingRules
      authAndCheckData: (tableList) =>
        db.authAndCheckData(tableList)
      getTables: (tableList, forceRefreshAll = false) =>
        defer = $q.defer()
        db.getTables(tableList, forceRefreshAll).then((db) =>
          $rootScope.user = accessFunc.user()
          defer.resolve(accessFunc)
        , (err) =>
          defer.reject(err)
        )
        defer.promise
      saveTables: (tableList, forceServerCleanAndSaveAll = false) ->
        db.saveTables(tableList, forceServerCleanAndSaveAll)
      dumpAllCollections: (tableList) -> 
        db.dumpAllCollections(tableList)
    }
  
  .factory 'errorReporter', () ->
    errorCallbackToScope: ($scope) ->
      (reason) ->
        $scope.error = "failure for reason: " + reason

angular.module('app.directives', ['app.services', 'app.filters'])
  .directive 'currencyWithSign', ($filter) ->
    {
      restrict: 'E',
      link: (scope, elm, attrs) ->
        currencyFilter = $filter('currency')
        scope.$watch attrs.amount, (value) ->
          if typeof value != 'string'
            value = value.toString()
          if (typeof value == 'undefined' || value == null)
            elm.html('')
          else if value[0] == '-'
            elm.html('<span class="negative">' + currencyFilter(value) + '</span>')
          else
            elm.html('<span class="positive">' + currencyFilter(value) + '</span>')
    }
  
  .directive 'dateFormat', ($filter) ->
    dateFilter = $filter('localDate')
    {  
      require: 'ngModel'
      link: (scope, element, attr, ngModelCtrl) ->
        ngModelCtrl.$formatters.unshift (value) ->
          dateFilter(value)
        
        ngModelCtrl.$parsers.push (value) ->
          moment(value).valueOf()          
    }

  .directive 'floatToString', ($filter) ->
    {  
      require: 'ngModel'
      link: (scope, element, attr, ngModelCtrl) ->
        ngModelCtrl.$formatters.unshift (value) ->
          return 0 if !value
          parseFloat(value)
        
        ngModelCtrl.$parsers.push (value) ->
          value.toString()
    }

  .directive 'typeFormat', ($filter) ->
    typeFilter = $filter('typeString')
    {  
      require: 'ngModel'
      link: (scope, element, attr, ngModelCtrl) ->
        ngModelCtrl.$formatters.unshift (value) ->
          typeFilter(value)
        
        ngModelCtrl.$parsers.push (value) ->
          if value == 'Expense' then LineItemCollection.EXPENSE else LineItemCollection.INCOME
    }

  .directive 'numbersOnly', () ->
    {
      require: 'ngModel',
      link: (scope, element, attrs, modelCtrl) ->
        modelCtrl.$parsers.push (inputValue) -> 
          parseInt(inputValue, 10)
    }

  .directive 'pickadate', () ->
    {
      require: 'ngModel',
      link: (scope, element, attrs, ngModel) ->
        initialized = false
        scope.$watch(() ->
          ngModel.$modelValue;
        , (newValue) ->
          if newValue && !initialized
            element.pickadate({
              format: 'mm/dd/yyyy'
            })
            initialized = true
        )
    }
  .directive "fileread", () ->
    scope: 
      fileread: "="
    link: (scope, element, attributes) ->
      element.bind "change", (changeEvent) ->
        scope.$apply () ->
          scope.fileread = changeEvent.target.files[0]
        
  .directive 'ngConfirmClick', ->
    link: (scope, element, attr) ->
        msg = attr.ngConfirmClick || "Are you sure?";
        clickAction = attr.confirmedClick
        element.bind 'click', (event) ->
          if window.confirm(msg)
            scope.$eval(clickAction)

  .directive 'autoresize', ($window) ->
    restrict: 'A',
    link: (scope, element, attrs) ->
      offset = if !$window.opera then (element[0].offsetHeight - element[0].clientHeight) else (element[0].offsetHeight + parseInt($window.getComputedStyle(element[0], null).getPropertyValue('border-top-width'))) ;

      resize  = (el)  ->
        el.style.height = 'auto';
        el.style.height = (el.scrollHeight  + offset ) + 'px';    
   
      element.bind('input', -> resize(element[0]));
      element.bind('keyup', -> resize(element[0]));

 angular.module('app.filters', [])
  .filter 'localDate', ($filter) ->
    angularDateFilter = $filter('date')
    (theDate) ->
      angularDateFilter(theDate, 'MM/dd/yyyy')

  .filter 'monthDay', ($filter) ->
    angularDateFilter = $filter('date')
    (theDate) ->
      angularDateFilter(theDate, 'MM/dd')

  .filter 'percent', ->
    (value) ->
      value + '%'

  .filter 'mbCurrency', ($filter) ->
    angularCurrencyFilter = $filter('currency')
    (number) ->
      result = angularCurrencyFilter(number)
      if result[0] == '('
        '-' + result[1..-2]
      else
        result

  .filter 'typeString', ($filter) ->
    (typeInt) ->
      if typeInt == LineItemCollection.EXPENSE then 'Expense' else 'Income'

   .filter 'bnToFixed', ($window) ->
     (value, format) -> 
      if (typeof value == 'undefined' || value == null)
        return ''

      value.toFixed(2)

  .filter 'joinBy', () ->
    (input, delimiter) ->
      (input || []).join(delimiter || ',')

  .filter 'newline', ($sce) ->
    (string) ->
      return '' if !string
      $sce.trustAsHtml(string.replace(/\n/g, '<br/>'));
        
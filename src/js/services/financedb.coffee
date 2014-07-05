angular.module('app.services')
  .factory 'fdb', ($q, $rootScope, storageService, userService) ->
    db = new Database('financeng', $q, storageService, userService)

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

    financeDbConfig = {incomeCategories: ['Income:Salary', 'Income:Dividend', 'Income:Misc']}
    
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
      config: ->
        financeDbConfig
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
      createAllFiles: (tableNames) ->
        db.createAllFiles(tableNames)
      authAndCheckData: (tableList) =>
        db.authAndCheckData(tableList)
      getTables: (tableList, forceRefreshAll = false) =>
        db.getTables(tableList, forceRefreshAll)
      saveTables: (tableList, forceServerCleanAndSaveAll = false) ->
        db.saveTables(tableList, forceServerCleanAndSaveAll)
      dumpAllCollections: (tableList) -> 
        db.dumpAllCollections(tableList)
    }
APP_NAME = 'financeng'

angular.module('app.services')
  .factory 'financeidb', ($q, $rootScope, storageService, userService) ->
    
    db = new IndexedDbDatabase(APP_NAME, $q, storageService, userService)
    
    tables = {}
    tables.categories = db.createCollection('categories', new IndexedDbSimpleCollection(APP_NAME, 'categories'))
    tables.payees = db.createCollection('payees', new IndexedDbSimpleCollection(APP_NAME, 'payees'))
    tables.accounts = db.createCollection('accounts', new IndexedDbCollection(APP_NAME, 'accounts', 'name'))
    tables.lineItems = db.createCollection('lineItems', new LineItemCollection(APP_NAME, 'lineItems', ['date', 'id']))

    tables.budgetItems = db.createCollection('budgetItems', new BudgetItemCollection(APP_NAME, 'budgetItems'))
    tables.plannedItems = db.createCollection('plannedItems', new PlannedItemCollection(APP_NAME, 'plannedItems'))
    tables.importedLines = db.createCollection('importedLines', new ImportedLinesCollection(APP_NAME, 'importedLines'))
    tables.processingRules = db.createCollection('processingRules', new IndexedDbSimpleCollection(APP_NAME, 'processingRules'))

    tableNames = {}
    tableNames[name] = name for name, item of tables

    schema = {
        budgetItems:
          key: { keyPath: 'id' }
          indexes:
            id: {unique: true}
            budgetYear: {}
        plannedItems:
          key: { keyPath: 'id' }
          indexes:
            id: {unique: true}
            eventDateStart: {}
            eventDateEnd: {}
        categories:
          key: { keyPath: 'id' }
          indexes:
            id: {unique: true}
        payees:
          key: { keyPath: 'id' }
          indexes:
            id: {unique: true}
        accounts:
          key: { keyPath: 'id' }
          indexes:
            id: {unique: true}
        lineItems:
          key: { keyPath: 'id' }
          indexes:
            id: {unique: true}
            date: {}
            'date_id': {unique: true, key: ['date', 'id']}
            'account_date_id': {unique: true, key: ['accountId', 'date', 'id']}
        importedLines:
          key: { keyPath: 'id' }
          indexes:
            id: {unique: true}
        processingRules:
          key: { keyPath: 'id' }
          indexes:
            id: {unique: true}
      }

    loadTables = ->
      new RSVP.Promise (resolve, reject) =>
        async.each Object.keys(tables), (table, callback) -> 
          tables[table].createDatabase(schema, 1)
          .then -> tables[table].afterLoadCollection()
          .then(callback)
        , (err) ->
          if err then reject(err) else resolve()

    preloaded = {}
    loaders = 
      loadCategories: ->
        tables.categories.getAllKeys().then (categories) ->
          preloaded.categories = categories

      loadPayees:  ->
        tables.payees.getAllKeys().then (payees) ->
          preloaded.payees = payees

      loadAccounts: (db) ->
        tables.accounts.getAll().then (accounts) ->
          preloaded.accounts = accounts

    financeDbConfig = {incomeCategories: ['Income:Salary', 'Income:Dividend', 'Income:Misc']}

    accessFunc = {
      tables: tableNames
      preloaded: preloaded
      config: ->
        financeDbConfig
      budgetItems: ->
        tables.budgetItems
      plannedItems: ->
        tables.plannedItems
      categories: ->
        tables.categories
      payees: ->
        tables.payees
      accounts: ->
        tables.accounts      
      lineItems: ->
        tables.lineItems
      importedLines: ->
        tables.importedLines
      processingRules: ->
        tables.processingRules
      loadTables: ->
        loadTables()
      getTables: (tableList, forceRefreshAll) =>
        db.getTables(tableList, forceRefreshAll)
      saveTables: (tableList, forceServerCleanAndSaveAll) ->
        db.saveTables(tableList, forceServerCleanAndSaveAll)
      loaders: loaders
    }
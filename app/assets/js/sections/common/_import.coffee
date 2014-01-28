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
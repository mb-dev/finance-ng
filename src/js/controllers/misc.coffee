capitalizeFirstLetter = (string) ->
  return string if !string || string.length < 2
  result = string.charAt(0).toUpperCase() + string.slice(1).toLowerCase()

correctCase = (name) ->
  return name if !name
  name.split(' ').map(capitalizeFirstLetter).join(' ')

toImportString = (item) ->
  "#{item.type},#{item.amount},#{item.payeeName||''},#{item.comment || ''},#{moment(item.date).format('L')}"

padTo = (str, length) ->
  return '' unless str
  result = str
  result += ' ' for i in [1..(length-str.length)]
  result


angular.module('app.controllers')
  .controller 'MiscController', ($scope, $routeParams, $location, db, $injector) ->
    $scope.msg = ''
    $scope.forceLoadAll = ->
      $scope.msg = ''
      db.getTables(Object.keys(db.tables), true).then ->
        $scope.msg = 'Done loading all tables'

    $scope.forceSave = (tableName) ->
      $scope.msg = ''
      db.saveTables([tableName], true).then -> $scope.$apply ->
        $scope.msg = "Done saving #{tableName}"

    $scope.reBalanceAll = ->
      $scope.msg = ''
      db.accounts().getAll().then (accounts) ->
        async.each accounts, (account, callback) ->
          db.lineItems().reBalance(null, account.id).then ->
            db.saveTables(['lineItems']).then ->
              callback()
        , (err) -> $scope.$apply ->
          if err
            $scope.msg = 'Error rebalancing'
            console.log('error', err)
          else
            $scope.msg = 'Done rebalancing'

    $scope.recreatePayees = ->
      db.loaders.loadPayees().then (payees) ->
        allPayees = _.indexBy(payees)
        db.lineItems().getAll().then (lineItems) ->
          promises = []
          for lineItem in lineItems
            if !allPayees[lineItem.payeeName]
              promises.push(db.payees().findOrCreate(lineItem.payeeName))
          RSVP.all(promises).then ->
            db.saveTables([db.tables.payees]).then -> console.log 'done'

  .controller 'ImportItemsController', ($scope, $routeParams, $location, db, $injector) ->
    $scope.states = {SELECT_FILE: 'selectFile', REVIEW_ITEMS: 'reviewItems', RENAME_ITEMS: 'renameItems'}
    $scope.allCategories = db.preloaded.categories
    $scope.allPayees = db.preloaded.payees

    $scope.accounts = db.preloaded.accounts
    $scope.account = $scope.accounts[0] if $scope.accounts.length > 0

    processingRules = {}
    processingRules[rule.key] = rule.value for rule in db.preloaded.processingRules

    if $routeParams.accountId
      $scope.account = _($scope.accounts).find({id: parseInt($routeParams.accountId, 10)})

    $scope.weHaveItems = false
    $scope.state = $scope.states.SELECT_FILE

    $scope.onBackToSelectFile = ->
      $scope.state = $scope.states.SELECT_FILE

    $scope.onBackToReviewItems = ->
      $scope.state = $scope.states.REVIEW_ITEMS

    $scope.onFileLoaded = (fileContent) ->
      account = $scope.account
      importedLines = db.preloaded.importedLines
      importer = $injector.get('Import' + account.importFormat)
      $scope.items = db.lineItems().sortLazy(importer.import(fileContent))
      db.lineItems().addHelpers($scope.items)

      # mark items that were imported before with ignore flag
      $scope.items.forEach (item, index) ->
        item.index = index.toString()
        item.$originalJson = toImportString(item)
        item.accountId = account.id
        if(importedLines[item.$originalJson])
          item.$ignore = true
        else
          item.originalDate = item.date
          item.$originalPayeeName = item.payeeName
          if !item.$process(processingRules)
            item.payeeName = correctCase(item.payeeName)
            item.$addRule = false
          else
            item.$addRule = false

      $scope.state = $scope.states.REVIEW_ITEMS
      $scope.$apply()

    $scope.onSubmitFile = ->
      # improve later with:
      reader = new FileReader()
      reader.onload = (e) ->
        $scope.onFileLoaded(e.target.result)
      reader.readAsText($scope.fileToImport)

    $scope.onAcceptItems = ->
      $scope.state = $scope.states.RENAME_ITEMS

    $scope.onConfirmImport = ->
      imported = 0
      promises = []
      $scope.items = db.lineItems().sortLazy($scope.items)
      $scope.items.forEach (item) ->
        return if item.$ignore
        importedLine = {content: item.$originalJson}
        promises.push(db.importedLines().insert(importedLine))
        item.importId = importedLine.lastInsertedId
        item.payeeName = item.payeeName.value if(item.payeeName && item.payeeName.value) # fix a bug
        promises.push(db.lineItems().insert(item))
        promises.push(db.categories().findOrCreate(item.categoryName))
        promises.push(db.payees().findOrCreate(item.payeeName))

        if item.$addRule
          promises.push(item.$addProcessingRule(db.processingRules()))
        imported += 1

      RSVP.all(_.compact(promises))
      .then -> db.lineItems().reBalance($scope.items[0], $scope.items[0].accountId)
      .then -> db.saveTables([db.tables.lineItems, db.tables.categories, db.tables.payees, db.tables.importedLines, db.tables.processingRules])
      .then -> $scope.$apply ->
        $scope.flashSuccess(imported.toString() + ' items were imported successfully!')
        $location.path('/line_items')
      .done()

  .controller 'MiscCategoriesController', ($scope, $routeParams, $location, db, $injector) ->
    $scope.items = db.preloaded.categories

  .controller 'MiscPayeesController', ($scope, $routeParams, $location, db, $injector) ->
    $scope.items = db.preloaded.payees

  .controller 'MiscProcessingRulesController', ($scope, $routeParams, $location, db, $injector) ->
    processingRules = db.preloaded.processingRules

    $scope.processingRulesByName = []
    $scope.processingRulesByAmount = []
    processingRules.forEach (processingRule) ->
      key = processingRule.key
      details = processingRule.value
      if key.indexOf('name:') == 0
        $scope.processingRulesByName.push({name: key.substring(5), payeeName: details.payeeName, categoryName: details.categoryName, key: key})
      else
        $scope.processingRulesByAmount.push({name: key.substring(6), payeeName: details.payeeName, categoryName: details.categoryName, key: key})

    $scope.deleteItem = (key, collection, index) ->
      db.processingRules().deleteKey(key)
      .then -> db.saveTables([db.tables.processingRules])
      .then -> $scope.$apply ->
        collection.splice(index, 1)

  .controller 'MiscImportedLinesController', ($scope, $routeParams, $location, db, $injector) ->
    $scope.importedLines = _.filter db.preloaded.importedLines, (item, index) ->
      if $routeParams.year && $routeParams.month
        try
          parts = item.content.split(',')
          dateParts = parts.pop().split('/')
          dateParts[0] == $routeParams.month && dateParts[2] == $routeParams.year
        catch
          debugger
      else
        true

    $scope.deleteItem = (item, index) ->
      db.importedLines().deleteById(item.id)
      .then -> db.saveTables([db.tables.importedLines]).then -> $scope.$apply ->
        $scope.importedLines.splice(index, 1)

  .controller 'ExportLedger', ($scope, $routeParams, $location, db, $injector) ->
    transformItem = (item) ->
      item.longCategoryName = '    ' + padTo(item.categoryName, 64)
      item.ledgerAccountName = if item.accountId is 1
        '    Assets:ProvidentChecking'
      else
        '    Liabilities:CreditCard:Chase'
      if item.groupedLabel
        item.allTags = '    ; :' + item.groupedLabel.replace(/[ ]/g, '-') + ':' + "\n"
      else
        item.allTags = "\n"
      item

    $scope.items = []
    $scope.cashItems = []
    db.lineItems().getByDynamicFilter(date: {year: +$routeParams.year, month: +$routeParams.month-1}, sortBy: 'originalDate').then (lineItems) -> $scope.$apply ->
      db.lineItems().addHelpers(lineItems)

      for item in lineItems
        if item.tags and item.tags.indexOf('Cash') >= 0
          $scope.cashItems.push(transformItem(item))
        else
          $scope.items.push(transformItem(item))

angular.module('app.filters')
  .filter 'notIgnored', ->
    (items, userAccessLevel) ->
      filtered = [];
      angular.forEach items, (item) ->
        filtered.push(item) if !item.$ignore
      filtered

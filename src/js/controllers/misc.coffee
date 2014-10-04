capitalizeFirstLetter = (string) ->
  return string if !string || string.length < 2
  result = string.charAt(0).toUpperCase() + string.slice(1).toLowerCase()

correctCase = (name) ->
  return name if !name
  name.split(' ').map(capitalizeFirstLetter).join(' ')

toImportString = (item) ->
  "#{item.type},#{item.amount},#{item.payeeName||''},#{item.comment || ''},#{moment(item.date).format('L')}"

angular.module('app.controllers')
  .controller 'ImportItemsController', ($scope, $routeParams, $location, db, $injector) ->
    $scope.states = {SELECT_FILE: 'selectFile', REVIEW_ITEMS: 'reviewItems', RENAME_ITEMS: 'renameItems'}
    $scope.allCategories = db.preloaded.categories
    $scope.allPayees = db.preloaded.payees

    $scope.accounts = db.preloaded.accounts
    $scope.account = $scope.accounts[0] if $scope.accounts.length > 0

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
      $scope.items = importer.import(fileContent)
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
          if !item.$process(db.preloaded.processingRules)
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
      .then -> db.lineItems().reBalance()
      .then -> db.saveTables([db.tables.lineItems, db.tables.categories, db.tables.payees, db.tables.importedLines, db.tables.processingRules])
      .then -> $scope.$apply ->
        $scope.flashSuccess(imported.toString() + ' items were imported successfully!')
        $location.path('/line_items')

  .controller 'MiscCategoriesController', ($scope, $routeParams, $location, db, $injector) ->
    $scope.items = db.preloaded.categories

  .controller 'MiscPayeesController', ($scope, $routeParams, $location, db, $injector) ->
    $scope.items = db.preloaded.payees

  .controller 'MiscProcessingRulesController', ($scope, $routeParams, $location, db, $injector) ->
    processingRules = db.processingRules().getAll().toArray().sort()

    $scope.processingRulesByName = []
    $scope.processingRulesByAmount = []
    processingRules.forEach (item) ->
      details = db.processingRules().get(item)
      if Lazy(item).startsWith('name:')
        $scope.processingRulesByName.push({name: item.substring(5), payeeName: details.payeeName, categoryName: details.categoryName, key: item})
      else
        $scope.processingRulesByAmount.push({name: item.substring(6), payeeName: details.payeeName, categoryName: details.categoryName, key: item})

    $scope.deleteItem = (key, collection, index) ->
      db.processingRules().delete(key)
      db.saveTables([db.tables.processingRules]).then ->
        collection.splice(index, 1)

  .controller 'MiscImportedLinesController', ($scope, $routeParams, $location, db, $injector) ->
    $scope.importedLines = db.importedLines().getAll().filter((item, index) ->
      if $routeParams.year && $routeParams.month
        try
          parts = item.content.split(',')      
          dateParts = parts.pop().split('/')
          dateParts[0] == $routeParams.month && dateParts[2] == $routeParams.year
        catch
          debugger
      else
        true
    ).toArray()

    $scope.deleteItem = (item, index) ->
      db.importedLines().deleteById(item.id)
      db.saveTables([db.tables.importedLines]).then ->
        $scope.importedLines.splice(index, 1)

angular.module('app.filters')
  .filter 'notIgnored', ->
    (items, userAccessLevel) ->
      filtered = [];
      angular.forEach items, (item) ->
        filtered.push(item) if !item.$ignore
      filtered
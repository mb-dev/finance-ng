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
    $scope.allCategories = db.categories().getAll().toArray()
    payeesEngine = new Bloodhound({
      datumTokenizer: (d) -> Bloodhound.tokenizers.whitespace(d.value)
      queryTokenizer: Bloodhound.tokenizers.whitespace,
      local: db.payees().getAll().toArray().map (item) -> {value: item}
    })
    payeesEngine.initialize()

    $scope.allPayees = {
      displayKey: 'value',
      source: payeesEngine.ttAdapter()
    }

    $scope.payeeAutoCompleteOptions = {
      hint: false
    }

    $scope.accounts = db.accounts().getAll().toArray()
    $scope.accountId = $scope.accounts[0].id if $scope.accounts.length > 0

    if $routeParams.accountId
      $scope.accountId = parseInt($routeParams.accountId, 10)

    $scope.weHaveItems = false
    $scope.state = $scope.states.SELECT_FILE

    $scope.onBackToSelectFile = ->
      $scope.state = $scope.states.SELECT_FILE

    $scope.onBackToReviewItems = ->
      $scope.state = $scope.states.REVIEW_ITEMS

    $scope.onFileLoaded = (fileContent) ->
      account = db.accounts().findById($scope.accountId)
      importedLines = db.importedLines().getAll().pluck('content').reduce (result, item, index) -> 
        result[item] = true
        result
      , {}
      importer = $injector.get('Import' + account.importFormat)
      $scope.items = importer.import(fileContent)

      # mark items that were imported before with ignore flag
      $scope.items.forEach (item, index) ->
        item.index = index.toString()
        db.lineItems().extendItem(item)
        item.$originalJson = toImportString(item)
        item.accountId = account.id
        if(importedLines[item.$originalJson])
          item.$ignore = true
        else
          item.originalDate = item.date
          item.$originalPayeeName = item.payeeName
          if !item.$process()
            item.payeeName = correctCase(item.payeeName)
            item.$addRule = true
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
      $scope.items.forEach (item) ->
        return if item.$ignore
        db.importedLines().insert({content: item.$originalJson})
        item.importId = db.importedLines().lastInsertedId
        if(item.payeeName && item.payeeName.value)
          item.payeeName = item.payeeName.value
        db.lineItems().insert(item)
        db.categories().findOrCreate(item.categoryName)
        db.payees().findOrCreate(item.payeeName)

        if item.$addRule
          item.$addProcessingRule()
        imported += 1

      firstModifiedItem = Lazy($scope.items).filter((item) -> !item.$ignore).sortBy((item) -> [item.date, item.id]).first()
      db.lineItems().reBalance(firstModifiedItem)
      db.saveTables([db.tables.lineItems, db.tables.categories, db.tables.payees, db.tables.importedLines, db.tables.processingRules]).then ->
        $scope.flashSuccess(imported.toString() + ' items were imported successfully!')
        $location.path('/line_items')

  .controller 'MiscCategoriesController', ($scope, $routeParams, $location, db, $injector) ->
    $scope.items = db.categories().getAll().toArray().sort()

  .controller 'MiscPayeesController', ($scope, $routeParams, $location, db, $injector) ->
    $scope.items = db.payees().getAll().toArray().sort()

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
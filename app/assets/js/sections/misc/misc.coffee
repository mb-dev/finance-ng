capitalizeFirstLetter = (string) ->
  return string if !string || string.length < 2
  result = string.charAt(0).toUpperCase() + string.slice(1).toLowerCase()

correctCase = (name) ->
  return name if !name
  name.split(' ').map(capitalizeFirstLetter).join(' ')

angular.module('app.controllers')
  .controller 'ImportItemsController', ($scope, $routeParams, $location, db, $injector) ->
    $scope.states = {SELECT_FILE: 'selectFile', REVIEW_ITEMS: 'reviewItems', RENAME_ITEMS: 'renameItems'}
    $scope.allCategories = {
      name: 'categories'
      local: db.categories().getAll().toArray()
    }
    $scope.allPayees = {
      name: 'payees'
      local: db.payees().getAll().toArray()
    }

    $scope.accounts = db.accounts().getAll().toArray()
    $scope.accountId = $scope.accounts[0].id if $scope.accounts.length > 0
    $scope.weHaveItems = false
    $scope.state = $scope.states.SELECT_FILE

    $scope.onBackToSelectFile = ->
      $scope.state = $scope.states.SELECT_FILE

    $scope.onBackToReviewItems = ->
      $scope.state = $scope.states.REVIEW_ITEMS

    $scope.onFileLoaded = (fileContent) ->
      account = db.accounts().findById($scope.accountId)
      importedLines = db.importedLines().getAll().pluck('content').reduce (result, item) -> 
        result[item] = true 
        result
      , {}
      importer = $injector.get('Import' + account.importFormat)
      $scope.items = importer.import(fileContent)

      # mark items that were imported before with ignore flag
      $scope.items.forEach (item) ->
        db.lineItems().extendItem(item)
        item.$originalJson = angular.toJson(item)
        item.accountId = account.id
        if(importedLines[item.$originalJson])
          item.$ignore = true
        else
          item.originalDate = item.date
          item.$originalPayeeName = item.payeeName
          if !item.$process()
            item.payeeName = correctCase(item.payeeName)
            item.$addRule = true

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
        db.lineItems().insert(item)
        db.categories().findOrCreate(item.categoryName)
        db.payees().findOrCreate(item.payeeName)

        if item.$addRule
          item.$addProcessingRule()
        imported += 1

      firstModifiedItem = Lazy($scope.items).filter((item) -> !item.$ignore).sortBy((item) -> item.date).first()
      db.lineItems().reBalance(firstModifiedItem)
      db.saveTables([db.tables.lineItems, db.tables.categories, db.tables.payees, db.tables.importedLines, db.tables.processingRules])
      $scope.flashSuccess(imported.toString() + ' items were imported successfully!')
      $location.path('/line_items')

angular.module('app.filters')
  .filter 'notIgnored', ->
    (items, userAccessLevel) ->
      filtered = [];
      angular.forEach items, (item) ->
        filtered.push(item) if !item.$ignore
      filtered

angular.module('app.importers', [])
  .factory 'ImportProvidentChecking', () ->
    import: (fileContent) ->
      rows = CSV.parse(fileContent)
      rows.splice(0, 1)
      rows.map (row) =>
        date = row[0]
        description = row[1]
        comments = row[2]
        checkNumber = row[3]
        amount = row[4]
        balance = row[5]

        if !Lazy(description).endsWith('(Pending)')
          amountAsFloat = parseFloat(amount.match(/[0-9.\-]+/g).join(''))

          lineItem = {}
          lineItem.source = LineItemCollection.SOURCE_IMPORT
          lineItem.type = if amount[0] == '(' then LineItemCollection.EXPENSE else LineItemCollection.INCOME
          lineItem.amount = Math.abs(amountAsFloat).toString()
          lineItem.comment = "Check #{checkNumber}" if checkNumber
          lineItem.payeeName = description.trim() if !checkNumber
          lineItem.date = moment(date).valueOf()
          lineItem

  .factory 'ImportChaseCC', () ->
    import: (fileContent) ->
      rows = CSV.parse(fileContent)
      rows.splice(0, 1)
      rows.map (row) =>
        type = row[0]
        date = row[1]
        description = row[3]
        amount = row[4]

        amountAsFloat = parseFloat(amount.match(/[0-9.\-]+/g).join(''))

        lineItem = {}
        lineItem.source = LineItemCollection.SOURCE_IMPORT
        lineItem.type = if amountAsFloat < 0 then LineItemCollection.EXPENSE else LineItemCollection.INCOME
        lineItem.amount = Math.abs(amountAsFloat).toString()
        lineItem.payeeName = description.trim()
        lineItem.date = moment(date).valueOf()
        lineItem
      



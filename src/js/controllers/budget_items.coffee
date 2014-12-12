angular.module('app.controllers')
  .controller 'BudgetsIndexController', ($scope, $routeParams, $location, $modal, db, budgetReportService) ->
    $scope.currentYear = moment().year()
    if $routeParams.year
      $scope.currentYear = parseInt($routeParams.year, 10)
    $scope.months = moment.monthsShort()
    refresh = ->
      db.loaders.loadBudgetItemsForYear($scope.currentYear).then -> $scope.$apply ->
        reportGenerator = budgetReportService.getReportForYear(db, $scope.currentYear)
        $scope.report = reportGenerator.generateReport()
    refresh()

    $scope.nextYear = ->
      $location.path('/budgets/' + ($scope.currentYear+1).toString())
    $scope.prevYear = ->
      $location.path('/budgets/' + ($scope.currentYear-1).toString())

    $scope.editBudgetItem = (budgetItemId) ->
      db.preloaded.budgetItem = angular.copy(_.find(db.preloaded.budgetItems, {id: budgetItemId}))
      dialog = $modal({template: '/partials/budgets/formDialog.html', show: true})
      dialog.$scope.$on 'itemEdited', (event) ->
        refresh()

    $scope.cloneBudgetItem = (budgetItemId) ->
      db.preloaded.budgetItem = angular.copy(_.find(db.preloaded.budgetItems, {id: budgetItemId}))
      db.preloaded.budgetItem.id = null
      dialog = $modal({template: '/partials/budgets/formDialog.html', show: true})
      dialog.$scope.$on 'itemEdited', (event) ->
        refresh()

  .controller 'BudgetItemsFormController', ($scope, $routeParams, $location, financeidb, errorReporter) ->
    db = financeidb
    db.loaders.loadCategories().then -> $scope.$apply ->
      $scope.categories = db.preloaded.categories

    updateFunc = null
    if db.preloaded.budgetItem?.id
      $scope.title = 'Edit budget item'
      $scope.item = db.preloaded.budgetItem
      updateFunc = db.budgetItems().updateById
    else if db.preloaded.budgetItem
      $scope.title = 'Clone budget item'
      $scope.item = db.preloaded.budgetItem
      updateFunc = db.budgetItems().insert
    else
      $scope.title = 'New budget item'
      $scope.item = {budgetYear: moment().year()}
      updateFunc = db.budgetItems().insert
      

    $scope.onSubmit = ->
      onSuccess = -> $scope.$apply -> 
        if $scope.$hide?
          $scope.$emit('itemEdited', $scope.item)
          $scope.$hide()
        else
          $location.path('/budgets/' + $scope.item.budgetYear.toString())

      updateFunc($scope.item)
      .then -> db.saveTables([db.tables.budgetItems])
      .then(onSuccess, errorReporter.errorCallbackToScope($scope))

angular.module('app.services')
  .factory 'budgetReportService', () ->
    getReportForYear: (db, year) ->
      budgetReport = new BudgetReportView(db, year)
      budgetReport
angular.module('app.controllers')
  .controller 'BudgetsIndexController', ($scope, $routeParams, $location, db, budgetReportService) ->
    $scope.currentYear = moment().year()
    if $routeParams.year
      $scope.currentYear = parseInt($routeParams.year, 10)
    $scope.months = moment.monthsShort()
    reportGenerator = budgetReportService.getReportForYear(db, $scope.currentYear)
    $scope.report = reportGenerator.generateReport()

    $scope.nextYear = ->
      $location.path('/budgets/' + ($scope.currentYear+1).toString())
    $scope.prevYear = ->
      $location.path('/budgets/' + ($scope.currentYear-1).toString())

  .controller 'BudgetItemsFormController', ($scope, $routeParams, $location, db, errorReporter) ->
    updateFunc = null
    if Lazy($location.$$url).endsWith('new')
      $scope.title = 'New budget item'
      $scope.item = {budget_year: moment().year()}
      updateFunc = db.budgetItems().insert
    else
      $scope.title = 'Edit account'
      $scope.item = db.budgetItems().findById($routeParams.itemId)
      updateFunc = db.budgetItems().editById

    $scope.categories = db.lineItems().getCategories()

    $scope.onSubmit = ->
      onSuccess = -> $location.path('/budgets/' + $scope.item.budget_year.toString())
      saveTables = -> db.saveTables([Database.BUDGET_ITEMS_TBL])
      updateFunc($scope.item).then(saveTables).then(onSuccess, errorReporter.errorCallbackToScope($scope))

angular.module('app.services')
  .factory 'budgetReportService', () ->
    getReportForYear: (db, year) ->
      budgetReport = new BudgetReportView(db, year)
      budgetReport
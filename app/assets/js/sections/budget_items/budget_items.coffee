angular.module('app.controllers')
  .controller 'BudgetsIndexController', ($scope, $routeParams, $location, db, budgetReportService) ->
    report = null
    applyDateChanges = ->
        reportGenerator = budgetReportService.getReportForYear(db, $scope.currentDate.year())
        $scope.report = reportGenerator.generateReport()
    $scope.yearRanges = db.budgetItems().getYearRange()
    
    $scope.currentDate = moment('2012-01-01')
    if $routeParams.year
      $scope.currentDate.year(+$routeParams.year)
    $scope.months = moment.monthsShort()
    applyDateChanges()

    $scope.selectYear = (year) ->
      $scope.currentDate.year(year)
      $location.path('/budgets/' + $scope.currentDate.year().toString())

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

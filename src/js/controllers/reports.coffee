angular.module('app.controllers')
  .controller 'ReportsIndexController', ($scope, $routeParams, $location, db, reportService) ->
    $scope.currentYear = moment().year()
    if $routeParams.year
      $scope.currentYear = parseInt($routeParams.year, 10)
    $scope.months = moment.monthsShort()
    reportGenerator = reportService.getReportForYear(db, $scope.currentYear)
    reportGenerator.generateReport().then (report) -> $scope.$apply ->
      $scope.report = report

    $scope.nextYear = ->
      $location.path('/reports/' + ($scope.currentYear+1).toString())
    $scope.prevYear = ->
      $location.path('/reports/' + ($scope.currentYear-1).toString())

  .controller 'ReportsShowController', ($scope, $routeParams, $location, db, reportService) ->
    $scope.months = moment.monthsShort()
    $scope.currentYear = parseInt($routeParams.year, 10)
    $scope.rootCategory = $routeParams.item

    reportGenerator = reportService.getReportForYear(db, $scope.currentYear)
    reportGenerator.generateReport().then (report) -> $scope.$apply ->
      $scope.report = report
      $scope.rootCategoryInfo = _.find($scope.report.reportSections[1].rootCategories, {name: $scope.rootCategory})

angular.module('app.services')
  .factory 'reportService', () ->
    getReportForYear: (db, year) ->
      budgetReport = new LineItemsReportView(db, year)
      budgetReport
MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']

getMultibarMonthAmountChart = ->
  type: 'multiBarChart'
  stacked: true
  height: 600
  xAxis:
    axisLabel: 'Month'
    showMaxMin: false
    tickFormat: (d) ->
      MONTHS[d-1]
  yAxis:
    axisLabel: 'Dollars'
    axisLabelDistance: 40
    tickFormat: (d) ->
      d3.format('$f')(d)

generateChartDataFromReport = (report) ->
  data = []
  incomeMonthly = []
  for category in report.reportSections[0].rootCategories
    for column, index in category.monthlyTotals
      incomeMonthly[index] ?= 0.0
      incomeMonthly[index] += parseFloat(column.total)
  for category in report.reportSections[1].rootCategories
    sectionData = {
      key: category.name
      values: []
    }
    for column, index in category.monthlyTotals
      amount = parseFloat(column.total)
      sectionData.values.push({x: index+1, y: amount})
      incomeMonthly[index] -= amount
    data.push(sectionData)
  incomeData = {
    key: 'Income'
    values: []
  }
  for monthIncome, index in incomeMonthly
    if monthIncome > 0
      incomeData.values.push({x: index+1, y: monthIncome})
    else
      incomeData.values.push({x: index+1, y: 0})
  data.push(incomeData)
  data

angular.module('app.controllers')
  .controller 'ReportsIndexController', ($scope, $routeParams, $location, db, reportService) ->
    $scope.currentYear = moment().year()
    if $routeParams.year
      $scope.currentYear = parseInt($routeParams.year, 10)
    $scope.months = moment.monthsShort()
    reportGenerator = reportService.getReportForYear(db, $scope.currentYear)
    $scope.options = {
      chart: getMultibarMonthAmountChart()
    }
    $scope.data = []
    reportGenerator.generateReport().then (report) -> $scope.$apply ->
      $scope.report = report
      $scope.data = generateChartDataFromReport(report)
      
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
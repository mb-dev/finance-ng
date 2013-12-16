#= require ./db
#= require ./reports
#= require ./config/app
#= require ./sections/accounts/accounts
#= require ./sections/line_items/line_items  
#= require ./sections/budget_items/budget_items
#= require ./sections/user/user

#= require ./sections/memories/memories

angular.module('app.filters', [])
  .filter 'localDate', ($filter) ->
    angularDateFilter = $filter('date')
    (theDate) ->
      angularDateFilter(theDate, 'MM/dd/yyyy')

  .filter 'typeString', ($filter) ->
    (typeInt) ->
      if typeInt == LineItemCollection.EXPENSE then 'Expense' else 'Income'

   .filter 'bnToFixed', ($window) ->
     (value, format) -> 
      if (typeof value == 'undefined' || value == null)
        return ''

      value.toFixed(2)


angular.module('app.services', ['ngStorage'])
  .factory 'fdb', ($http, $q, $sessionStorage, $rootScope) ->
    new Database($http, $q, $sessionStorage)
  .factory 'budgetReportService', () ->
    getReportForYear: (db, year) ->
      budgetReport = new BudgetReportView(db, year)
      budgetReport
  .factory 'errorReporter', () ->
    errorCallbackToScope: ($scope) ->
      (reason) ->
        $scope.error = "failure for reason: " + reason

angular.module('app.directives', ['app.services', 'app.filters'])
  .directive 'currencyWithSign', ->
    {
      restrict: 'E',
      link: (scope, elm, attrs) ->
        scope.$watch attrs.amount, (value) ->
          if (typeof value == 'undefined' || value == null)
            elm.html('')
          else if value[0] == '-'
            elm.html('<span class="negative">' + value + '</span>')
          else
            elm.html('<span class="positive">' + value + '</span>')
    }
  
  .directive 'dateFormat', ($filter) ->
    dateFilter = $filter('localDate')
    {  
      require: 'ngModel'
      link: (scope, element, attr, ngModelCtrl) ->
        ngModelCtrl.$formatters.unshift (value) ->
          dateFilter(value)
        
        ngModelCtrl.$parsers.push (value) ->
          moment(value).valueOf()          
    }

  .directive 'typeFormat', ($filter) ->
    typeFilter = $filter('typeString')
    {  
      require: 'ngModel'
      link: (scope, element, attr, ngModelCtrl) ->
        ngModelCtrl.$formatters.unshift (value) ->
          typeFilter(value)
        
        ngModelCtrl.$parsers.push (value) ->
          if value == 'Expense' then LineItemCollection.EXPENSE else LineItemCollection.INCOME
    }

  .directive 'numbersOnly', () ->
    {
      require: 'ngModel',
      link: (scope, element, attrs, modelCtrl) ->
        modelCtrl.$parsers.push (inputValue) -> 
          parseInt(inputValue, 10)
    }
 
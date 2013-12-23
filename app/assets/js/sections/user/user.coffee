angular.module('app.controllers')
   .controller 'UserLoginController', ($scope, $window) ->
    $scope.loginOauth = (provider) ->
      $window.location.href = '/auth/' + provider;

  .controller 'UserKeyController', ($scope, $window, $localStorage, $location) ->
    $scope.key = ''

    $scope.onSubmit = ->
      $localStorage.encryptionKey = $scope.key
      $location.path('/line_items')


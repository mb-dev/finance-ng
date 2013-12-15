angular.module('app.controllers')
  .controller 'UserController', ($scope, $window) ->
    $scope.loginOauth = (provider) ->
      $window.location.href = '/auth/' + provider;
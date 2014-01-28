root = {}

describe 'storageService', ->
  beforeEach ->
    module('app')
    inject ($localStorage, storageService) ->
      root.$localStorage = $localStorage
      root.storageService = storageService
  describe 'isAuthenticateTimeAndSet', ->
    it 'should return true the first time and false the other', ->
      expect(root.storageService.isAuthenticateTimeAndSet()).toEqual(true)
      expect(root.storageService.isAuthenticateTimeAndSet()).toEqual(false)
      

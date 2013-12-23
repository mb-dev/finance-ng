
# describe 'graph db', ->
#   beforeEach(module('app'))
#   beforeEach(inject((_$rootScope_, $q) ->
#     root.$q = $q
#   ))
#   it 'should allow associate connections', ->
#     db = new Database(root.$http, root.$q, root.$sessionStorage)
#     db.memoryGraph().associate('memoryToCategory', '1', '1')
#     expect(db.memoryGraph().isAssociated('memoryToCategory', '1', '1')).toEqual(true)
#     expect(db.memoryGraph().getAssociated('memoryToCategory', '1')).toEqual(['1'])

root = {}

describe 'Database', ->
  beforeEach(module('app'))
  beforeEach(inject(($httpBackend, $http) ->
    root.$httpBackend = $httpBackend
    root.$http = $http
    root.appName = 'finance'
    root.tableName = 'people'
    root.getURL = '/data/datasets?' + $.param({appName: root.appName, tableList: [root.tableName]})
    root.postURL = '/data/datasets?' + $.param({appName: root.appName})
    root.getResponse = {user: {email: 'a@a.com'}, tablesResponse: []}
    root.postResponse = {success: true}
    root.item = {name: 'Moshe'}
    root.originalName = 'Moshe'
    root.encryptionKey = "ABC"
    root.storageContent = {
      version: '1.0'
      data: [{id: 1, name: 'Moshe'}]
    }
    root.sessionKey = root.appName + '-' + root.tableName
    root.getResponse.tablesResponse.push {
      name: root.tableName,
      content: sjcl.encrypt(root.encryptionKey, angular.toJson(root.storageContent))
    }
    root.$httpBackend.when('GET', root.getURL).respond(root.getResponse)
    root.$httpBackend.when('POST', root.postURL).respond(root.postResponse)
    root.$q = $q = {
      defer: ->
        { 
          promise: true, 
          resolve: -> 
          reject: -> console.log 'something got rejected'; raise 'error'
        }
    }
    root.$sessionStorage = {}
    root.$localStorage = {encryptionKey: root.encryptionKey}
  ))
  afterEach ->
   root.$httpBackend.verifyNoOutstandingExpectation();
   root.$httpBackend.verifyNoOutstandingRequest();
  describe 'loadTables', ->
    it 'should load data from the network when session has no data', ->
      root.$httpBackend.expectGET(root.getURL)
      db = new Database(root.appName, root.$http, root.$q, root.$sessionStorage, root.$localStorage)
      testCollection = db.createCollection(root.tableName, new Collection(root.$q, 'name'))
      db.getTables([root.tableName])
      root.$httpBackend.flush()
      expect(testCollection.getAll().toArray()).toEqual([{id: 1, name: 'Moshe'}])
      expect(root.$sessionStorage[root.sessionKey]).toEqual(root.storageContent)
      # test session storage isolated
      testCollection.collection[0].name = 'Daniel'
      expect(root.$sessionStorage[root.sessionKey]).toEqual(root.storageContent)
    it 'should load data from the session when session has data', ->
      root.$sessionStorage[root.sessionKey] = root.storageContent
      root.$sessionStorage['user'] = {email: 'a@a.com'}
      db = new Database(root.appName, root.$http, root.$q, root.$sessionStorage, root.$localStorage)
      testCollection = db.createCollection(root.tableName, new Collection(root.$q, 'name'))
      db.getTables([root.tableName])
      expect(testCollection.getAll().toArray()).toEqual([{id: 1, name: 'Moshe'}])
      # test session storage isolated
      testCollection.collection[0].name = 'Daniel'
      expect(root.$sessionStorage[root.sessionKey]).toEqual(root.storageContent)
  describe 'saveTables', ->
    it 'should save to the server', ->
      root.$httpBackend.expectPOST(root.postURL)
      db = new Database(root.appName, root.$http, root.$q, root.$sessionStorage, root.$localStorage)
      testCollection = db.createCollection(root.tableName, new Collection(root.$q, 'name'))
      testCollection.insert(root.item)
      db.saveTables([root.tableName])
      root.$httpBackend.flush()
      expect(root.$sessionStorage[root.sessionKey].data[0].name).toEqual(root.item.name)
      # test session storage isolated
      testCollection.collection[0].name = 'Daniel'
      expect(root.$sessionStorage[root.sessionKey].data[0].name).toEqual(root.originalName)

describe 'Box', ->
  it 'should allow setting values', ->
    item = {name: 'Groceries'}
    box = new Box()
    box.addRow(item)
    box.setColumns([0..11], ['expense', 'future_expense', 'planned_expense'])
    box.addToValue(item, 0, 'expense', 100)
    box.addToValue(item, 1, 'expense', 100)

    firstColumnValue = box.rowColumnValues(item)[0]
    expect(firstColumnValue.column).toEqual('0')
    expect(firstColumnValue.values.expense.toFixed(0)).toEqual('100')

    totals = box.rowTotals(item)
    expect(totals['expense'].toFixed(0)).toEqual('200')
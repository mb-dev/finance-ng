root = {}

describe 'ImportItemsController', ->
  beforeEach(module('app'))
  beforeEach(inject(($controller, $rootScope, $injector) ->
    root.$controller = $controller
    root.$scope = $rootScope.$new()
    root.routeParams = {}
    root.db = $injector.get('fdb')
    root.$location = {path: () -> {} }
    $controller('ImportItemsController', {
      $scope: root.$scope,
      $routeParams: root.routeParams,
      $location: root.$location,
      db: root.db,
      $injector: $injector
    });
    root.account = {name: 'Provident', importFormat: 'ProvidentChecking'}
    root.db.accounts().insert(root.account)
  ))
  it 'should import the file', ->
    content = window.fixtures.csv.provident_checking

    spyOn(root.db, 'saveTables').and.callFake -> 
      {then: -> true }
    spyOn(root.$location, 'path')

    # one item was already imported, we have one rule already
    root.db.importedLines().insert({content: '1,1350,,Check 1015,07/03/2012'})
    root.db.processingRules().set('amount:130', {payeeName: 'Home Owner', categoryName: 'Rent'})
    root.db.processingRules().set('name:TARGET T2767 OAKLA OAKLAND CAUS', {payeeName: 'Target', categoryName: 'Shopping'})

    # step 1: load file
    root.$scope.accountId = root.account.id
    root.$scope.onFileLoaded(content)

    expect(root.$scope.items[1].$ignore).toEqual(true) # check was already imported
    expect(root.$scope.items[2].accountId).toEqual(root.account.id) # check was already imported
    expect(root.$scope.state).toEqual(root.$scope.states.REVIEW_ITEMS)

    # step 2 accept items
    root.$scope.onAcceptItems()
    expect(root.$scope.state).toEqual(root.$scope.states.RENAME_ITEMS)

    expect(root.$scope.items[0].payeeName).toEqual('Baci Cafe & Wine B Healdsburg Caus')
    root.$scope.items[0].payeeName = {value: 'Baci Cafe'}
    root.$scope.items[0].categoryName = 'Restaurants'
    root.$scope.items[0].$addRule = true

    root.$scope.items[4].payeeName = 'Another amount'
    root.$scope.items[4].categoryName = 'Rent'
    root.$scope.items[4].$addRule = true

    # step 3: confirm import
    root.$scope.onConfirmImport()
    importedLines = root.db.importedLines().getAll().toArray()
    expect(importedLines.length).toEqual(5)
    expect(importedLines[1].content).toEqual('1,52,BACI CAFE & WINE B HEALDSBURG CAUS,,07/02/2012')
    
    lineItems = root.db.lineItems().getAll().toArray()
    expect(lineItems[1].importId).toEqual(importedLines[2].id)
    expect(lineItems[0].balance).toEqual('-52')
    expect(lineItems[1].balance).toEqual('-66.16')

    expect(root.db.categories().getAll().toArray()).toEqual(['Restaurants', 'Shopping', 'Rent'])
    expect(root.db.payees().getAll().toArray()).toEqual(['Baci Cafe', 'Target', 'Home Owner', 'Another amount'])

    processingRules = root.db.processingRules()
    expect(processingRules.get('name:BACI CAFE & WINE B HEALDSBURG CAUS')).toEqual({payeeName: 'Baci Cafe', categoryName: 'Restaurants'})
    expect(processingRules.get('amount:160')).toEqual({payeeName: 'Another amount', categoryName: 'Rent'})
    expect(root.db.saveTables).toHaveBeenCalled()

describe 'importers', ->
  beforeEach(module('app'))
  describe 'ImportProvidentChecking', ->
    beforeEach(inject((ImportProvidentChecking) ->
      root.importer = ImportProvidentChecking
    ))
    it 'should import the csv', ->
      content = window.fixtures.csv.provident_checking
      result = root.importer.import(content)
      expect(result.length).toEqual(5)
      expect(result[0]).toEqual({ source : 'import', type : 1, amount : '52', payeeName : 'BACI CAFE & WINE B HEALDSBURG CAUS', date : moment('07/02/2012').valueOf() })
      expect(result[1]).toEqual({ source : 'import', type : 1, amount : '1350', comment : 'Check 1015', date : moment('07/03/2012').valueOf() })
  describe 'ImportProvidentVisa', ->
    beforeEach(inject((ImportProvidentVisa) ->
      root.importer = ImportProvidentVisa
    ))
    it 'should import the csv', ->
      content = window.fixtures.csv.provident_visa
      result = root.importer.import(content)
      expect(result.length).toEqual(4)
      expect(result[0]).toEqual({ source : 'import', type : 1, amount : '6.05', payeeName : "LEE'S DELI - 615 M SAN FRANCISCO CA", date : moment('07/06/2012').valueOf() })
      expect(result[1]).toEqual({ source : 'import', type : 1, amount : '41.54', payeeName : "TRADER JOE'S #236 QPS SAN FRANCISCO CA", date : moment('07/08/2012').valueOf() })
      expect(result[2]).toEqual({ source : 'import', type : 1, amount : '1', payeeName : 'Interest Charge on Purchases', date : moment('08/07/2012').valueOf() })
      expect(result[3]).toEqual({ source : 'import', type : 1, amount : '0', payeeName : 'Interest Charge on Cash Advan', date : moment('08/07/2012').valueOf() })
      content = window.fixtures.csv.provident_visa_new
      result = root.importer.import(content)
      expect(result.length).toEqual(2)
      expect(result[0]).toEqual({ source : 'import', type : 2, amount : '80.69', payeeName : 'AUTOMATIC PAYMENT - THANK YOU', date : moment('05/27/13').valueOf() })
      expect(result[1]).toEqual({ source : 'import', type : 1, amount : '40', payeeName : 'RECREATION.GOV 888-448-1474 NY', date : moment('06/05/13').valueOf() })
  describe 'ImportChaseCC', ->
    beforeEach(inject((ImportChaseCC) ->
      root.importer = ImportChaseCC
    ))
    it 'should import the csv', ->
      content = window.fixtures.csv.chase_cc
      result = root.importer.import(content)
      expect(result.length).toEqual(2)
      expect(result[0]).toEqual({ source : 'import', type : 1, amount : '1.5', payeeName : 'IMPARK00740010A', date : moment('10/17/2013').valueOf() })
      expect(result[1]).toEqual({ source : 'import', type : 1, amount : '26.5', payeeName : 'FANDANGO.COM', date : moment('10/17/2013').valueOf() })
    
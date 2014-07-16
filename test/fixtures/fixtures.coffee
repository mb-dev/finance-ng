window.fixtures = {}
window.fixtures.csv = {}
window.fixtures.csv.chase_cc = """
Type,Trans Date,Post Date,Description,Amount
Sale,10/17/2013,10/18/2013,"IMPARK00740010A",-1.50
Sale,10/17/2013,10/18/2013,"FANDANGO.COM",-26.50
"""

window.fixtures.csv.provident_checking = """
"Date","Description","Comments","Check Number","Amount","Balance"
"07/02/2012","BACI CAFE & WINE B HEALDSBURG CAUS","","","($52.00)","$6,779.22"
"07/03/2012","CHECK # 1015","","1015","($1,350.00)","$3,611.79"
"10/09/2013","TARGET T2767 OAKLA OAKLAND CAUS","","","($14.16)","$1,540.41"
"12/03/2013","CHECK # 1135","","1135","($130.00)","$15,823.35"
"12/03/2013","CHECK # 1135","","1135","($160.00)","$15,823.35"
"""

window.fixtures.csv.provident_visa = """
Trans Date,Post Date,Reference Number,Description,Amount
"07/06/2012","07/08/2012","2422443JD2YZWFQHY","LEE'S DELI - 615 M SAN FRANCISCO CA",$ 6.05
"07/08/2012","07/09/2012","2449398JF5HWDBJF1","TRADER JOE'S #236  QPS SAN FRANCISCO CA",$ 41.54
"08/07/2012","08/07/2012",,"Interest Charge on Purchases",$ 1.00
"08/07/2012","08/07/2012",,"Interest Charge on Cash Advan",$ 0.00
"""

window.fixtures.csv.provident_visa_new = """
TRANSACTION DATE,POST DATE,DESCRIPTION,REFERENCE,AMOUNT
05/27/13,05/27/13, AUTOMATIC PAYMENT - THANK YOU                      , F3462004K00CHGDDA,-0000000000080.69
06/05/13,06/06/13, RECREATION.GOV           888-448-1474 NY           , 24445004XHF0JE64Y,00000000000040.00
"""

window.fixtures.models = {}
window.fixtures.models.lineItems = {}
window.fixtures.models.lineItems.getLineItem = (specific_properties, more_opts = {}) ->
  transactionDate = moment([2014, 0, 1]).valueOf()
  base_object = {
    type: LineItemCollection.EXPENSE,
    accountId: 1, 
    amount: '100', 
    balance: '0', 
    payeeName: 'Valero',
    categoryName: 'Transportation:Gas', 
    date: transactionDate, 
    originalDate: transactionDate, 
    tags: []
  }
  base_object.tags += ['Cash'] if more_opts.cash
  angular.extend(base_object, specific_properties)

console.log('fixtures loaded')
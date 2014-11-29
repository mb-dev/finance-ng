angular.module('app.importers')
  .factory 'ImportProvidentChecking', () ->
    import: (fileContent) ->
      rows = CSV.parse(fileContent)
      rows.splice(0, 1)
      _(rows).map((row) =>
        date = row[0]
        description = row[1]
        comments = row[2]
        checkNumber = row[3]
        amount = row[4]
        balance = row[5]

        if description.indexOf('(Pending)') < 0
          amountAsFloat = parseFloat(amount.match(/[0-9.\-]+/g).join(''))

          lineItem = {}
          lineItem.source = LineItemCollection.SOURCE_IMPORT
          lineItem.type = if amount[0] == '(' then LineItemCollection.EXPENSE else LineItemCollection.INCOME
          lineItem.amount = Math.abs(amountAsFloat).toString()
          lineItem.comment = "Check #{checkNumber}" if checkNumber
          lineItem.payeeName = description.trim() if !checkNumber
          lineItem.date = moment(date).valueOf()
          lineItem
      ).compact().valueOf()

  .factory 'ImportProvidentVisa', () ->
    import: (fileContent) ->
      rows = CSV.parse(fileContent)
      rows.splice(0, 1)
      rows.map (row) =>
        date = row[0].trim()
        comments = row[2].trim()
        if date.length == 8
          description = row[2].trim().replace(new RegExp("[ ]+", "g"), ' ')
          referenceNumber = row[3].trim()
        else
          description = row[3].trim().replace(new RegExp("[ ]+", "g"), ' ')
          referenceNumber = row[2].trim()
        amount = row[4].toString().trim()

        amountAsFloat = parseFloat(amount.match(/[0-9.\-]+/g).join(''))

        if amount != NaN
          lineItem = {}
          lineItem.source = LineItemCollection.SOURCE_IMPORT
          lineItem.type = if amountAsFloat >= 0 then LineItemCollection.EXPENSE else LineItemCollection.INCOME
          lineItem.amount = Math.abs(amountAsFloat).toString()
          lineItem.payeeName = description.trim()
          lineItem.date = moment(date).valueOf()
          lineItem

  .factory 'ImportChaseCC', () ->
    import: (fileContent) ->
      rows = CSV.parse(fileContent)
      rows.splice(0, 1)
      rows.map (row) =>
        type = row[0]
        date = row[1]
        description = row[3]
        amount = row[4]

        amountAsFloat = parseFloat(amount.toString().match(/[0-9.\-]+/g).join(''))

        lineItem = {}
        lineItem.source = LineItemCollection.SOURCE_IMPORT
        lineItem.type = if amountAsFloat < 0 then LineItemCollection.EXPENSE else LineItemCollection.INCOME
        lineItem.amount = Math.abs(amountAsFloat).toString()
        lineItem.payeeName = description.toString().trim()
        lineItem.date = moment(date).valueOf()
        lineItem
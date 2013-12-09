class BudgetReportView
  constructor: (db, year) ->
    @db = db
    @year = year

    @budgetItems = db.budgetItems().getItemsByYear('budget_year', @year, Collection.doNotConvertFunc).toArray()
    @plannedItems = db.plannedItems().getItemsByYear('event_date_start', @year).toArray()
    @lineItems = db.lineItems().getItemsByYear('event_date', @year).toArray()

    @totals = {}

    @groupedItems = {}
    Lazy(@lineItems).each (lineItem) =>
      if lineItem.grouped_label
        item = @groupedItems[lineItem.grouped_label] ?= {amount: 0, month: 12, label: lineItem.grouped_label}
        item['amount'] += lineItem.$signedAmount()
        item['month'] = Lazy([item['month'], lineItem.$eventDate().month]).min
    
    @groupedItems = Lazy(@groupedItems).values().sortBy((item) -> item['month']).toArray()

    categoryToBudget = {}
    Lazy(@budgetItems).each (budgetItem) ->
      Lazy(budgetItem.categories).each (categoryName) ->
        categoryToBudget[categoryName] = budgetItem

    # prepare expense box
    @expenseBox = new Box()
    Lazy(@budgetItems).each (budgetItem) =>
      @expenseBox.addRow(budgetItem.name)
    
    @expenseBox.setColumns([0..11], ['expense', 'future_expense', 'planned_expense'])
    # prepare income box
    @incomeBox = new Box()
    @incomeBox.addRow('income')
    @incomeBox.setColumns([0..11], ['amount', 'future_income'])
    # add expenses/income
    Lazy(@lineItems).each (lineItem) =>
      if db.user().config.incomeCategories.indexOf(lineItem.category_name) >= 0
        @incomeBox.addToValue('income', lineItem.$eventDate().month(), 'amount', lineItem.$signedAmount())
      else if categoryToBudget[lineItem.category_name]
        @expenseBox.addToValue(categoryToBudget[lineItem.category_name].name, lineItem.$eventDate().month(), 'expense', lineItem.$signedAmount())      

    # add future expenses
    if @year == moment().year()
      currentMonth = moment().month()
      Lazy(@budgetItems).each (budgetItem) =>
        ([(currentMonth)..11]).each (futureMonth) =>
          @expenseBox.addToValue(budgetItem.name, futureMonth, 'future_expense', budgetItem.estimated_min_monthly_amount)
        
      # add planned items
      Lazy(@plannedItems).each (plannedItem) =>
        Lazy([plannedItem.$eventDateStart.month()..plannedItem.$eventDateEnd()]).each (month) ->
          if month > currentMonth
            if planned_item.$isIncome()
              @incomeBox.addToValue('income', month, 'future_income', plannedItem.amount)
            else
              @expenseBox.addToValue(categoryToBudget[plannedItem.category_name].name, month, 'planned_expense', plannedItem.amount)

  isInFuture: (month) =>
    month > moment().month() && @year == moment().year()
  
  totalIncome: =>
    @incomeBox.rowTotals('income').amount.plus(@incomeBox.rowTotals('income').future_income)

  totalExpensesForBudgetItemInYear: (budgetItem) ->
    @expenseBox.rowTotals(budgetItem.name).expense.abs().plus(@expenseBox.rowTotals(budgetItem.name).future_expense.plus(@expenseBox.rowTotals(budgetItem.name).planned_expense))
  
  percentExpense: (budgetItem) ->
    return 'N/A' if @totalIncome().equals(0)
    ((@totalExpensesForBudgetItemInYear(budgetItem).div(@totalIncome())).times(100)).toFixed(0) + '%'
  

  
  generateReport: =>
    incomeRow = []
    Lazy(@incomeBox.rowColumnValues('income')).each (column) =>
      month = column.column
      if @isInFuture(month)
        incomeRow.push {type: 'future', amount: column.values.future_income.toFixed(2)}
      else
        incomeRow.push {type: 'current', amount: column.values.amount.toFixed(2) }

    expenseRowsForBudgetItem = []
    Lazy(@budgetItems).each (budgetItem) =>
      expenseRow = {columns: []}
      expenseRow.meta = {
        name: budgetItem.name 
        limit: budgetItem.limit
        now: 0
        total: budgetItem.limit*12
        expenses: @totalExpensesForBudgetItemInYear(budgetItem).toFixed(2) 
        percent: @percentExpense(budgetItem)
      }
      amountAvailable = 0
      amountUsed = BigNumber(0)
      Lazy(@expenseBox.rowColumnValues(budgetItem.name)).each (expenseColumn) =>
        month = expenseColumn.column
        if expenseColumn.values.expense != 0
          amount = expenseColumn.values.expense.abs()
          expenseRow.columns.push {type: 'current', amount: amount.toFixed(2)}
          amountAvailable += budgetItem.limit
          amountUsed = amountUsed.plus(amount)
        else if expenseColumn.values.planned_expense > 0
          expenseRow.columns.push {type: 'planned', amount: expenseColumn.values.planned_expense.toFixed(2)}
        else if expenseColumn.values.future_expense > 0
          expenseRow.columns.push {type: 'future', amount: expenseColumn.values.future_expense.toFixed(2)}
        else
          expenseRow.columns.push {type: 'other', amount: '0.0'}
      
      expenseRow.meta.now = BigNumber(amountAvailable).minus(amountUsed).toFixed(2)

      expenseRowsForBudgetItem.push expenseRow

    totalLimit = Lazy(@budgetItems).pluck('limit').sum()
    {incomeMeta: {totalIncome: @totalIncome().toFixed(2)}, incomeRow: incomeRow, expenseRows: expenseRowsForBudgetItem, totalBudgeted: totalLimit}

#   def budget_year_range
#     (BudgetItem.min(:budget_year).to_i)..(BudgetItem.max(:budget_year).to_i)
#   end

#   def budget_items
#     @budget_items
#   end

#   def grouped_item_label(grouped_item)
#     item = grouped_item
#     "#{grouped_item[:label]} (#{Date.new(@active_year, item[:month]).strftime('%B')}): Total: #{item[:amount]*-1}"
#   end



#   def future_amount(budget_item)
#     @totals[budget_item.name] ||= 0
#     @totals[budget_item.name] -= budget_item.estimated_min_monthly_amount

#     budget_item.estimated_min_monthly_amount
#   end

#   def future_income(month)
#     found_income = current_user.planned_items.where(:event_date_begin.gt => Date.new(@active_year, month, 1), :event_date_end.lt => Date.new(@active_year, month, 1).end_of_month ).first
#     income_for_month = found_income ? found_income.amount : 0
#     @totals['Income'] ||= 0
#     @totals['Income'] += income_for_month
#     income_for_month
#   end

#   def planned_amount(budget_item, month)

#   end

#   def total_expenses_for_budget_item_in_month(budget_item, month)
#     #noinspection RubyArgCount
#     current_date = Date.new(@active_year, month, 1)
#     amount = LineItem.inline_sum_with_filters(@current_user, @line_items, {
#                                               :categories => budget_item.categories,
#                                               :in_month_of_date => current_date
#                                               }, LineItemReportProcess.new)

#     @totals[budget_item.name] ||= 0
#     @totals[budget_item.name] += amount
#     amount * -1
#   end

#   def total_expenses_for_budget_item_in_year(budget_item)
#     @expenseBox.row_totals(budget_item)[:expense]*-1 +
#             @expenseBox.row_totals(budget_item)[:future_expense] +
#             @expenseBox.row_totals(budget_item)[:planned_expense]
#   end

#   def amount_left_budget_item_in_year(budget_item)
#     budget_item.limit.to_i.to_f * 12 - total_expenses_for_budget_item_in_year(budget_item)

#   end

#   def total_limit
#     @budget_items.collect(&:limit).compact.sum
#   end

#   def income_at(month)
#     income_for_month = @line_items.select { |li| li.event_date.month == month and LineItem::INCOME_CATEGORIES.include? li.category_name }.sum(&:signed_amount)
#     @totals['Income'] ||= 0
#     @totals['Income'] += income_for_month
#     income_for_month
#   end



#   def percent_expense(budget_item)
#     ((total_expenses_for_budget_item_in_year(budget_item).to_f / total_income.to_f) * 100).to_i.to_s + '%'
#   end

#   def amount_available_now(budget_item)
#     return 'N/A' if Time.now.year != @active_year
#     expenses_so_far = 0
#     (1..Time.now.month).each do |month|
#       expenses_so_far += expenseBox.row_column_values(budget_item)[month - 1][1][:expense]
#     end
#     (budget_item.limit * Time.now.month) - (expenses_so_far*-1)
#   end
# # end
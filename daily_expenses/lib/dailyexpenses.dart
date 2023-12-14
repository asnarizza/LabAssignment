import 'package:flutter/material.dart';
import 'package:daily_expenses/Controller/request_controller.dart';
import 'Model/expense.dart';

class DailyExpensesApp extends StatelessWidget {
  final String username;
  const DailyExpensesApp({required this.username});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ExpenseList(username: username),
    );
  }
}

class ExpenseList extends StatefulWidget {
  final String username;
  ExpenseList({required this.username});

  @override
  _ExpenseListState createState() => _ExpenseListState();
}

class _ExpenseListState extends State<ExpenseList> {
  final List<Expense> expenses = [];
  final TextEditingController descController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController totalAmountController = TextEditingController();
  final TextEditingController txtDateController = TextEditingController(); // new

  double totalAmount = 0;
  // added new parameter for Expense Contructor - DateTime text
  void _addExpense() async {
    String description = descController.text.trim();
    String amount = amountController.text.trim();
    int id = 0;

    if (amount.isNotEmpty && description.isNotEmpty) {
      Expense exp =
      Expense(0, double.parse(amount), description, txtDateController.text);
      if (await exp.save()) {
        setState(() {
          expenses.add(exp);
          descController.clear();
          amountController.clear();
          calculateTotal();
        });
      }
      else {
        _showMessage("Failed to save Expenses data");
      }
    }
  }
  void calculateTotal() {
    totalAmount = 0;
    for (Expense ex in expenses) {
      totalAmount += ex.amount;
    }
    totalAmountController.text = totalAmount.toString();
  }

  void _removeExpense(int index) {
    totalAmount -= expenses[index].amount;
    setState(() {
      expenses.removeAt(index);
      totalAmountController.text = totalAmount.toString();
    });
  }
  // function to display message at bottom od scaffold
  void _showMessage(String msg) {
    if(mounted) {
      // make sure this context is still mounted/exist
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
        ),
      );
    }
  }
  // Navigate to Edit Screen when long press on the itemList
  // edited
  void _editExpense(int index) async {
    final Expense originalExpense = expenses[index];

    // Navigate to Edit Screen and wait for the result
    final editedExpense = await Navigator.push<Expense>(
      context,
      MaterialPageRoute(
        builder: (context) => EditExpenseScreen(
          expense: originalExpense,
          onSave: (editedExpense) {
            setState(() {
              totalAmount += editedExpense.amount - originalExpense.amount;
              expenses[index] = editedExpense;
              totalAmountController.text = totalAmount.toString();
            });
          },
        ),
      ),
    );

    // Check if the user saved the changes
    if (editedExpense != null) {
      // Update the date and time in the original expense
      expenses[index].dateTime = editedExpense.dateTime;
      // Save the updated expense to the database
      await originalExpense.update();
    }
  }
  // new fn - Date and Time picker on textfield
  _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedDate != null && pickedTime != null) {
      setState(() {
        txtDateController.text =
        "${pickedDate.year}-${pickedDate.month}-${pickedDate.day} "
            " ${pickedTime.hour}:${pickedTime.minute}:00";
      });
    }
  }
  // new
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      _showMessage("Welcome");// ${widget.username}");

      RequestController req = RequestController(
          path: "/api/timezone/Asia/Kuala_Lumpur",
          server: "http://worldtimeapi.org");
      req.get().then((value) {
        dynamic res = req.result();
        txtDateController.text =
            res["dateTime"].toString().substring(0,19).replaceAll('T', ' ');
      });
      expenses.addAll(await Expense.loadAll());

      setState(() {
        calculateTotal();
      });
    });
  }

  Future<String> _getCurrentDateTime() async {
    RequestController req = RequestController(
        path: "/api/timezone/Asia/Kuala_Lumpur",
        server: "http://worldtimeapi.org");
    await req.get();
    dynamic res = req.result();
    return res["datetime"].toString().substring(0, 19).replaceAll('T', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Daily Expenses'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: 'Description',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'Amount (RM)',
              ),
            ),
          ),
          Padding(
            // new textfield for the date and time
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              keyboardType: TextInputType.datetime,
              controller: txtDateController,
              readOnly: true,
              onTap: _selectDate,
              decoration: const InputDecoration(labelText: 'Date'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: totalAmountController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Total Spend(RM)',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _addExpense,
            child: Text('Add Expense'),
          ),
          Container(
            child: _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return Expanded(
      child: ListView.builder(
        itemCount: expenses.length,
        itemBuilder: (context, index) {
          return Dismissible(
            key: Key(expenses[index].dateTime),
            background: Container(
              color: Colors.red,
              child: Center(
                child: Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            onDismissed: (direction) {
              _removeExpense(index);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Item dismissed')),
              );
              setState(() {
                _removeExpense(index);
              });
            },
            child: Card(
              margin: EdgeInsets.all(8.0),
              child: ListTile(
                title: Text(expenses[index].desc),
                subtitle: Row(
                  children: [
                    Text('Amount: ${expenses[index].amount}'),
                    const Spacer(),
                    Text('Date: ${expenses[index].dateTime}'),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () async{
                    // Delete expense on press
                    final success = await expenses[index].delete();
                    if (success) {
                      // Update UI
                      _removeExpense(index);
                      setState(() {
                        expenses.removeAt(index);
                      });
                    }
                  },
                ),
                onLongPress: () {
                  _editExpense(index);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class EditExpenseScreen extends StatelessWidget {
  final Expense expense;
  final Function(Expense) onSave;

  EditExpenseScreen({required this.expense, required this.onSave});

  final TextEditingController descController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController txtDateController = TextEditingController();
  final TextEditingController idController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    descController.text = expense.desc;
    amountController.text = expense.amount.toString();
    txtDateController.text = expense.dateTime;
    idController.text = expense.id.toString();

    return Scaffold(
        appBar: AppBar(
          title: Text('Edit Expense'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'Description',
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: 'Amount (RM)',
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                keyboardType: TextInputType.datetime,
                controller: txtDateController,
                readOnly: true,
                onTap: () => _selectDate(context),
                decoration: const InputDecoration(labelText: 'Date and Time'),
              ),
            ),

            ElevatedButton(
                onPressed:() async{
                  // Save the edited expense details
                  expense.id = expense.id;
                  expense.desc = descController.text;
                  expense.amount = double.parse(amountController.text);
                  expense.dateTime = txtDateController.text;

                  // Update expense in database and server
                  final isUpdated = await expense.update();
                  print(isUpdated);

                  // If update is successful, notify and navigate back
                  if (isUpdated) {
                    onSave(Expense(0, double.parse(amountController.text),
                        descController.text, txtDateController.text));
                    Navigator.pop(context);
                  } else {
                    print("failure");
                  }
                },
                child: Text("Save")
            ),
          ],
        )
    );
  }
  // New method for date and time picker
  _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedDate != null && pickedTime != null) {
      txtDateController.text =
      "${pickedDate.year}-${pickedDate.month}-${pickedDate.day} "
          "${pickedTime.hour}:${pickedTime.minute}:00";
    }
  }
}
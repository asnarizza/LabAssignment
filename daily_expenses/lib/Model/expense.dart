import 'package:shared_preferences/shared_preferences.dart';

import '../Controller/request_controller.dart';
import '../Controller/sqlite_db.dart';

class Expense {
  static const String SQLiteTable = "expenses";
  int? id;
  String desc;
  double amount;
  String dateTime;
  Expense(this.id, this.amount, this.desc, this.dateTime);

  Expense.fromJson(Map<String, dynamic> json)
      :   id = json['id'] as int,
        amount = double.parse(json['amount'] as dynamic),
        desc = json['desc'] as String,
        dateTime = json['dateTime'] as String;

  // toJson will be automatically called by jsonEncode when necessary
  Map<String, dynamic> toJson() =>
      {'amount': amount, 'desc': desc, 'dateTime': dateTime.toString()};

  Map<String, dynamic> toUpdateJson() =>
      {'id': id, 'amount': amount, 'desc': desc, 'dateTime': dateTime.toString()};

  Map<String, dynamic> todeleteJson() =>
      {'id': id };

  Future<bool> update() async {
    if (id == null) {
      throw Exception("Cannot update expense with null ID");
    }

    // Update expense in local database
    final rowsUpdated = await SQLiteDB().update(
      SQLiteTable, 'id', toUpdateJson(),
    );

    // Update expense on server
    final prefs = await SharedPreferences.getInstance();
    String? server = prefs.getString('ip');
    RequestController req = RequestController(path: "/api/expenses.php", server:"http://$server" );
    req.setBody(toUpdateJson());
    await req.put();

    return req.status() == 200;
  }

  Future<bool> save() async {

    //Save to local SQLite
    await SQLiteDB().insert(SQLiteTable, toJson());

    final prefs = await SharedPreferences.getInstance();
    String? server = prefs.getString('ip');
    RequestController req = RequestController(path: "/api/expenses.php", server:"http://$server" );
    req.setBody(toJson());

    try{
      await req.post();
      print(req.status());
      if (req.status() == 200){
        return true;
      }
      else{
        if(await SQLiteDB().insert(SQLiteTable, toJson())!=0){
          return true;
        }
        else{
          return false;
        }
      }
    } catch (e) {
      print("Exception during HTTP request: $e");
    }
    return false;
  }

  Future<bool> delete() async {
    if (id == null) {
      throw Exception("Cannot delete expense with null ID");
    }

    // Delete expense from local database
    final rowsDeleted = await SQLiteDB().delete(
      SQLiteTable, 'id', id,
    );

    // Delete expense on server
    final prefs = await SharedPreferences.getInstance();
    String? server = prefs.getString('ip');
    RequestController req = RequestController(path: "/api/expenses.php", server:"http://$server" );
    req.setBody(todeleteJson());
    await req.delete();

    return req.status() == 200;
  }

  static Future<List<Expense>> loadAll() async{
    List<Expense> result = [];
    final prefs = await SharedPreferences.getInstance();
    String? server = prefs.getString('ip');
    RequestController req = RequestController(path: "/api/expenses.php", server:"http://$server" );
    await req.get();

    if(req.status() == 200 && req.result() != null){
      for (var item in req.result()){
        result.add(Expense.fromJson(item));
      }
    }
    else{
      // else it will load from local storage
      List<Map<String, dynamic>> result = await SQLiteDB().queryAll(SQLiteTable);
      List<Expense> expenses = [];
      for (var item in result){
        result.add(Expense.fromJson(item) as Map<String, dynamic>);
      }
    }
    return result;
  }
}
import 'package:csv/csv.dart';
void main() {
  final text = 'Date,Type,Route,notes,Set 1,Set 2,Set 3,Set 4,Set 5,Set 6,Set 7\n'
      '1/6/26,endurance ,yellow,,28,21,,,,,\n'
      '1/12/26,endurance ,yellow,crap technique. kept falling from stupid mistakes ,32,21,24,21,,,';
  final data = const CsvToListConverter(eol: '\n').convert(text);
  print('rows: \\${data.length}');
  for (var row in data) {
    print(row);
    print('len=' + row.length.toString());
  }
}

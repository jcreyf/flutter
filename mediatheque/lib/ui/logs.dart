
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppLogging {
  List<String> _logLines = [];

  addLine(String line) {
    _logLines.add(line);
    print("JC: $line");
  }

  clear() {
    _logLines.clear();
  }

  printAll() {
    for(String line in _logLines) {
      print("Log: $line");
    }
  }

  Widget widget() {
    return RefreshIndicator(
      onRefresh: () async {
        // The page got pulled down.  We need to refresh the log list:
        addLine("refresh logs");
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        scrollDirection: Axis.vertical,
        itemCount: _logLines.length,
        itemBuilder: (BuildContext context, int index) {
          String line = _logLines[index];
          return Text("> $line",
                      style: TextStyle(
                        fontSize: 12,
                        backgroundColor: ( index % 2 == 0 ) ? Colors.grey[200] : Colors.grey[400],
                      ),
                 );
          },
      )
    );
  }
}
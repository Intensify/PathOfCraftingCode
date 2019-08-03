import 'package:flutter/material.dart';

Widget imageButton(String assetPath, VoidCallback callback) {

  return Expanded(
    flex: 1,
    child: InkWell(
      onTap: callback,
      child: Container(
        decoration: new BoxDecoration(
          border: Border.all(color: Color(0xFF2A221A), width: 1),
          /*image: DecorationImage(
              image: AssetImage(assetPath),
              fit: BoxFit.fill
          ),*/
        ),
        child: Image(image: AssetImage(assetPath), ),
      ),
    ),
  );
}

Widget emptySquare() {
  return Expanded(
    flex: 1,
    child: Container(
        decoration: new BoxDecoration(
          border: Border.all(color: Color(0xFF2A221A), width: 1),
          color: Colors.black
        ),
        child: Image(image: AssetImage('assets/images/empty.png'), ),

    ),
  );
}
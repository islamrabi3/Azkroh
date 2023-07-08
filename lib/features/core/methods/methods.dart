import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

navigateTo(context, Widget widget) {
  Navigator.push(context, MaterialPageRoute(builder: (context) => widget));
}

import 'package:flutter/material.dart';

class MiniNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> key;
  final Widget child;

  MiniNavigator({@required this.key, @required this.child});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (key.currentState.canPop()) {
          key.currentState.pop();
          return false;
        }
        return true;
      },
      child: Navigator(
        key: key,
        onGenerateRoute: (RouteSettings settings) {
          return MaterialPageRoute(builder: (context) {
            return child;
          });
        },
      )
    );
  }
}
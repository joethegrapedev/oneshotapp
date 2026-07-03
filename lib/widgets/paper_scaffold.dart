import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A minimal-chrome scaffold on a warm paper background. Optional title and
/// leading/actions, generous padding, no elevation — the writing surface should
/// feel like paper.
class PaperScaffold extends StatelessWidget {
  const PaperScaffold({
    super.key,
    required this.child,
    this.title,
    this.leading,
    this.actions,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.floatingActionButton,
    this.showAppBar = true,
    this.scroll = false,
  });

  final Widget child;
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final EdgeInsets padding;
  final Widget? floatingActionButton;
  final bool showAppBar;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: showAppBar
          ? AppBar(
              title: title == null
                  ? null
                  : Text(
                      title!,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
              leading: leading,
              actions: actions,
            )
          : null,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: scroll ? SingleChildScrollView(child: body) : body,
      ),
    );
  }
}

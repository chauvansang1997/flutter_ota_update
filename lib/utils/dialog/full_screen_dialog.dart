import 'package:flutter/material.dart';

class DialogScaffold extends StatelessWidget {
  const DialogScaffold({
    Key? key,
    this.header,
    this.content,
    this.footer,
    this.backgroundColor,
    this.borderRadius,
    this.contentBoxDecoration,
    this.dialogOuterPadding = const EdgeInsets.all(20.0),
    this.dialogInnerPadding = const EdgeInsets.all(20.0),
    this.headerPadding = const EdgeInsets.all(0.0),
    this.contentPadding = const EdgeInsets.only(top: 10.0, bottom: 10.0),
    this.footerPadding = const EdgeInsets.only(top: 10.0, bottom: 10.0),
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.dialogSizeConstraints = const BoxConstraints(),
  }) : super(key: key);

  final Widget? header;
  final Widget? content;
  final Widget? footer;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final BoxDecoration? contentBoxDecoration;
  final EdgeInsets dialogOuterPadding;
  final EdgeInsets dialogInnerPadding;
  final EdgeInsets headerPadding;
  final EdgeInsets contentPadding;
  final EdgeInsets footerPadding;
  final CrossAxisAlignment crossAxisAlignment;
  final BoxConstraints dialogSizeConstraints;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: dialogOuterPadding,
          child: ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: dialogSizeConstraints,
              child: Container(
                color: backgroundColor,
                decoration: contentBoxDecoration,
                child: Padding(
                  padding: dialogInnerPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: crossAxisAlignment,
                    children: [
                      Padding(
                        padding: headerPadding,
                        child: header,
                      ),
                      Padding(
                        padding: contentPadding,
                        child: content,
                      ),
                      Padding(
                        padding: footerPadding,
                        child: footer,
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FullScreenDialogScaffold extends StatelessWidget {
  const FullScreenDialogScaffold({
    Key? key,
    this.header,
    this.content,
    this.footer,
    this.backgroundColor,
    this.borderRadius,
    this.contentBoxDecoration,
    this.dialogOuterPadding = const EdgeInsets.all(20.0),
    this.dialogInnerPadding = const EdgeInsets.all(20.0),
    this.headerPadding = const EdgeInsets.all(0.0),
    this.contentPadding = const EdgeInsets.only(top: 10.0, bottom: 10.0),
    this.footerPadding = const EdgeInsets.only(top: 10.0),
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.dialogSizeConstraints = const BoxConstraints(),
  }) : super(key: key);

  final Widget? header;
  final Widget? content;
  final Widget? footer;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final BoxDecoration? contentBoxDecoration;
  final EdgeInsets dialogOuterPadding;
  final EdgeInsets dialogInnerPadding;
  final EdgeInsets headerPadding;
  final EdgeInsets contentPadding;
  final EdgeInsets footerPadding;
  final CrossAxisAlignment crossAxisAlignment;
  final BoxConstraints dialogSizeConstraints;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: dialogOuterPadding,
          child: ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: dialogSizeConstraints,
              child: Container(
                color: backgroundColor,
                decoration: contentBoxDecoration,
                child: Padding(
                  padding: dialogInnerPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: crossAxisAlignment,
                    children: [
                      Padding(
                        padding: headerPadding,
                        child: header,
                      ),
                      Expanded(
                        child: Padding(
                          padding: contentPadding,
                          child: content,
                        ),
                      ),
                      Padding(
                        padding: footerPadding,
                        child: footer,
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

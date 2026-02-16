// Copyright 2024 MongoDB, Inc.
// SPDX-License-Identifier: Apache-2.0

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

// Used to represent a type that is not yet defined, such as the mapped type of a realm model (ie. A for _A)
// Hopefully we can get rid of this when static meta programming lands
class PseudoType implements DartType {
  @override
  final NullabilitySuffix nullabilitySuffix;
  final String _name;

  PseudoType(this._name, {this.nullabilitySuffix = NullabilitySuffix.none});

  @override
  String getDisplayString({bool withNullability = true}) {
    if (withNullability && nullabilitySuffix == NullabilitySuffix.question) {
      return '$_name?';
    }
    return _name;
  }

  PseudoType withNullability(NullabilitySuffix nullabilitySuffix) {
    return PseudoType(_name, nullabilitySuffix: nullabilitySuffix);
  }

  @override
  Element? get element => null;

  @override
  bool get isDartCoreSet => false;

  @override
  bool get isDartCoreList => false;

  @override
  bool get isDartCoreMap => false;

  @override
  bool get isDartCoreIterable => false;

  @override
  bool get isDartCoreInt => false;

  @override
  bool get isDartCoreBool => false;

  @override
  bool get isDartCoreString => false;

  @override
  bool get isDartCoreNum => false;

  @override
  bool get isDartCoreDouble => false;

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

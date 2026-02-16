// Copyright 2021 MongoDB, Inc.
// SPDX-License-Identifier: Apache-2.0

import 'package:source_gen/source_gen.dart';

const ignoredChecker = TypeChecker.fromUrl('package:realm_common/src/realm_common_base.dart#Ignored');

const indexedChecker = TypeChecker.fromUrl('package:realm_common/src/realm_common_base.dart#Indexed');

const mapToChecker = TypeChecker.fromUrl('package:realm_common/src/realm_common_base.dart#MapTo');

const primaryKeyChecker = TypeChecker.fromUrl('package:realm_common/src/realm_common_base.dart#PrimaryKey');

const backlinkChecker = TypeChecker.fromUrl('package:realm_common/src/realm_common_base.dart#Backlink');

const realmAnnotationChecker = TypeChecker.any([
  ignoredChecker,
  indexedChecker,
  mapToChecker,
  primaryKeyChecker,
]);

const realmModelChecker = TypeChecker.fromUrl('package:realm_common/src/realm_common_base.dart#RealmModel');

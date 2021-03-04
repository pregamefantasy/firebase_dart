import 'dart:async';
import 'dart:isolate';

import 'package:async/async.dart';
import 'package:firebase_dart/core.dart';
import 'package:firebase_dart/src/database/impl/connections/protocol.dart';
import 'package:firebase_dart/src/database/impl/repo.dart';
import 'package:firebase_dart/src/database/impl/treestructureddata.dart';
import 'package:rxdart/rxdart.dart';

import '../../../database.dart';
import '../isolate.dart';
import 'util.dart';

class IsolateFirebaseDatabase extends IsolateFirebaseService
    implements FirebaseDatabase {
  final PushIdGenerator pushIds = PushIdGenerator();

  @override
  final String databaseURL;

  IsolateFirebaseDatabase({IsolateFirebaseApp app, this.databaseURL})
      : super(app);

  Future<T> invoke<T>(Symbol method,
      [List<dynamic> positionalArguments,
      Map<Symbol, dynamic> namedArguments]) {
    return app.commander.execute(DatabaseFunctionCall<FutureOr<T>>(
        method, app.name, databaseURL, positionalArguments, namedArguments));
  }

  DateTime get serverTime => throw UnimplementedError();

  @override
  Future<void> goOffline() async {
    await invoke(#goOffline, []);
  }

  @override
  Future<void> goOnline() async {
    await invoke(#goOnline, []);
  }

  @override
  Future<void> purgeOutstandingWrites() async {
    await invoke(#purgeOutstandingWrites, []);
  }

  @override
  DatabaseReference reference() {
    return IsolateDatabaseReference(this, []);
  }

  @override
  void setPersistenceCacheSizeBytes(int cacheSizeInBytes) async {
    await invoke(#setPersistenceCacheSizeBytes, [cacheSizeInBytes]);
  }

  @override
  Future<bool> setPersistenceEnabled(bool enabled) async {
    return await invoke(#setPersistenceEnabled, [enabled]);
  }
}

class DatabaseFunctionCall<T> extends BaseFunctionCall<T> {
  final String appName;
  final String databaseURL;
  final Symbol functionName;

  DatabaseFunctionCall(this.functionName, this.appName, this.databaseURL,
      [List<dynamic> positionalArguments, Map<Symbol, dynamic> namedArguments])
      : super(positionalArguments, namedArguments);

  FirebaseDatabase get database =>
      FirebaseDatabase(app: Firebase.app(appName), databaseURL: databaseURL);

  @override
  Function get function {
    switch (functionName) {
      case #goOffline:
        return database.goOffline;
      case #goOnline:
        return database.goOnline;
      case #purgeOutstandingWrites:
        return database.purgeOutstandingWrites;
      case #setPersistenceCacheSizeBytes:
        return database.setPersistenceCacheSizeBytes;
      case #setPersistenceEnabled:
        return database.setPersistenceEnabled;
    }
    return null;
  }
}

class QueryFunctionCall<T> extends BaseFunctionCall<T> {
  final String appName;
  final String databaseURL;
  final String path;
  final QueryFilter filter;
  final Symbol functionName;

  QueryFunctionCall(
      this.functionName, this.appName, this.databaseURL, this.path, this.filter,
      [List<dynamic> positionalArguments, Map<Symbol, dynamic> namedArguments])
      : super(positionalArguments, namedArguments);

  FirebaseDatabase get database =>
      FirebaseDatabase(app: Firebase.app(appName), databaseURL: databaseURL);

  DatabaseReference getRef() {
    return database.reference().child(path);
  }

  Query getQuery() {
    Query query = getRef();
    switch (filter.orderBy) {
      case '.key':
        query = query.orderByKey();
        break;
      case '.priority':
        query = query.orderByPriority();
        break;
      case '.value':
        query = query.orderByValue();
        break;
      default:
        query = query.orderByChild(filter.orderBy);
        break;
    }
    if (filter.startKey != null || filter.startValue != null) {
      if (filter.orderBy == '.key') {
        query = query.startAt(filter.startKey.asString());
      } else {
        query = query.startAt(
            filter.startValue.toJson(), filter.startKey.asString());
      }
    }
    if (filter.endKey != null || filter.endValue != null) {
      if (filter.orderBy == '.key') {
        query = query.endAt(filter.endKey.asString());
      } else {
        query = query.endAt(filter.endValue.toJson(), filter.endKey.asString());
      }
    }
    if (filter.limit != null) {
      if (filter.reversed) {
        query = query.limitToLast(filter.limit);
      } else {
        query = query.limitToFirst(filter.limit);
      }
    }
    return query;
  }

  @override
  Function get function {
    switch (functionName) {
      case #keepSynced:
        return getQuery().keepSynced;
      case #set:
        return getRef().set;
      case #setPriority:
        return getRef().setPriority;
      case #update:
        return getRef().update;
      case #disconnectCancel:
        return getRef().onDisconnect.cancel;
      case #disconnectSetWithPriority:
        return getRef().onDisconnect.setWithPriority;
      case #disconnectUpdate:
        return getRef().onDisconnect.update;
      case #on:
        return getQuery().on;
    }
    return null;
  }
}

class IsolateQuery extends Query {
  final List<String> pathSegments;
  final IsolateFirebaseDatabase database;
  final QueryFilter filter;
  final String path;

  IsolateQuery(this.database, this.pathSegments, this.filter)
      : path = pathSegments.map(Uri.encodeComponent).join('/');

  Future<T> invoke<T>(Symbol method,
      [List<dynamic> positionalArguments,
      Map<Symbol, dynamic> namedArguments]) {
    return database.app.commander.execute(QueryFunctionCall<FutureOr<T>>(
        method,
        database.app.name,
        database.databaseURL,
        path,
        filter,
        positionalArguments,
        namedArguments));
  }

  @override
  Query equalTo(dynamic value, [String key = '[ANY_NAME]']) {
    if (filter.orderBy == '.key' || key == '[ANY_NAME]') {
      return endAt(value).startAt(value);
    }
    return endAt(value, key).startAt(value, key);
  }

  @override
  Future<void> keepSynced(bool value) async {
    await invoke(#keepSynced, [value]);
  }

  @override
  Query limitToFirst(int limit) =>
      _withFilter(filter.copyWith(limit: limit, reverse: false));

  @override
  Query limitToLast(int limit) =>
      _withFilter(filter.copyWith(limit: limit, reverse: true));

  @override
  Stream<Event> on(String eventType) {
    return DeferStream(() {
      return database.app.commander.subscribe(QueryFunctionCall(
        #on,
        database.app.name,
        database.databaseURL,
        path,
        filter,
        [eventType],
      ));
    }, reusable: true);
  }

  Query _withFilter(QueryFilter filter) {
    return IsolateQuery(database, pathSegments, filter);
  }

  @override
  Query orderByChild(String child) {
    if (child == null || child.startsWith(r'$')) {
      throw ArgumentError("'$child' is not a valid child");
    }

    return _withFilter(filter.copyWith(orderBy: child));
  }

  @override
  Query orderByKey() => _withFilter(filter.copyWith(orderBy: r'.key'));

  @override
  Query orderByValue() => _withFilter(filter.copyWith(orderBy: r'.value'));

  @override
  Query orderByPriority() =>
      _withFilter(filter.copyWith(orderBy: r'.priority'));

  @override
  DatabaseReference reference() {
    return IsolateDatabaseReference(database, pathSegments);
  }

  @override
  Query startAt(dynamic value, [String key = '[MIN_NAME]']) {
    if (filter.orderBy == '.key') {
      if (key != '[MIN_NAME]') {
        throw ArgumentError(
            'When ordering by key, you may only pass one argument to startAt(), endAt(), or equalTo().');
      }
      key = value is String ? value : null;
      value = null;
    }
    return _withFilter(filter.copyWith(
        startAtKey: _parseKey(key, '[MIN_NAME]'),
        startAtValue: TreeStructuredData.fromJson(value)));
  }

  @override
  Query endAt(dynamic value, [String key = '[MAX_NAME]']) {
    if (filter.orderBy == '.key') {
      if (key != '[MAX_NAME]') {
        throw ArgumentError(
            'When ordering by key, you may only pass one argument to startAt(), endAt(), or equalTo().');
      }
      key = value is String ? value : null;
      value = null;
    }
    return _withFilter(filter.copyWith(
        endAtKey: _parseKey(key, '[MAX_NAME]'),
        endAtValue: TreeStructuredData.fromJson(value)));
  }

  Name _parseKey(String key, String allowedSpecialName) {
    if (key == '[MIN_NAME]' && key == allowedSpecialName) return Name.min;
    if (key == '[MAX_NAME]' && key == allowedSpecialName) return Name.max;
    if (key == null) {
      throw ArgumentError(
          'When ordering by key, the argument passed to startAt(), endAt(),or equalTo() must be a non null string.');
    }
    if (key.contains(RegExp(r'\.\#\$\/\[\]'))) {
      throw ArgumentError(
          'Second argument was an invalid key = "[MIN_VALUE]".  Firebase keys must be non-empty strings and can\'t contain ".", "#", "\$", "/", "[", or "]").');
    }
    return Name(key);
  }
}

class IsolateDisconnect extends Disconnect {
  final IsolateDatabaseReference reference;

  IsolateDisconnect(this.reference);

  @override
  Future cancel() {
    return reference.invoke(#disconnectCancel, []);
  }

  @override
  Future setWithPriority(value, priority) {
    return reference.invoke(#disconnectSetWithPriority, [value, priority]);
  }

  @override
  Future update(Map<String, dynamic> value) {
    return reference.invoke(#disconnectUpdate, [value]);
  }
}

class IsolateDatabaseReference extends IsolateQuery with DatabaseReference {
  Disconnect _onDisconnect;

  IsolateDatabaseReference(
      IsolateFirebaseDatabase database, List<String> pathSegments)
      : super(database, pathSegments, const QueryFilter()) {
    _onDisconnect = IsolateDisconnect(this);
  }

  @override
  DatabaseReference child(String c) => IsolateDatabaseReference(
      database, [...pathSegments, ...c.split('/').map(Uri.decodeComponent)]);

  @override
  Disconnect get onDisconnect => _onDisconnect;

  @override
  DatabaseReference parent() => pathSegments.isEmpty
      ? null
      : IsolateDatabaseReference(
          database, [...pathSegments.sublist(0, pathSegments.length - 1)]);

  @override
  DatabaseReference root() => IsolateDatabaseReference(database, []);

  @override
  DatabaseReference push() => child(database.pushIds.next(database.serverTime));

  @override
  Uri get url => Uri.parse(database.databaseURL).replace(path: path);

  @override
  Future<TransactionResult> runTransaction(transactionHandler,
      {Duration timeout = const Duration(seconds: 5),
      bool fireLocalEvents = true}) {
    // TODO: implement runTransaction
    throw UnimplementedError();
  }

  @override
  Future<void> set(value, {priority}) async {
    await invoke(#set, [value], {#priority: priority});
  }

  @override
  Future<void> setPriority(priority) async {
    await invoke(#setPriority, [priority]);
  }

  @override
  Future<void> update(Map<String, dynamic> value) async {
    await invoke(#update, [value]);
  }
}
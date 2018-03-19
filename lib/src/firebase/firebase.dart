// Copyright (c) 2016, Rik Bellens. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of firebase_dart;

/// A Firebase reference represents a particular location in your database and
/// can be used for reading or writing data to that database location.
abstract class Firebase implements Query {
  /// Construct a new Firebase reference from a full Firebase URL.
  factory Firebase(String url) => new FirebaseImpl(url);

  /// Getter for onDisconnect.
  Disconnect get onDisconnect;

  /// Authenticates a Firebase client using an authentication token or Firebase
  /// Secret.
  /// Takes a single token as an argument and returns a Future that will be
  /// resolved when the authentication succeeds (or fails).
  Future<Map> authWithCustomToken(String token);

  /// Synchronously retrieves the current authentication state of the client.
  dynamic get auth;

  /// Listens for changes to the client's authentication state.
  Stream<Map> get onAuth;

  /// Unauthenticates a Firebase client (i.e. logs out).
  Future unauth();

  /// Get a Firebase reference for a location at the specified relative path.
  ///
  /// The relative path can either be a simple child name, (e.g. 'fred') or a
  /// deeper slash separated path (e.g. 'fred/name/first').
  Firebase child(String c) => new Firebase(childUri(url, c).toString());

  /// Get a Firebase reference for the parent location. If this instance refers
  /// to the root of your Firebase, it has no parent, and therefore parent
  /// will return null.
  Firebase get parent {
    if (url.pathSegments.isEmpty) return null;
    return new Firebase(_parentUri(url).toString());
  }

  /// Returns a Firebase reference to the root of the Firebase.
  Firebase get root => new Firebase(_rootUri(url).toString());

  /// Returns the last token in a Firebase location.
  /// [key] on the root of a Firebase is `null`.
  String get key => url.pathSegments.isEmpty
      ? null
      : url.pathSegments.lastWhere((s) => s.isNotEmpty);

  /// Gets the absolute URL corresponding to this Firebase reference's location.
  Uri get url;

  /// Write data to this Firebase location. This will overwrite any data at
  /// this location and all child locations.
  ///
  /// The effect of the write will be visible immediately and the corresponding
  /// events ('onValue', 'onChildAdded', etc.) will be triggered.
  /// Synchronization of the data to the Firebase servers will also be started,
  /// and the Future returned by this method will complete after synchronization
  /// has finished.
  ///
  /// Passing null for the new value is equivalent to calling remove().
  ///
  /// A single set() will generate a single onValue event at the location where
  /// the set() was performed.
  Future set(dynamic value);

  /// Write the enumerated children to this Firebase location. This will only
  /// overwrite the children enumerated in the 'value' parameter and will leave
  /// others untouched.
  ///
  /// The returned Future will be complete when the synchronization has
  /// completed with the Firebase servers.
  Future update(Map<String, dynamic> value);

  /// Remove the data at this Firebase location. Any data at child locations
  /// will also be deleted.
  ///
  /// The effect of this delete will be visible immediately and the
  /// corresponding events (onValue, onChildAdded, etc.) will be triggered.
  /// Synchronization of the delete to the Firebase servers will also be
  /// started, and the Future returned by this method will complete after the
  /// synchronization has finished.
  Future remove() => set(null);

  /// Push generates a new child location using a unique name and returns a
  /// Firebase reference to it. This is useful when the children of a Firebase
  /// location represent a list of items.
  ///
  /// The unique name generated by push() is prefixed with a client-generated
  /// timestamp so that the resulting list will be chronologically sorted.
  Future<Firebase> push(dynamic value);

  /// Write data to a Firebase location, like set(), but also specify the
  /// priority for that data. Identical to doing a set() followed by a
  /// setPriority(), except it is combined into a single atomic operation to
  /// ensure the data is ordered correctly from the start.
  ///
  /// Returns a Future which will complete when the data has been synchronized
  /// with Firebase.
  Future<Null> setWithPriority(dynamic value, dynamic priority);

  /// Set a priority for the data at this Firebase location. A priority can
  /// be either a number or a string and is used to provide a custom ordering
  /// for the children at a location. If no priorities are specified, the
  /// children are ordered by name. This ordering affects the enumeration
  /// order of DataSnapshot.forEach(), as well as the prevChildName parameter
  /// passed to the onChildAdded and onChildMoved event handlers.
  ///
  /// You cannot set a priority on an empty location. For this reason,
  /// setWithPriority() should be used when setting initial data with a
  /// specific priority, and this function should be used when updating the
  /// priority of existing data.
  Future setPriority(dynamic priority);

  /// Atomically modify the data at this location. Unlike a normal set(), which
  /// just overwrites the data regardless of its previous value, transaction()
  /// is used to modify the existing value to a new value, ensuring there are
  /// no conflicts with other clients writing to the same location at the same
  /// time.
  ///
  /// To accomplish this, you pass [transaction] an update function which is
  /// used to transform the current value into a new value. If another client
  /// writes to the location before your new value is successfully written,
  /// your update function will be called again with the new current value, and
  /// the write will be retried. This will happen repeatedly until your write
  /// succeeds without conflict or you abort the transaction by not returning
  /// a value from your update function.
  ///
  /// The returned [Future] will be completed after the transaction has
  /// finished.
  Future<DataSnapshot> transaction(dynamic update(dynamic currentVal),
      {bool applyLocally: true});

  static Uri _parentUri(Uri uri) =>
      Uri.parse("$uri/").resolve("..").normalizePath();

  static Uri _rootUri(Uri uri) => uri.resolve("/").normalizePath();
}

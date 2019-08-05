# CryptIdent Version History

## 0.2.6 (5 August 2019)

This updates several Gems, eliminating a Gem version (`yard`) which had a CVE open against it. We also took the opportunity to update other outdated direct Gem dependency versions. No functional changes to code or tests were made.

## 0.2.5 (1 March 2019)

This is what should have been 0.2.3. That version attempted to resolve `UserRepository`, used in the `CryptIdent.included` method, at `require` time; instead, by using `Object#const_get`, we now do it at the time the module is included in another (by which time `UserRepository` can be expected to be defined). Meh.

## 0.2.4 (28 February 2019)

Yanked. Disregard.

## 0.2.3 (28 February 2019)

Beginning with this release, you do not need to (and ordinarily should not) assign to `config.repository` in order for `config.guest_user` to work (or vice versa). This eliminates a noisome bit of ceremony from using the config. See Issue  [#29](https://github.com/jdickey/crypt_ident/issues/29).

## 0.2.2 (21 February 2019)

First off, note that all 2019 releases are actually *marked* as 2019 releases now.

This release closes Issue [#28](https://github.com/jdickey/crypt_ident/issues/28), wherein we note that Version 0.2.1 and prior would have catastrophic breakage in `#update_session_expiry` when called with a `session_data` parameter that was "insufficiently Hash-like"; i.e., it did not support the `#merge` method. Examples of such not-quite-Hashes include `Hanami::Action::Session` which, rather obviously, is Important. 😞

## 0.2.1 (16 February 2019)

To commemorate The Valentine's Day Massacre, we've just re-discovered that Rack (the server protocol underlying all reasonably-modern Ruby Web frameworks) doesn't deal nicely with objects stored in `session` data (which is, by default, persisted in a cookie). If you assign, say, a `Hanami::Entity`-subclass instance to `session[:current_user]` (where `session` is Hanami's access to `Rack::Session`), when you later read from `session[:current_user]`, you'll be handed back a `Hash` of the Entity's attributes. Entity semantics specify that any two instances of the same Entity class with the sasme attribute values refer to _the same value_ of the Entity, not merely equal values, so converting back to an Entity is harmless. You just need to remember to do it and, as of 0.2.0, we didn't. That is fixed here, throughout the published API.

## 0.2.0 (2 February 2019)

Initial *confident* public (pre-)release.

Many bug-fixes; vastly improved documentation; better configuration; and integration tests (`test/integration/*_test.rb`) as the authoritative reference for usage, largely in conjunction with the API Documentation.

Beat on it as you will; feel free to [open issues](https://github.com/jdickey/crypt_ident/issues/new) or join the discussion on [Gitter](https://gitter.im/crypt_ident).

This is *far* more likely to become 1.0.0.

## 0.1.0 (18 December 2018)

Initial public (pre-)release.

"Why isn't this 1.0.0?", you ask. Because nobody, including me, has yet put code using `CryptIdent` into production (internal or otherwise). Therefore, any problems encountered in doing so can be resolved prior to an official 1.0.0 release. After 1.0.0, [semantic-versioning](https://semver.org/) rules apply.


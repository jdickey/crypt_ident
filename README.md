
CryptIdent
==========

Yet another fairly basic authentication Gem. (Authorisation, and batteries, sold separately.)

This is initially tied to Hanami 1.2.0+; specifically, it assumes that user entities have an API compatible with `Hanami::Entity` for accessing the field/attribute values listed below in [_Database/Repository Setup_](#databaserepository-setup) (which itself assumes a Repository API compatible with that of Hanami 1.2's Repository classes). The Gem is mostly a thin layer around [BCrypt](https://github.com/codahale/bcrypt-ruby) that, in conjunction with Hanami entities or work-alikes, supports the most common use cases for password-based authentication:

1. [Registration](#registration);
2. [Signing in](#signing-in);
3. [Signing out](#signing-out);
4. [Password change](#password-change);
5. [Password reset](#password-reset); and
6. [Session expiration](#session-expiration).

It *does not* implement features such as

1. Password-strength testing;
2. Password occurrence in a [list of most popular (and easily hacked) passwords](https://www.passwordrandom.com/most-popular-passwords); or
3. Password ageing (requiring password changes after a period of time).

These either violate current best-practice recommendations from security leaders (e.g., NIST and others no longer recommend password ageing as a defence against cracking) or have other Gems that focus on the features in question (e.g., [`bdmac/strong_password`](https://github.com/bdmac/strong_password)).



# Installation

Add this line to your application's Gemfile:

```ruby
gem 'crypt_ident'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install crypt_ident

# Usage

## Database/Repository Setup

`CryptIdent` assumes that the repository used to read and update the underlying database table is named `UserRepository`; that can be changed using the [_Configuration_](#configuration) settings.

We further assume that the Repository object

1. Has a _class method_ named `.entity_name` that returns the name of the Entity used by that Repository *as a string* (e.g., `"User"` for a `UserRepository`);
2. Has a class method named `.guest_user` that returns an Entity with a descriptive name (e.g., "Guest User") and is otherwise invalid for persistence (e.g., it has an invalid `id` attribute); and
3. Implements the "usual" common methods (`#create`, `#update`, `#delete`, etc) conforming to an interface compatible with [`Hanami::Repository`](https://github.com/hanami/model/blob/master/lib/hanami/repository.rb). This interface is suitably generic and sufficiently widely implemented, even in ORMs such as ActiveRecord that make no claim to implementing the [Repository Pattern](https://8thlight.com/blog/mike-ebert/2013/03/23/the-repository-pattern.html).

The database table for that Repository **must** have the following fields, in any order within the schema:

| Field | Type | Description |
|:----- | ---- | ----------- |
| `name` | string | The name of an individual User to be Authenticated |
| `email` | string | The Email Address for that User, to be used for Password Recovery, for example. |
| `password_hash` | text | The *encrypted* Password associated with that User. |
| `password_reset_sent_at` | timestamp without time zone | Defaults to `nil`; set this to the current time (`Time.now`) when responding to a Password Reset request (e.g., by email). The `token` (below) will expire at this time offset by the `reset_expiry` configuration value (see _Configuration_, below). |
| `token` | text | Defaults to `nil`. A Password Reset Token; a URL-safe secure random number (see [standard-library documentation](https://ruby-doc.org/stdlib-2.5.1/libdoc/securerandom/rdoc/Random/Formatter.html#method-i-urlsafe_base64)) used to uniquely identify a Password Reset request. |


## Configuration

The currently-configurable details for `CryptIdent` are as follows:

| Key | Default | Description |
|:--- | ------- | ----------- |
| `error_key` | `:error` | Modify this setting if you want to use a different key for flash messages reporting unsuccessful actions. |
| `guest_user` | Return value from `repository` `.guest_user` method | This value is used for the session variable `session[:current_user]` when no User has [signed in](#signing-in), or after a previously Authenticated User has [signed out](#signing-out). If your application *does not* make use of the [Null Object pattern](https://en.wikipedia.org/wiki/Null_object_pattern), you would assign `nil` to this configuration setting. (See [this Thoughtbot post](https://robots.thoughtbot.com/rails-refactoring-example-introduce-null-object) for a good discussion of Null Objects in Ruby.) |
| `hashing_cost` | 8 | This is the [hashing cost](https://github.com/codahale/bcrypt-ruby#cost-factors) used to *encrypt a password* and is applied at the hashed-password-creation step; it **does not** modify the default cost for the encryption engine. **Note that** any change to this value **will** invalidate and make useless all existing Encrypted Password stored values. |
| `:repository` | `UserRepository.new` | Modify this if your user records are in a different (or namespaced) class. |
| `:reset_expiry` | 86400 | Number of seconds from the time a password-reset request token is stored before it becomes invalid. |
| `:session_expiry` | 900 | Number of seconds *from either* the time that a User is successfully Authenticated *or* the `restart_session_counter` method is called *before* a call to `session_expired?` will return `true`. |
| `:success_key` | `:success` | Modify this setting if you want to use a different key for flash messages reporting successful actions. |
| `:token_bytes` | 16 | Number of bytes of random data to generate when building a password-reset token. See `token` in the [_Database/Repository Setup_](#databaserepository-setup) section, above.

For example

```ruby
  include CryptIdent
  CryptIdent.configure_crypt_id do |config|
    config.repository = MainApp::Repositories::User.new # note: *not* a Hanami recommended practice!
    config.error_key = :alert
    config.hashing_cost = 6 # less secure and less resource-intensive
    config.token_bytes = 20
    config.reset_expiry = 7200 # two hours; "we run a tight ship here"
    config.guest_user = UserRepository.new.guest_user
  end
```

would change the configuration as you would expect whenever that code was run. (We **recommend** that this be done inside the `controller.prepare` block of your Hanami `web` (or equivalent) app's `application.rb` file.)

## Introductory Notes on Workflows

### Session Handling Not Automatic

If you've set up your `controller.prepare` block as **recommended** in the preceding section, `CryptIdent` is loaded and configured but *does not* implement session-handling "out of the box"; as with [other libraries](https://github.com/sebastjan-hribar/tachiban#session-handling), it must be implemented *by you* as described in the [*Session Expiration*](#session-expiration) description below.

### Code Samples in API Reference are Authoritative

Only minimal code snippets are included here to help explain use cases.  However, the [API Reference](docs/CryptIdent.html) should be considered authoritative; any discrepancies between the API and/or code snippets there and here should be regarded as a bug (and a [report](https://github.com/jdickey/crypt_ident/issues/) filed if not already filed.

### Terminology and the project Ubiquitous Language

Finally, a note on terminology. Terms that have meaning (e.g., _Guest User_) within this module's domain language, or [Ubiquitous Language](https://www.martinfowler.com/bliki/UbiquitousLanguage.html), **must** be capitalised, at least on first use within a paragraph. This is to stress to the reader that, while these terms may have "obvious" meanings, their use within this module and its related documents (including this one) **should** be consistent, specific, and rigorous in their meaning. In the [API Documentation](docs/CryptIdent.html), each of these terms **must** be listed in the _Ubiquitous Language Terms_ section under each method description in which they are used.

After the first usage in a paragraph, the term **may** be used less strictly (e.g., by referring to a _Clear-Text Password_ simply as a _password_ *if* doing so does not introduce ambiguity or confusion. The reader should feel free to [open an issue report](https://github.com/jdickey/cript_ident/issues) if you spot any lapses. (Thank you!)

## Use-Case Workflows

### Registration

#### Overview

Method involved:

```ruby
  module CryptIdent
    def sign_up(params, current_user:, repo: nil, on_error: nil, &on_success)
      # ...
    end
  end
```

This is the first of our use cases that involves calling a function which expects a block to be supplied; if one isn't, then a log-format warning message will remind you of the error.

The `params` parameter is a Hash-like object such as a `Hanami::Action::Params` instance. It **must** have a `:name` entry, as well as any other keys and matching field values required by the Entity which will be created from the `params` values, *other than* a `:password_hash` key. It **should** have a `:password` entry; if none is specified, then a *random* `:password_hash` attribute (rather than one created by encrypting the `:password`) will be assigned to the resulting Entity.

Pass in the value of the `session[:current_user]` session variable as the `:current_user` parameter. This **should** be an Entity value; if it is an integer, it will be used as an `id` to `#find` from the Repository in use by the method.

If a Repository instance different than that loaded by the [_Configuration_](#configuration) is to be used, pass it in as the `repo:` parameter. Leaving the default value, `nil`, **should** work in a properly-designed application.

To have the `#sign_up` method call a Callable (`Proc` or lambda) when an error is detected, supply it as the `on_error:` parameter. The parameters to be passed to it include

1. an error ID Symbol, which will also be the value returned by the `#sign_up` method itself;
2. the `params` passed to the `#sign_up` method;
3. a {CryptIdent::Config} instance describing the active configuration values;
4. a Hash of any other information relevant to the error; this will be documented in the {file:docs/CryptIdent.md API Guide} when relevant, defaulting to an empty Hash otherwise.

The block associated with the `#sign_up` call (documented as `&on_success` above) will be called *if and only if* the method is successful (and returns a User instance). The block **must** accept two parameters:

1. the User Entity that was created; and
2. a {CryptIdent::Config} instance describing the active configuration values.

These will be further described below:

#### Success, aka Golden Path

If the `params` include all values required by the underlying schema, including a valid `name` attribute that does not exist in the underlying data store, and an entry for `password`, then the specified `password` will be encrypted into a URL-safe string and used for the `password_hash` attribute of the new Entity. If the `password` is `nil`, empty, or blank, the resulting`password_hash` attribute will be randomised, requiring a [_Password Reset_](#password-reset) before the user can [_Sign In_](#signing-in).

The `&on_success` block will be called with the newly-created User Entity and Config object as parameters. This would typically be used to define UI interactions such as flash messages, redirection, and so on.

#### Error Conditions

##### Authenticated User as `current_user:` Parameter

If the specified `current_user:` parameter is a valid User instance or ID, then that is presumed to be the Current User of the application. Authenticated Users are prohibited from creating other Users, and so the call will fail and return `:current_user_exists`. This will also be the error ID passed to any defined `on_error:` handler.

##### Specified `:name` Attribute Already Used for an Existing User

If the specified `:name` attribute exists in a record within the Repository, then the call will fail and the returned error ID will be `:user_already_created`.

##### Record Could Not be Created Within Repository

If the Repository method `#create` returned an error, then the call will fail and the returned error ID will be `:user_creation_failed`.

### Signing In

#### Overview

Method involved:

```ruby
  module CryptIdent
    def sign_in(user, password, current_user: nil)
      # ...
    end
  end
```

Once a User has been [Registered](#registration), Signing In is a matter of retrieving that user's Entity (containing a `password_hash` attribute) and calling `#sign_in` passing in that Entity, the purported Clear-Text Password, and the currently Authenticated User (if any), then seeing what the return value is.

If the passed-in `current_user` is a User Entity *other than* the specified `user` Entity *or* the Guest User, no match will be attempted, and the method will return `:current_user_exists`. (A value of `nil` is treated as equivalent to the Guest User.)

If the supplied Clear-Text Password is *incorrect*, then `#sign_in` will return `nil`.

If it is *correct*, then the return value will be a User Entity with the same attributes as the one passed in.

**Note that** this method **does not** interact with a Repository, and therefore doesn't need to account for an invalid User Name parameter, for instance. Nor does it modify session data, although the associated Controller Action Class code **must** set `session[:current_user]` and `session[:start_time]` as below.

On *success*, the Controller Action Class calling code **must** set:

* `session[:start_time]` to the current time as returned by `Time.now`; and
* `session[:current_user]` to the *Entity* (not the ID value from the Repository) for the newly-Authenticated User.  This is to eliminate repeated reads of the Repository.

On *failure*, the Controller Action Class calling code **must** set:

* `session[:start_time]` to some sufficiently-past time to *always* trigger `#session_expired?`; `Hanami::Utils::Kernel.Time(0)` does this quite well, returning midnight GMT on 1 January 1970, converted to local time.
* `session[:current_user]` to `nil` or to the Guest User (see [_Configuration_](#configuration)).

*However*, the developer is again reminded that this method **does not** manipulate `session` data directly.

### Signing Out -- TODO: FIXME

Signing out a previously Authenticated user is straightforward: call the `sign_out` method.

If the `session[:current_user]` value *does not* have the value of [`config.guest_user`](#configuration), `session[:start_time]` is set to `0000-01-01 00:00:00 +0000`, and the method returns `true`.

If `session[:current_user]` _is_ the Guest User, then `session[:start_time]` is cleared as above, and the method returns `false`.

In neither case is any data but the `session` values affected.

### Password Change -- TODO: FIXME

To change an [authenticated](#signing-in) user's password, the current clear-text password, new clear-text password, and clear-text password confirmation are passed to `change_password`.

If the Encrypted Password in the `session[:current_user]` entity does not match the encrypted value of the specified current Clear-Text Password, then the method returns `:bad_password` and no changes occur.

If the current-password check succeeds but the new Clear-Text Password and its confirmation do not match, then the method returns `:mismatched_password` and no changes occur.

If the new Clear-Text Password and its confirmation match, then the _encrypted value_ of that new password is returned, and the `session[:current_user]` Entity is replaced with an Entity identical except that it has the new encrypted value for `password_hash`.

### Password Reset -- TODO: FIXME

To reset a User's password when the User *is not* [authenticated](#signing-in) is a two-step process:

1. Request that a password-reset link be sent to the email address associated with an individual user; and
2. Visit the unique link in the email sent in response to the first step to actually change the password.

#### Request a reset-password-link email message

Password Reset Tokens are useful for verifying that the person requesting a Password Reset for an existing User is sufficiently likely to be the person who Registered that User or, if not, that no compromise or other harm is done.

Typically, this is done by sending a link through email or other such medium to the address previously associated with the User purportedly requesting the Password Reset. `CryptIdent` *does not* automate generation or sending of the email message. What it *does* provide is a method to generate a new Password Reset Token to be embedded into an HTML anchor link within an email
that you construct.

It also implements an expiry system, such that if the confirmation of the Password Reset request is not completed within a [configurable](#Configuration) time, that the token is no longer valid (and cannot be later reused by unauthorised persons).

#### Actually reset the password

The `reset_password` method is called with the reset token encoded into the URL from the email in the preceding step, along with the clear-text new password and new-password confirmation parameters supplied to the action.

If the token is invalid or has expired, `reset_password` returns `:invalid_token` and no changes occur.

If the new password and confirmation do not match, `reset_password` returns `:mismatched_password` and no changes occur.

If the clear-text new password and its confirmation match, then the hashed value of that new password is returned, and the `session[:current_user]` Entity is replaced with an Entity identical except that it has the new value for `password_hash`.

### Session Expiration -- TODO: FIXME

Session management is a necessary part of implementing authentication (and authorisation) within an app. However,  it's not something that an authentication *library* can fully implement without making the client application excessively inflexible and brittle.

`CryptIdent` has two convenience methods which *help in* implementing session-expiration logic; these make use of the `session_expiry` [configuration value](#configuration).

* `CryptIdent#restart_session_counter` resets the session-expiry time to the current time *plus* the number of seconds specified by the `session_expiry` configuration value.
* `CryptIdent#session_expired?` returns `true` if the current time is not less than the session-expiry time; it returns `false` otherwise.

Example code which uses these methods is illustrated below, as a shared-code module that may be included in your controllers' action classes:

```ruby
# apps/web/controllers/handle_session.rb

module Web
  module HandleSession
    include CryptIdent

    def self.included(other)
      other.class_eval do
        before :validate_session
      end
    end

    private

    def validate_session
      return restart_session_counter unless session_expired?

      @redirect_url ||= routes.root_path
      session[:current_user] = config.guest_user
      error_message = 'Your session has expired. You have been signed out.'
      flash[config.error_key] = error_message
      redirect_to @redirect_url
    end
  end
end
```

This code should be fairly self-explanatory. Including the module adds the private `#validate_session` method to the client controller action class, adding a call to that method before the action class' `#call` method is entered. If the session-expiry time has been previously set and is not before the current time, then that session-expiry time is reset based on the current time, and no further action is taken. Otherwise:

1. The `current_user` setting in the session data is overwritten with the [`config.guest_user`](#configuration) value (defaulting to `nil`);
2. A flash error message is set, which **should** be rendered within the controller action's view; and
3. Control is redirected to the path or URL specified by `@redirect_url`, defaulting to the root path (`/`).

This code will be instantly familiar to anyone coming from another framework like Rails, where the conventional way to ensure authentication before a controller action is executed is to add a `:before` hook. Adding this module to the controller action class is also justifiable Hanami, since it depends on and interacts with session data. (Just don't let any actual domain logic [taint](http://hanamirb.org/guides/1.2/actions/control-flow/#proc) your controller callbacks; that's begging for difficult-to-debug problems going forward.

# API Documentation

See [the Documentation Index](./docs/index.html)

# Development

After checking out the repo, run `bin/setup` to install dependencies. If you use [`rbenv`](https://github.com/rbenv/rbenv) and [`rbenv-gemset`](https://github.com/jf/rbenv-gemset), the `setup` script will create a new Gemset (in `./tmp/gemset`) to keep your system Gem repository pristine. Then, run `bin/rake test` to run the tests, or `bin/rake` without arguments to run tests and all static-analysis tools ([Flog](https://github.com/seattlerb/flog), [Flay](https://github.com/seattlerb/flay), [Reek](https://github.com/troessner/reek), and [RuboCop](https://github.com/rubocop-hq/rubocop/)). Running `bin/rake inch` will let [Inch](http://trivelop.de/inch/) comment on the amount of internal documentation in the project.

You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bin/rake install` or `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bin/rake release` or `bundle exec rake release`, which will create a Git tag for the version, push Git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

# Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jdickey/crypt_ident. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

# License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

# Code of Conduct

Everyone interacting in the CryptIdent project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/jdickey/crypt_ident/blob/master/CODE_OF_CONDUCT.md).

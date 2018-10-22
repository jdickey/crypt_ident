
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

`CryptIdent` assumes that the entities being worked with are named `User` and the repository used to read and update the underlying database table is named `UserRepository`; that can be changed below.

The database table for that repository **must** have the following fields:

<table>
<thead>
<tr>
<th style="text-align:left">Field</th>
<th>Type</th>
<th>Description</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left"><code>password_hash</code></td>
<td>text</td>
<td>Encrypted password string.</td>
</tr>
<tr>
<td style="text-align:left"><code>reset_sent_at</code></td>
<td>timestamp without time zone</td>
<td>Defaults to <code>nil</code>; set this to the current time (<code>Time.now</code>) when responding to a password-reset request (e.g., by email). The <code>token</code> (below) will expire at this time offset by the <code>reset_expiry</code> configuration value (below).</td>
</tr>
<tr>
<td style="text-align:left"><code>token</code></td>
<td>text</td>
<td>A URL-safe secure random number (see <a href="https://ruby-doc.org/stdlib-2.5.1/libdoc/securerandom/rdoc/Random/Formatter.html#method-i-urlsafe_base64">standard-library documentation</a>) used to uniquely identify a password-reset request.</td>
</tr>
</tbody>
</table>

## Configuration

The currently-configurable details for `CryptIdent` are as follows:

<table>
<thead>
<tr>
<th style="text-align:left">Key</th>
<th>Default</th>
<th>Description</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left"><code>error_key</code></td>
<td><code>:error</code></td>
<td>Modify this setting if you want to use a different key for flash messages reporting unsuccessful actions.</td>
</tr>
<tr>
<td style="text-align:left"><code>hashing_cost</code></td>
<td>8</td>
<td>This is the <a href="https://github.com/codahale/bcrypt-ruby#cost-factors">hashing cost</a> used to <em>encrypt a password</em> and is applied at the hashed-password-creation step; it <strong>does not</strong> modify the default cost for the encryption engine. <strong>Note that</strong> any change to this value <em>should</em> invalidate and make useless all existing hashed-password stored values.</td>
</tr>
<tr>
<td style="text-align:left"><code>guest_user</code></td>
<td><code>nil</code></td>
<td>This value is used for the session variable <code>session[:current_user]</code> when no user has <a href="#signing-in">signed in</a>, or after a previously-authenticated user has <a href="#signing-out">signed out</a>. If your application makes use of the <a href="https://en.wikipedia.org/wiki/Null_object_pattern">Null Object pattern</a>, you would assign your null object instance to this configuration setting. (See <a href="https://robots.thoughtbot.com/rails-refactoring-example-introduce-null-object">this Thoughtbot post</a> for a good discussion of Null Objects in Ruby.)</td>
</tr>
<tr>
<td style="text-align:left"><code>repository</code></td>
<td><code>UserRepository.new</code></td>
<td>Modify this if your user records are in a different (or namespaced) class.</td>
</tr>
<tr>
<td style="text-align:left"><code>reset_expiry</code></td>
<td>86400</td>
<td>Number of seconds from the time a password-reset request token is stored before it becomes invalid.</td>
</tr>
<tr>
<td style="text-align:left"><code>session_expiry</code></td>
<td>900</td>
<td>Number of seconds <em>from either</em> the time that a user is successfully authenticated <em>or</em> the <code>restart_session_counter</code> method is called <em>before</em> a call to <code>session_expired?</code> will return <code>true</code>.</td>
</tr>
<tr>
<td style="text-align:left"><code>success_key</code></td>
<td><code>:success</code></td>
<td>Modify this setting if you want to use a different key for flash messages reporting successful actions.</td>
</tr>
<tr>
<td style="text-align:left"><code>token_bytes</code></td>
<td>16</td>
<td>Number of bytes of random data to generate when building a password-reset token. See <code>token</code> in the <a href="#databaserepository-setup">database/repository setup</a> section, above.</td>
</tr>
<tr>
<td style="text-align:left"><code>validity_time</code></td>
<td>600</td>
<td>Number of seconds from the time a user successfully <a href="#signing-in">signs in</a> before a call to <code>session_expired?</code> will return <code>true</code> rather than <code>false</code>.</td>
</tr>
</tbody>
</table>

For example

```ruby
  include CryptIdent
  CryptIdent.configureure_crypt_id do |config|
    config.repository = MainApp::Repositories::User.new # note: *not* a Hanami recommended practice!
    config.error_key = :alert
    config.hashing_cost = 6 # less secure and less resource-intensive
    config.token_bytes = 20
    config.reset_expiry = 7200 # two hours; "we run a tight ship here"
    config.guest_user = UserRepository.new.guest_user
  end
```

would change the configuration as you would expect whenever that code was run. (We **recommend** that this be done inside the `controller.prepare` block of your Hanami `web` (or equivalent) app's `application.rb` file.)

## Use-Case Workflows

First, if you've set up your `controller.prepare` block as **recommended** in the preceding section, `CryptIdent` is loaded and configured but *does not* implement session-handling "out of the box"; as with [other libraries](https://github.com/sebastjan-hribar/tachiban#session-handling), it must be implemented *by you* as described in the [*Session Expiration*](#session-expiration) description below.

Note that these workflows demonstrate *sample* `User` Entity and Repository layouts; you are free to adapt them, with the aid of the [_Configuration_](#configuration) settings detailed above, to your specific needs.

Code examples are not included here, but are shown in the [API Reference](docs/CryptIdent.html).

Finally, a note on terminology. Terms that have meaning (e.g., _Repository_) within this module's domain language, or [Ubiquitous Language](https://www.martinfowler.com/bliki/UbiquitousLanguage.html), should be capitalised, at least on first use within a paragraph. This is to stress to the reader that, while these terms may have "obvious" meanings, their use within this module and its related documents (including this one) **should** be consistent, specific, and rigorous in their meaning. In the [API Documentation](docs/CryptIdent.html), each of these terms **must** be listed in the _Ubiquitous Language Terms_ section under each method description in which they are used.

After the first usage in a paragraph, the term **may** be used less strictly (e.g., by referring to a _Clear-Text Password_ simply as a _password_ *if* doing so does not introduce ambiguity or confusion. The reader should feel free to [open an issue report](https://github.com/jdickey/cript_ident/issues) if you spot any lapses. (Thank you!)

### Registration

To build an Entity suitable for saving to the appropriate Repository, call the `add_password` method, passing in a Hash of attributes and a plain-text password as parameters. The method returns a Hash containing the entries supplied in the parameter, with the addition of a `password_hash` entry whose value is the encrypted value of the supplied plain-text password.

If the supplied plain-text password is an empty string, blank, or `nil`, then the `password_hash` attribute of the returned entity will be randomised, requiring a [_Password Reset_](#password-reset) before the user can [_Sign In_](#signing-in).

Once the new attribute Hash with an encrypted `password_hash` has been returned from `add_password`, it may be used to build and persist an Entity as you normally would.

### Signing In

Once a user has been [Registered](#registration), signing in is a matter of retrieving that user's Entity (containing a `password_hash` attribute) and calling `#sign_in` passing in that Entity and the supplied clear-text password, and seeing what the return value is.

If the supplied clear-text password is *incorrect*, then `#sign_in` will return `nil`.

If it is *correct*, then the return value will be `true`.

**Note that** `#sign_in` interacts with session data if available. (In unit tests, it often is not.) Specifically:

On *success*:

* `session[:start_time]` is set to the current time as returned by `Time.now` when called from within the method;
* `session[:current_user]` is set to the *Entity* (not the ID value from the Repository) for the now-logged-in user.  This is to eliminate repeated reads of the Repository.

On *failure*:

* `session[:start_time]` is set to `0000-01-01 00:00:00 +0000`;
* `session[:current_user]` is set to [`config.guest_user`](#configuration).

If a *different user* is logged in (as evidenced by `session[:current_user]`), then `#sign_in` returns `false` and the `session` data remains unchanged.

### Signing Out

Signing out a previously Authenticated user is straightforward: call the `sign_out` method.

If the `session[:current_user]` value *does not* have the value of [`config.guest_user`](#configuration), `session[:start_time]` is set to `0000-01-01 00:00:00 +0000`, and the method returns `true`.

If `session[:current_user]` _is_ the Guest User, then `session[:start_time]` is cleared as above, and the method returns `false`.

In neither case is any data but the `session` values affected.

### Password Change

To change an [authenticated](#signing-in) user's password, the current clear-text password, new clear-text password, and clear-text password confirmation are passed to `change_password`.

If the Encrypted Password in the `session[:current_user]` entity does not match the encrypted value of the specified current Clear-Text Password, then the method returns `:bad_password` and no changes occur.

If the current-password check succeeds but the new Clear-Text Password and its confirmation do not match, then the method returns `:mismatched_password` and no changes occur.

If the new Clear-Text Password and its confirmation match, then the _encrypted value_ of that new password is returned, and the `session[:current_user]` Entity is replaced with an Entity identical except that it has the new encrypted value for `hashed_password`.

### Password Reset

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

If the clear-text new password and its confirmation match, then the hashed value of that new password is returned, and the `session[:current_user]` Entity is replaced with an Entity identical except that it has the new value for `hashed_password`.

### Session Expiration

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

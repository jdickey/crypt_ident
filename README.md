# CryptIdent

Yet another fairly basic authentication Gem. (Authorisation, and batteries, sold separately.)

This is initially tied to Hanami 1.3.0+; specifically, it assumes that user entities have an API compatible with `Hanami::Entity` for accessing the field/attribute values listed below in [_Database/Repository Setup_](#databaserepository-setup) (which itself assumes a Repository API compatible with that of Hanami 1.3's Repository classes). The Gem is mostly a thin layer around [BCrypt](https://github.com/codahale/bcrypt-ruby) that, in conjunction with Hanami entities or work-alikes, supports the most common use cases for password-based authentication:

1. [Registration](#registration);
2. [Signing in](#signing-in);
3. [Signing out](#signing-out);
4. [Password change](#password-change);
5. [Password reset](#password-reset); and
6. [Session expiration management](#session-management-overview).

It *does not* implement features such as

1. Password-strength testing;
2. Password occurrence in a [list of most popular (and easily hacked) passwords](https://www.passwordrandom.com/most-popular-passwords); or
3. Password ageing (requiring password changes after a period of time).

These either violate current best-practice recommendations from security leaders (e.g., NIST and others no longer recommend password ageing as a defence against cracking) or have other Gems that focus on the features in question (e.g., [`bdmac/strong_password`](https://github.com/bdmac/strong_password)).

**NOTE:** One feature of this Gem is that most of the [configuration](#configuration) *should* Work Just Fine for most use cases. However, you **must** explicitly initialise the `:repository` configuration item prior to using the configuration data for the `repository` or the `guest_user` entries. We **recommend** assigning this once, during application startup when other configuration setup is being completed.

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

1. Has a _class method_ named `.entity_name` that returns the name of the Entity used by that Repository *as a string* (e.g., `"User"` for a `UserRepository`). (This is to match `Hanami::Repository`.)
2. Has a class method named `.guest_user` that returns an Entity with a descriptive name (e.g., "Guest User") and is otherwise invalid for persistence (e.g., it has an invalid `id` attribute); and
3. Implements the "usual" common methods (`#create`, `#update`, `#delete`, etc) conforming to an interface compatible with [`Hanami::Repository`](https://github.com/hanami/model/blob/master/lib/hanami/repository.rb). This interface is suitably generic and sufficiently widely implemented, even in ORMs such as ActiveRecord that make no claim to implementing the [Repository Pattern](https://8thlight.com/blog/mike-ebert/2013/03/23/the-repository-pattern.html).

The database table for that Repository **must** have the following fields, in any order within the schema:

| Field | Type | Description |
|:----- | ---- | ----------- |
| `name` | string | The name of an individual User to be Authenticated |
| `email` | string | The Email Address for that User, to be used for Password Recovery, for example. |
| `password_hash` | text | The *encrypted* Password associated with that User. |
| `password_reset_expires_at` | timestamp without time zone | Defaults to `nil`; set this to the Expiry Time (`Time.now + config.reset_expiry`) when responding to a Password Reset request (e.g., by email). The `token` (below) will expire at this time (see _Configuration_, below). |
| `token` | text | Defaults to `nil`. A Password Reset Token; a URL-safe secure random number (see [standard-library documentation](https://ruby-doc.org/stdlib-2.5.1/libdoc/securerandom/rdoc/Random/Formatter.html#method-i-urlsafe_base64)) used to uniquely identify a Password Reset request. |

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

## User Entity

`CryptIdent` currently **requires** the Entity persisted to and retrieved from the Repository to have the class name `User`. In addition to attributes matching the fields specified in the _Database/Repository Setup_ table above (which `Hanami::Entity` and most analogous ORM Entities expose by default), the Entity **must** respond to the `#guest?` message, returning `true` if it is the Guest User (as returned by `UserRepository#guest_user`), or `false` otherwise. It *may* have other methods as appropriate to the client code.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

## Configuration

The currently-configurable details for `CryptIdent` are as follows:

| Key | Default | Description |
|:--- | ------- | ----------- |
| `error_key` | `:error` | Modify this setting if you want to use a different key for flash messages reporting unsuccessful actions. |
| `guest_user` | Return value from `repository` `.guest_user` method | This value is used for the session variable `session[:current_user]` when no User has [signed in](#signing-in), or after a previously Authenticated User has [signed out](#signing-out). If your application *does not* make use of the [Null Object pattern](https://en.wikipedia.org/wiki/Null_object_pattern), you would assign `nil` to this configuration setting. (See [this Thoughtbot post](https://robots.thoughtbot.com/rails-refactoring-example-introduce-null-object) for a good discussion of Null Objects in Ruby.) |
| `hashing_cost` | 8 | This is the [hashing cost](https://github.com/codahale/bcrypt-ruby#cost-factors) used to *encrypt a password* and is applied at the hashed-password-creation step; it **does not** modify the default cost for the encryption engine. **Note that** any change to this value **will** invalidate and make useless all existing Encrypted Password stored values. |
| `:repository` | `UserRepository.new` | Modify this if your user records are in a different (or namespaced) class. |
| `:reset_expiry` | 86400 (24 hours in seconds) | Number of seconds from the time a password-reset request token is stored before it becomes invalid. |
| `:session_expiry` | 900 (15 minutes) | Number of seconds *from either* the time that a User is successfully Authenticated *or* the `update_session_expiry` method is called *before* a call to `session_expired?` will return `true`. |
| `:success_key` | `:success` | Modify this setting if you want to use a different key for flash messages reporting successful actions. |
| `:token_bytes` | 24 | Number of bytes of random data to generate when building a password-reset token. See `token` in the [_Database/Repository Setup_](#databaserepository-setup) section, above.

For example

```ruby
  include CryptIdent

  CryptIdent.configure do |config|
    config.repository = MainApp::Repositories::User.new # note: *not* a Hanami recommended practice!
    config.error_key = :alert
    config.hashing_cost = 6 # less secure and less resource-intensive
    config.token_bytes = 20
    config.reset_expiry = 7200 # two hours; "we run a tight ship here"
    config.guest_user = MainApp::Repositories::User.new.guest_user
  end
```

would change the configuration as you would expect whenever that code was run. (We **recommend** that this be done inside the `controller.prepare` block of your Hanami `web` (or equivalent) app's `application.rb` file.)

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

## Introductory Notes on Workflows

### Interfaces

The methods employed directly by these use cases use [Result matchers](https://dry-rb.org/gems/dry-matcher/result-matcher/) and [`Result` monads](https://dry-rb.org/gems/dry-monads/1.0/result/) to provide a *consistent, fluent, explicit, and understandable* mechanism for detecting and handling success and failure.

Each method *requires* a block, to which a `result` indicating success or failure is yielded. That block **must** in turn define blocks for **both** `result.success` and `result.failure` to handle success and failure results, respectively. Each of the two blocks takes parameters which the method uses to communicate either the successful result (and possible supporting information), or the reason for failure, along with supporting information. Not all failure cases use all parameters to the `result.failure` block. Any that are not relevant may be safely ignored (and **should** by convention have a value of `:unassigned` yielded to the `result.failure` block).

The active configuration **is not** passed as a parameter to either the `success` or `failure` blocks; it is always accessible as `CryptIdent.config`, and is based on the [`dry-configurable`](https://dry-rb.org/gems/dry-configurable/) Gem.

For further discussion of this, see the documentation of the individual methods in the [API Reference](docs/CryptIdent.html).

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

### Session Handling Not Automatic

If you've set up your `controller.prepare` block as **recommended** in the preceding section, `CryptIdent` is loaded and configured but *does not* implement session-handling "out of the box"; as with [other libraries](https://github.com/sebastjan-hribar/tachiban#session-handling), it must be implemented *by you* as described in the [*Session Expiration*](#session-expiration) description below.

### Code Samples in API Reference are Authoritative

Only minimal code snippets are included here to help explain use cases.  However, the [API Reference](docs/CryptIdent.html) should be considered authoritative; any discrepancies between the API and/or code snippets there and here should be regarded as a bug (and a [report](https://github.com/jdickey/crypt_ident/issues/) filed if not already filed.

### Terminology and the project Ubiquitous Language

Finally, a note on terminology. Terms that have meaning (e.g., _Guest User_) within this module's domain language, or [Ubiquitous Language](https://www.martinfowler.com/bliki/UbiquitousLanguage.html), **must** be capitalised, at least on first use within a paragraph. This is to stress to the reader that, while these terms may have "obvious" meanings, their use within this module and its related documents (including this one) **must** be consistent, specific, and rigorous in their meaning. In the [API Documentation](docs/CryptIdent.html), each of these terms **must** be listed in the _Ubiquitous Language Terms_ section under each method description in which they are used. (If you find any omissions, inconsistencies, or other errors, please open a [new issue](https://github.com/jdickey/conversagence-hanami/issues/new) if it has not already been [reported](https://github.com/jdickey/conversagence-hanami/issues).)

After the first usage in a paragraph, the term **may** be used less strictly; e.g., by referring to a _Clear-Text Password_ simply as a _password_ *if* doing so does not introduce ambiguity or confusion. The reader should feel free to [open an issue report](https://github.com/jdickey/crypt_ident/issues) for any lapses of consistency or clarity. (Thank you!)

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

## Use-Case Workflows

### Registration

#### Overview

Method involved:

```ruby
  module CryptIdent
    def sign_up(attribs, current_user:)
      # ...
    end
  end
```

This is the first of our use cases that involves calling a function which expects a block to be supplied. If one isn't, then a `LocalJumpError` will be raised. If either the `success` or `failure` blocks are omitted within that block, then a `Dry::Matcher::NonExhaustiveMatchError` will be raised. (It *is* permissible to completely omit the parameters to a `success` or `failure` block; e.g., for the `#sign_out` method which does not support reporting a failure.)

The `attribs` parameter is a Hash-like object such as a `Hanami::Action::Params` instance. It **must** have a `:name` entry, as well as any other keys and matching field values required by the Entity which will be created from the `params` values, *other than* a `:password_hash` key. It also **must not** have a `:password` entry; if one is supplied, it will be *ignored*. This is to support our standard workflow of having newly-Registered Users be initially assigned a Clear-Text Password of random text, then immediately starting the [Password Reset](#password-reset) workflow to further validate their supplied email address.

Pass in the value of the `session[:current_user]` session variable as the `:current_user` parameter. This **must** be an Entity value rather than an `id` value. Supplying a value of `nil` is permitted, and is equivalent to specifying the Guest User (see [_Database/Repository Setup_](#database-repository-setup)).

As described [earlier](#interfaces), this method **requires** a block which accepts a `result` parameter. The block **must** define *both* `result.success` and `result.failure` blocks, passing each a block which itself takes appropriate parameters. These will be further described below.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

#### Success, aka Golden Path

If the `params` include all values required by the underlying schema, including a valid `name` attribute that does not exist in the underlying data store, then it (with a `password_hash` attribute created from a random-text Clear-Text Password) will be persisted to the Repository specified by `repo:` (or to the Repository specified by the [_Configuration_](#configuratino) if the `repo:` value is `nil`). That User Entity will be passed to the `result.success` block as the `user:` parameter.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

#### Error Conditions

##### Authenticated User as `current_user:` Parameter

If the specified `current_user:` parameter is a valid User Entity other than the Guest User, then that is presumed to be the Current User of the application. Authenticated Users are prohibited from creating other Users, and so the `result.failure` block will be called with a `code:` of `:current_user_exists`.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

##### Specified `:name` Attribute Already Used for an Existing User

If there is no improper value for the `current_user:` parameter, and if the specified `:name` attribute exists in a record within the Repository, then the `result.failure` block will be called with a `:code` of `:user_already_created`.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

##### Record Could Not be Created Within Repository

If neither of the earlier conditions apply, but the Repository method `#create` returned an error, then the `result.failure` block will be called with a `:code` of `:user_creation_failed `.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

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

Once a User has been [Registered](#registration) and [Reset their Password](#password-reset), Signing In is a matter of retrieving that user's Entity (containing a `password_hash` attribute) and calling `#sign_in` passing in that Entity, the purported Clear-Text Password, and the currently Authenticated User (if any), then using the `result` passed to the yielded block to determine and respond to the success or failure of the call.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

#### Successfully Signing In

So long as no User is currently Authenticated in the Session (as shown by the `session[:current_user]` having a value of either `nil` or the Guest User), supplying a User Entity and the correct Clear-Text Password for that User to a call to `#sign_in` will cause the block for the `#sign_in` method call to yield the *same* User Entity to the `result.success` block, indicating success.

Note that this process is unchanged if the passed-in `current_user` is *the same as* the User Entity attempting Authentication. It is up to client code to determine how to proceed if Authentication fails in this case.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

#### Error Conditions

##### Incorrect Password Supplied

While no Authenticated Member currently exists (as shown by the `session[:current_user]` having a value of either `nil` or the Guest User), supplying a User Entity and an *incorrect* Clear-Text Password for that User to a call to `#sign_in` will yield a call to the block's `result.failure` block with a `code:` of `:invalid_password`.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

##### Authenticated User Exists

If the passed-in `current_user` is a User Entity *other than* the specified `user` Entity *or* the Guest User, no match will be attempted, and the method will yield a call to the block's `result.failure` block with a `code:` value of `:illegal_current_user`.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

##### Guest User Attempts Authentication

While no Authenticated Member currently exists (as shown by the `session[:current_user]` having a value of either `nil` or the Guest User), supplying *the Guest User* as the User Entity to be Authenticated will yield a call to the block's `result.failure` block with a `code:` value of `:user_is_guest`.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

#### Other Notes

This method **does not** interact with a Repository, and therefore doesn't need to account for an invalid User Name parameter, for instance. Nor does it directly modify session data, although the associated Controller Action Class code **must** set `session[:current_user]` and `session[:start_time]` as below. This is to support extraction of this code (along with anything else not using `Hanami::Controller`-dependent input validation, redirects, flash messages, etc) to an Interactor, into which would be explicitly passed `session[:current_user]`.

On *success*, the Controller Action Class calling code **must** set:

* `session[:start_time]` to the current time as returned by `Time.now`; and
* `session[:current_user]` to the *Entity* (not the ID value from the Repository) for the newly-Authenticated User.  This is to eliminate repeated reads of the Repository.

On *failure*, the Controller Action Class calling code **must** set:

* `session[:start_time]` to some sufficiently-past time to *always* trigger `#session_expired?`; `Hanami::Utils::Kernel.Time(0)` does this quite well, returning midnight GMT on 1 January 1970, converted to local time.
* `session[:current_user]` to `nil` or to the Guest User (see [_Configuration_](#configuration)).

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

### Signing Out

#### Overview

Method involved:

```
module CryptIdent
  def sign_out(current_user:)
  end
end
```

Signing out any previously Authenticated User is straightforward: call the `sign_out` method, passing in that User as the `current_user:` parameter. As with the earlier methods, this method also **requires** a block which accepts a `result` parameter and has `result.success` and `result.failure` calls/blocks. No parameters are yielded to either block.

Note that, as of Release 0.2.0, the method simply passes control to the (required) block, in whose `result.success` call block you can delete or reset `session[:current_user]` and `session[:start_time]`. We **recommend** reset values of:

* `CryptIdent.configure_crypt_ident.guest_user` for `session[:current_user]` and
* `Hanami::Utils::Kernel.Time(0)` for `session[:start_time]`, which will set the timestamp to 1 January 1970 at midnight  &mdash; a value which should *far* exceed your session-expiry limit if you decide not to simply delete the previous values by assigning `nil` to them.

The required `result.failure` block can simply be skipped, as

```
    result.failure { next }
```

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

### Password Change

#### Overview

Method involved:

```ruby
  module CryptIdent
    def change_password(user, current_password, new_password)
      # ...
    end
  end
```

To change an Authenticated User's password, an Entity for that User, the current Clear-Text Password, and the new Clear-Text Password are required.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

#### Successfully Changing the Password

If all parameters are valid and the updated User is successfully persisted, the method calls the **required** block with a `result` whose `result.success` matcher is yielded a `user:` parameter with the updated User as its value. From that point, the User is able to Sign In using the User Name and updated Clear-Text Password.

Client code **must** take care not to try to Authenticate using the Encrypted Password in the Entity passed in to this method, as it is no longer current. Either retain the returned User Entity from the method, or read it again from the Repository.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

#### Error Conditions

##### Specified User is Guest User

If the passed-in `user` is the Guest User (or `nil`), the method  calls the **required** block with a `result` whose `result.failure` matcher is yielded a `code:` of `:invalid_user`. No new Entity with updated values is created; no changes are made to the Repository.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

##### Invalid Current Clear-Text Password

If the specified Current Clear-Text Password cannot Authenticate against the encrypted value within the `user` Entity, the method calls the **required** block with a `result` whose `result.failure` matcher is yielded a `code:` of `:bad_password`. No new Entity with updated values is created; no changes are made to the Repository.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

### Generate Password Reset Token and Password Reset: Introduction

Password Reset Tokens are useful for verifying that the person requesting a Password Reset for an existing User is sufficiently likely to be the person who Registered that User or, if not, that no compromise or other harm is done.

Typically, this is done by sending a link through email or other such medium to the address previously associated with the User purportedly requesting the Password Reset. `CryptIdent` *does not* automate generation or sending of the email message. What it *does* provide is a method to generate a new Password Reset Token to be embedded into such a message, often in the form of an HTML anchor link within an email that you construct. It also provides another method (`#reset_password`) to actually change the password given a valid, correct token.

It also implements an expiry system, such that if the confirmation of the Password Reset request is not completed within a [configurable](#Configuration) time, that the Token is no longer valid (and cannot be later reused by unauthorised persons).

**Note that** multiple successful calls to generate a new Password Reset Token for a single User overwrite the data generated by previous calls, invalidating the previously-generated Tokens and resetting the expiry.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

### Generate Password Reset Token

Method involved:

```ruby
module CryptIdent
  def generate_reset_token(user_name, current_user: nil)
    # ...
  end
end
```

#### Successfully Generating a Token

Given a `user_name` parameter that specifies an existing User Name, and a `current_user:` parameter that is either `nil` or the Guest User, the method calls the **required** block with a `result` whose `result.success` matcher is yielded a `user:` parameter with a User Entity as its value. That User will be an Entity whose `name` matches the specified `user_name` parameter, with (new) values for the `token` and `password_reset_expires_at` attributes. The `token` attribute uniquely identifies the Password Reset request, and the `password_reset_expires_at` attribute is based on both the current (server-local) time when the updated User Entity was persisted to the Repository, and the `:reset_expiry` attribute of the configuration.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

#### Error Conditions

##### Authenticated User Exists

If the specified `current_user:` parameter is a valid User Entity other than the Guest User, then that is presumed to be the Current User of the Application. Authenticated Users are prohibited from requesting Password Resets for other Users; if they wish to change their *own* Clear-Text Password, there's a [method](#password-change) for that.

In this case, the **required** block will be passed a `result` whose `result.failure` matcher is yielded a `code:` parameter of `:user_logged_in`, a `current_user:` parameter matching the passed-in User Entity, and a `name:` parameter of `:unassigned` (which must be included in the block parameters but can be ignored thereafter).

##### Named User Not Found in Repository

If the specified `user_name` parameter value does not match the `name` of any User in the Repository, then the **required** block will be passed a `result` whose `result.failure` matcher is yielded a `code:` parameter of `:user_not_found`, a `current_user:` parameter of the Guest User, and a `name:` parameter whose value is the passed-in `user_name` value.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

### Password Reset

#### Overview

Method involved:

```ruby
module CryptIdent
  def reset_password(token, new_password, current_user: nil)
    # ...
  end 
end
```

Calling `#reset_password` is different than calling `#change_password` in one vital respect: with `#change_password`, the User involved **must** be the Current User (as presumed by passing the appropriate User Entity in as the `current_user:` parameter), whereas `#reset_password` **must not** be called with *any* User other than the Guest User as the `current_user:` parameter (and, again presumably, the Current User for the session). How can we assure ourselves that the request is legitimate for a specific User? By use of the Token generated by a previous call to `#generate_reset_token`, which is used _in place of_ a User Name for this request.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

#### Successfully Resetting a Password

To successfully perform a Password Reset, supply a valid, non-expired Token along with a new Clear-Text Password to the `#reset_password` method. Once the Token is found in the configuration-default Repository, and is verified not to have Expired, then the Repository will be updated with a record for that User where the `password_hash` field has been updated to reflect the new Clear-Text Password, and the `token` and `password_reset_expires_at` fields will be set to `nil`.

If all the preceding is successful and the updated User is successfully persisted, the method calls the **required** block with a `result` whose `result.success` matcher is yielded a `user:` parameter with the updated User as its value. From that point, the User is able to Sign In using the User Name and updated Clear-Text Password.

Client code **must** take care not to try to Authenticate using the Encrypted Password in the Entity passed in to this method, as it is no longer current. Either retain the returned User Entity from the method, or read it again from the Repository.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

#### Error Conditions

##### Expired Token

If the passed-in `token` parameter matches the `token` field of a record in the Repository *and* that Token is determined to have Expired, then this method calls the **required** block with a `result` whose `result.failure` matcher is yielded a `code:` parameter of `:expired_token` and a `token:` parameter that has the same value as the passed-in `token` parameter.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

##### Token Not Found

If the passed-in `token` parameter *does not* match the `token` field of any record in the Repository, then this method calls the **required** block with a `result` whose `result.failure` matcher is yielded a `code:` parameter of `:token_not_found` and a `token:` parameter that has the same value as the passed-in `token` parameter.

##### Invalid Current User

If the passed-in `current_user:` parameter *is not* either the default `nil` or the Guest User, then this method calls the **required** block with a `result` whose `result.failure` matcher is yielded a `code:` parameter of `:invalid_current_user` and a `token:` parameter that has the same value as the passed-in `token` parameter.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

### Session Management Overview

Session management is a necessary part of implementing authentication (and authorisation) within an app. However,  it's not something that an authentication *library* can fully implement without making the client application excessively inflexible and brittle.

`CryptIdent` has two convenience methods which *help in* implementing session-expiration logic; these make use of the `session_expiry` [configuration value](#configuration).

* `CryptIdent#update_session_expiry` returns a `Hash` whose `:expires_at` value the current time *plus* the number of seconds specified by the `session_expiry` configuration value. This can be used to update the corresponding `session` data which defines the session-expiry time;
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
      updates = update_session_expiry(session)
      if !session_expired?(session)
        session[:expires_at] = updates[:expires_at]
        return
      end

      @redirect_url ||= routes.root_path
      config = CryptIdent.config
      session[:current_user] = config.guest_user
      session[:expires_at] = updates[:expires_at]
      error_message = 'Your session has expired. You have been signed out.'
      flash[config.error_key] = error_message
      redirect_to @redirect_url
    end
  end
end
```

This code should be fairly self-explanatory. Including the module adds the private `#validate_session` method to the client controller action class, adding a call to that method before the action class' `#call` method is entered. (One can argue that this violates the spirit if not the letter of the [Hanami Guide's](https://guides.hanamirb.org/actions/control-flow/) warning not to "use callbacks for model domain logic operations". We would argue that this callback's functionality is common to essentially all client applications and, by providing a reference example, allows individual project teams to modify it as required for their use.) If the session-expiry time has been previously set and is not before the current time, then that session-expiry time is reset based on the current time, and no further action is taken. Otherwise:

1. The `current_user` setting in the session data is overwritten with the [`config.guest_user`](#configuration) value (defaulting to `nil`);
2. A flash error message is set, which **should** be rendered within the controller action's view; and
3. Control is redirected to the path or URL specified by `@redirect_url`, defaulting to the root path (`/`).

This code will be instantly familiar to anyone coming from another framework like Rails, where the conventional way to ensure authentication before a controller action is executed is to add a `:before` hook. Adding this module to the controller action class is also justifiable Hanami, since it depends on and interacts with session data. (Just don't let any actual domain logic [taint](http://hanamirb.org/guides/1.2/actions/control-flow/#proc) your controller callbacks; that's begging for difficult-to-debug problems going forward.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

### Session Expired

Method involved:

```ruby
module CryptIdent
  def session_expired?(session_data={})
    # ...
  end 
end
```

This is one of two methods in `CryptIdent` (the other being [`#update_session_expiry `](#update-session-expiry), below) which *does not* follow the `result`/success/failure [monad workflow](#interfaces). Like that method:

* there is no success/failure division in the workflow;
* calling this method only makes sense if there is an Authenticated User;
* it is intended for use in session-management code as described in the [Overview](#session-management-overview) above.

This method checks the passed-in `session_data[:start_time]` value against the current time. If the difference is *greater than* the [configured](#configuration) _Session Expiry_ value, then the method returns `true`; otherwise, it returns `false`. No change is attempted to the contents of the passed-in `session_data`.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

### Update Session Expiry

#### Overview

Method involved:

```ruby
module CryptIdent
  def update_session_expiry(session_data={})
    # ...
  end 
end
```

This is one of two methods in `CryptIdent` (the other being [`#session_expired?`](#session-expired), above) which *does not* follow the `result`/success/failure [monad workflow](#interfaces). This is because there is no success/failure division in the workflow. Calling the method only makes sense if there is an Authenticated User, but *all this method does* is return a `Hash` as defined below.

It is intended for use in session-management code as described in the [Overview](#session-management-overview) above.

#### Parameter

The parameter, `session_data`, is a Hash-like object which **should** have existing entries for `:current_user` (defaulting to the Guest User if not found) and for `:expires_at` (defaulting to the [epoch](https://en.wikipedia.org/wiki/Unix_time) if not found).

#### Return

The return value is a `Hash` which:

1. `:current_user` value is the same as the passed-in parameter's `:current_user` value *if* that is a Registered User, or the Guest User if it isn't; and
2. `start_time` value is a `Time` instance based on the current time when called.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

# API Documentation

See [the Documentation Index](/CryptIdent.html).

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

# Development

After checking out the repo, run `bin/setup` to install dependencies. If you use [`rbenv`](https://github.com/rbenv/rbenv) and [`rbenv-gemset`](https://github.com/jf/rbenv-gemset), the `setup` script will create a new Gemset (in `./tmp/gemset`) to keep your system Gem repository pristine. Then, run `bin/rake test` to run the tests, or `bin/rake` without arguments to run tests and all static-analysis tools ([Flog](https://github.com/seattlerb/flog), [Flay](https://github.com/seattlerb/flay), [Reek](https://github.com/troessner/reek), and [RuboCop](https://github.com/rubocop-hq/rubocop/)). Running `bin/rake inch` will let [Inch](http://trivelop.de/inch/) comment on the amount of internal documentation in the project.

You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bin/rake install` or `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bin/rake release` or `bundle exec rake release`, which will create a Git tag for the version, push Git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

# Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jdickey/crypt_ident. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

# License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

# Code of Conduct

Everyone interacting in the CryptIdent project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/jdickey/crypt_ident/blob/master/CODE_OF_CONDUCT.md).

<sub style="font-size: 0.75rem;">[Back to Top](#CryptIdent)</sub>

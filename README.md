# Authorizir #

*N.B. the mathematical expressions in this document are composed in laTex format
and will be most legible when this document is translated to HTML by ex_doc
(i.e. run `mix docs` and open the generated `doc/index.html` file in your web
browser.)*

Authorizir is an Ecto-backed authorization library for Elixir applications that
allows for a flexible, cascading, permission grant/denial based system that can
be applied to hierarchies of both subjects (the entity to which a permission is
granted or denied) and objects (the entity that a subject is attempting to
access/modify).

## Definitions ##

The following terms are used throughout this document to describe aspects of
authorization and access control:

**Subject**
: An entity that is attempting to perform an operation, e.g. a logged-in user or
  an API client

**Object**
: An entity that is the target of an operation being performed by a Subject,
  e.g. if a logged-in user (Subject) attempts to update a record, the Object is
  the record.

**Privilege**
: Represents a discrete business operation with semantic meaning to the
  application that is responsible for performing that operation, e.g. if a
  logged-in user (Subject) attempts to update an assignment (Object), the
  Privilege might simply be update_assignments or it may be more granular such
  as schedule_assignment.

**Grant**
: Used in combination with a Privilege to signify that the Privilege is either
  explicitly granted (Positive Grant) or explicitly denied (Negative Grant).

**Access Rule**
: Defines a combination of Subject, Object, Privilege, and Grant.

**Application**
: In this document, unless otherwise specified, an Application is any deployed
  application or service within the Foundry platform that will use the
  Authorization System to control access to its data and operations.

**Authorization Query**
: A combination of specific Subject, Object, and Privilege identities used as
  input to the Authorization System when an Application requests an
  Authorization.

**Authorization**
: For a given Authorization Query, the Authorization is the final determination
  of the Grant value (Positive Grant or Negative Grant) after considering all
  defined Access Rules that directly or indirectly apply to the entities
  specified in the Authorization Query.

## A Hierarchical Model for Access Control ##

The Authorization System described in this document is based on the system
described by Andreas Geyer-Schulz and Anke Thede in *Implementation of
Hierarchical Authorization for a Web Based Digital Library*[^1] uses three
distinct hierarchies to model Access Rules: **Subjects**, **Objects**, and
**Privileges**. This is similar to the NIST level-2 RBAC model[^2] in that
Privilege assignments can be propagated along a hierarchy of Subjects in a
manner that is similar to the use of Role hierarchies, however RBAC does not
inherently address the need for a similar hierarchy in the set of Objects. In
this Authorization System, we maintain the primary advantages of the RBAC model
while largely avoiding the inherent downsides of shared Roles; we do not
explicitly model the use of ABAC, however the model can be extended in various
ways to support ABAC as an Application-level concern.

  * A Subject can be any type of entity, whether authenticated (e.g. an internal
    Administrator, a User account, or an API client) or anonymous (e.g. someone
    accessing data from an emailed link that does not require them to log in).
    (N.B. The authorization system is not responsible for authenticating the
    Subject; Applications must take other measures to ensure that Privileges are
    being checked against the appropriate Subject identity.)

  * An Object can be any type of entity that has a distinct identity. As long as
    the entity can be uniquely identified, the authorization system can apply
    access control to it.

  * A Privilege can represent any discrete business operation that a Subject may
    be able to perform on an Object. The Authorization System will not require
    semantic knowledge of Privileges (aside from any Privileges which may apply
    to the authorization system itself). Each Application will be responsible
    for implementing the semantics of the Privileges that affect its operations.

  * Using only the identities (i.e. ID attributes) of a Subject, Object, and a
    Privilege, an Application is able to submit an Authorization Query and
    receive an Authorization.

  * Any Privilege that is not explicitly granted is denied.

  * If multiple Access Rules are defined that directly or indirectly affect a
    given combination of Subject, Object, and Privilege, the most restrictive
    Access Rule will apply. In other words, if Access Rule `r` implies that
    Subject `s` has a Positive Grant for Privilege `p` on Object `o`, and Access
    Rule `r'` implies that Subject `s` has a Negative Grant for Privilege `p` on
    Object `o`, when the Authorization System applies both rules, the resulting
    Authorization must be a Negative Grant.

  * No Subject `s` shall be capable of creating an Access Rule that will change
    the resulting Privilege of that same Subject `s` (i.e. a Subject cannot
    create a rule that would result in a Positive Grant on an Object for which
    the Subject does not *already* have a Positive Grant.)

  * No Subject `s` shall be capable of creating an Access Rule affecting a
    Privilege `p` on an Object `o` to another Subject `s'` where `s` does not
    already have a Positive Grant Authorization for `p` on `o` (i.e. if you do
    not have permission to do X, then you also may not grant someone else
    permission to do X.)
    

    
## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `authorizir` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:authorizir, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/authorizir>.

[^1]: Geyer-Schulz A, Thede A. "Implementation of Hierarchical Authorization For A Web Based Digital Library", **Systemics, Cybernetics and Informatics**, Vol. 5, No. 2, 2007, pp. 51--56

[^2]: Sandhu R, Ferraiolo D, Kuhn R. The NIST Model for Role-Based Access Control: Towards a Unified Standard

# Authorizir #

<!-- N.B. the mathematical expressions in this document are composed in laTex format
and will be most legible when this document is translated to HTML by ex_doc
(i.e. run `mix docs` and open the generated `doc/index.html` file in your web
browser.) -->

Authorizir is an Ecto-backed authorization library for Elixir applications that
allows for a flexible, cascading, privilege grant/denial based system that can
be applied to hierarchies of both subjects (the entity to which a privilege is
granted or denied) and objects (the entity that a subject is attempting to
access/modify).

Authorizir requires the use of [PostgreSQL with the ltree
extension](https://www.postgresql.org/docs/current/ltree.html). The ltree
extension is used internally to maintain the directed, acyclic graphs
representing the Subject, Object, and Privilege hierarchies that are explained
in the remainder of this document.[^1]

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
  application or service within your platform that will use the Authorization
  System to control access to its data and operations.

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
Hierarchical Authorization for a Web Based Digital Library*[^2] uses three
distinct hierarchies to model Access Rules: **Subjects**, **Objects**, and
**Privileges**. This is similar to the NIST level-2 RBAC model[^3] in that
Privilege assignments can be propagated along a hierarchy of Subjects in a
manner that is similar to the use of Role hierarchies, however RBAC does not
inherently address the need for a similar hierarchy in the set of Objects. In
this Authorization System, we maintain the primary advantages of the RBAC model
while largely avoiding the inherent downsides of shared Roles; we do not
explicitly model the use of ABAC, however the model can be extended in various
ways to support ABAC as an Application-level concern.

### Guiding Principles ###

Authorizir adheres to the following guiding principles in order to provide an
authorization system that is both secure and adaptable to a wide variety of needs:

  * A Subject can be any type of uniquely-identifiable entity, whether
    authenticated (e.g. an internal Administrator, a User account, or an API
    client) or anonymous (e.g. someone accessing data from an emailed link that
    does not require them to log in). (N.B. The authorization system is not
    responsible for *authenticating* the Subject; Applications must take other
    measures to ensure that Privileges are being checked against the appropriate
    Subject identity.) Authorizir has no semantic knowledge about the Subjects
    aside from modeling their hierarchy as a directed, acyclic graph of IDs.

  * An Object can also be any type of uniquely-identifiable entity. Authorizir
    has no semantic knowledge about the Objects aside from modeling their
    hierarchy as a directed, acyclic graph of IDs.
    
  * A single entity MAY be represented as both a Subject and an Object (e.g. the
    User entity, "Jim", may be assigned Privileges for their use of a
    system—thus behaving as a Subject—and a different User, "Ann", may have
    privileges that allow them to act on the "Jim" entity—in which case "Jim" is
    behaving as an Object.)

  * A Privilege represents a discrete business operation that a Subject may be
    able to perform on an Object. Authorizir does not require semantic knowledge
    of Privileges (aside from any Privileges that apply to the authorization
    system itself). Each Application is responsible for implementing the
    semantics of the Privileges that affect its operations.

  * Using only the identities (e.g. the ID attributes) of a Subject, Object, and
    a Privilege, an Application is able to submit an Authorization Query and
    receive an Authorization.

  * Any Privilege that is not explicitly granted is denied.

  * If multiple Access Rules are defined that directly or indirectly affect a
    given combination of Subject, Object, and Privilege, the *most restrictive*
    Access Rule will apply. In other words, if Access Rule $r$ implies that
    Subject $s$ has a Positive Grant for Privilege $p$ on Object $o$, and Access
    Rule $r'$ implies that Subject $s$ has a Negative Grant for Privilege $p$ on
    Object $o$, when the Authorization System applies both rules, the resulting
    Authorization must be a Negative Grant.

  * No Subject $s$ shall be capable of creating an Access Rule that will change
    the resulting Privilege of that same Subject $s$ (i.e. a Subject cannot
    create a rule that would result in a Positive Grant on an Object for which
    the Subject does not *already* have a Positive Grant.)

  * No Subject $s$ shall be capable of creating an Access Rule affecting a
    Privilege $p$ on an Object $o$ to another Subject $s'$ where $s$ does not
    already have a Positive Grant Authorization for $p$ on $o$ (i.e. if you do
    not have a given privilege, then you also may not grant someone else
    that privilege.)
    
### Access Rules ###

The canonical access control model is defined as the relation $R_S \sube S
\times P \times O$ where $S$ is the set of all Subjects, $P$ is the set of all
Privileges, $O$ is the set of all Objects, and $G = \lbrace +,- \rbrace $
(either a Positive Grant or a Negative Grant). Access Rules are defined in terms
of two tuples such that a Positive Grant is $\langle s,p,o,+ \rangle$ and a
Negative Grant is $\langle s,p,o,- \rangle$. The Negative Grant is defined
explicitly rather than relying only on the lack of a Positive Grant, because an
explicit Negative Grant can be used to override a Positive Grant in situations
where a Subject is related to an Object through multiple paths.

### The Subject and Object Hierarchies ###

Each of the sets of Subjects and Objects are defined as a hierarchy created
using a partial order on its elements. This allows Access Rules to be defined
such that they can be applied not just to individual elements but also to any
subsets of Subjects and Objects. Each hierarchy can be generalized such that for
set $X \in \lbrace S,O \rbrace$, the partial order is defined on the power set
$P(X)$. The hierarchical relationship between elements of each of these sets is
expressed as

$$Y = P(X) \newline
  \forall \lbrace X_i \mid X_i \in Y \rbrace ,
  X_i \in X_j \iff (X_j \in Y \land X_i \prec_Y X_j)$$

Each element in $P(X)$ is given a name reflecting the semantics of those
elements within the business domain (i.e. a given Subject may have the name
"John Doe" and an Object may have the name "Blog Posts".) The set of names for
all elements in $P(X)$ is denoted as $X_N$ and $* \in X_N$ is the supremum of
set $X$. The relation between elements of set $X$ and their names is defined as
the bijection $\upsilon_X:X_N \to X$.

We also define the functions $su:X \to P(X)$ and $pr:X \to P(X)$ such that
$su(x) \to \lbrace y:y \prec_X x \rbrace$ (the set of all subsets of $x \in X$)
and $pr(x) \to \lbrace y:y \succ_X x \rbrace$ (the set of all supersets of $x
\in X$.) These functions are used to find all of the possible descendants or
ascendants, respectively, of a given entity in one of the three hierarchies, so
that the Access Rules for that entity can be determined for any given $\langle
s,o,p \rangle$, even where those Access Rules are only made explicit on other
elements in any of the hierarchies. This simplifies the management of the Access
Rules by reducing the number of distinct Access Rules that must be created. In
particular it allows for the appropriate access controls to be applied to both
Subjects and Objects as a natural consequence of their organization within the
relevant Applications.

### The Privilege Hierarchy ###

The privilege hierarchy is slightly different in that the partial order $\prec P$ is
defined directly on the set $P$ rather than on the power set of $P$ such that

$$\forall \lbrace p_i | p_i \in P \rbrace,
  p_j \in p_i \iff (p_j \in P \land p_i \prec_P p_j)$$

This means that Privilege $p_j$ implies $p_i$, or in other words, a Subject that has
been granted $p_j$ has necessarily *also* been granted $p_i$. This makes sense for
Privileges, as one Privilege (such as “edit document”, for example) may
necessarily require another Privilege (“read document”). By creating a hierarchy
allowing for this implication, we avoid unnecessarily explicit specification
of Access Rules in such cases. Similar to the other two hierarchies, $P_N$
represents the set of names for all of the Privileges in $P$.

### Privilege Propagation and Conflict Resolution ###

Privileges are granted or revoked by specifying an Access Rule as $r = \langle
s_n, o_n , p_n \rangle \in S_N \times O_N \times P_N \times G$, which can then
be translated into a set of canonical access definitions with the function

$$T:S_N \times O_N \times P_N \times G \to P(S \times O \times P \times G)$$

so that for an Access Rule $a = \langle a_S, a_O, a_P, a_G \rangle$:

$$
T(a) = \begin{cases}
su_S(\nu(a_S)) \times su_O(\nu(a_O)) \times su_P(\nu(a_P)) \times + & \iff & a_G = + \newline
su_S(\nu(a_S)) \times su_O(\nu(a_O)) \times pr_P(\nu(a_P)) \times - & \iff & a_G = -
\end{cases}
$$
   
Note that there is a difference in the direction of propagation applied to the
Privilege depending on the value of $a_G$. This is the method by which we ensure
that the explicit denial of a Privilege will always take precedence, event to
the point of denying a superior privilege that was explicitly granted. For
example, let's say that Subject "John" has been granted the "edit" privilege on
the group of objects, "Blog Posts". The "edit" privilege is an ancestor of the
"read" privilege (i.e. having "edit" implies also having "read".) Within the
"Blog Posts" group, there is a sub-group called "Private". There exist an access
rule that declares a negative grant for "John" on the "Private" group for the
"read" privilege. Even though the positive grant of the "edit" privilege on
"Blog Posts" for "John" would normally apply to everything in that object group,
including the "Private" group, the explicit denial of the "read" privilege on
the "Private" group also transalates into a denial of the "edit" privilege on
the "Private" group.

In order to determine the Authorization for a given $\langle s, o, p \rangle$,
we use the function $cA : S \times O \times P \to \lbrace true, false \rbrace$
defined as:

$$
cA(\langle s, o, p \rangle ) = \exists \lbrace \langle s \prime , o \prime, p \prime
\rangle \in S_N \times O_N \times P_N : \langle s, o, p, + \rangle \in T(\langle
s \prime, o \prime, p \prime, + \rangle ) \rbrace  \newline
\hphantom{cA\langle s, o, p \rangle ) = } \land \nexists \lbrace \langle \hat{s},
\hat{o}, \hat{p} \rangle \in S_N \times O_N \times P_N : \langle s, o, p, -
\rangle \in T(\langle \hat{s}, \hat{o}, \hat{p}, - \rangle ) \rbrace
$$

If the given combination of subject, object, and privilege can be derived from a
Positive Grant using the translation function $T$ and if there is no Negative Grant
that also can be translated to the given subject, object, and privilege, then
the result is true, or a Positive Grant Authorization; otherwise, if there is
either no explicit Positive Grant, or if there is an explicit Negative Grant,
then the result will be false, or a Negative Grant Authorization.

Although the use of Negative Grants is available as needed, the fact that they
cannot be overridden at lower levels of the Subject and Object hierarchies means
that they should generally be used only as necessary and in the tightest scope
possible (i.e. towards the leaf nodes of the hierarchies); in practice, almost
all useful configurations of Access Rules for a system can be derived from the
use of Positive Grants, since the default in the absence of any applicable
Access Rule is $cA(a)=false$.

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

[^1]: X. B. Talavera, “DAGs with materialized paths using postgres ltree,” bustawin, Aug. 27, 2018. https://www.bustawin.com/dags-with-materialized-paths-using-postgres-ltree/ (accessed Jan. 06, 2022).

[^2]: A. Geyer-Schulz and A. Thede, “Implementation of Hierarchical Authorization For A Web Based Digital Library,” Systemics, Cybertetics and Informatics, 2007, doi: 10.54808/JSCI.

[^3]: R. Sandhu, D. Ferraiolo, and R. Kuhn, “The NIST model for role-based access control,” Proceedings of the fifth ACM workshop on Role-based access control  - RBAC ’00, 2000, doi: 10.1145/344287.344301.

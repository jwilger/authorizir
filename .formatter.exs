# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [
    permission: 2,
    permission: 3,
    role: 2,
    role: 3,
    collection: 2,
    collection: 3,
    grant: 2,
    deny: 2
  ],
  export: [
    locals_without_parens: [
      permission: 2,
      permission: 3,
      role: 2,
      role: 3,
      collection: 2,
      collection: 3,
      grant: 2,
      deny: 2
    ]
  ]
]

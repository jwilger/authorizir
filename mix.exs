defmodule Authorizir.MixProject do
  use Mix.Project

  def project do
    [
      name: "Authorizir",
      source_url: "https://github.com/jwilger/authorizir",
      homepage_url: "https://github.com/jwilger/authorizir",
      app: :authorizir,
      version: "0.1.0",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      docs: [
        main: "readme",
        extras: ["README.md"],
        before_closing_body_tag: &before_closing_body_tag/1,
        before_closing_head_tag: &before_closing_head_tag/1,
        markdown_processor: {ExDoc.Markdown.Earmark, footnotes: true}
      ]
    ]
  end

  defp before_closing_head_tag(:html) do
    """
    <style>
      .content-inner {
        line-height: 2.2;
      }

      a.footnote, a.footnote:visited {
        vertical-align: super;
        font-size: 1em;
        text-decoration: none;
        color: blue;
      }

      a.reversefootnote {
        display: inline-block;
        text-indent: -9999px;
        line-height: 0;
        text-decoration: none;
      }

      a.reversefootnote:after {
        content: ' ↩';
        text-indent: 0;
        display: block;
        line-height: initial;
        color: blue;
        text-decoration: none;
      }

      .katex {
        color: darkblue;
        background-color: white;
      }
    </style>
    """
  end

  defp before_closing_head_tag(_), do: ""

  defp before_closing_body_tag(:html) do
    """
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.13.0/dist/katex.min.css" integrity="sha384-t5CR+zwDAROtph0PXGte6ia8heboACF9R5l/DiY+WZ3P2lxNgvJkQk5n7GPvLMYw" crossorigin="anonymous">
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.13.0/dist/katex.min.js" integrity="sha384-FaFLTlohFghEIZkw6VGwmf9ISTubWAVYW8tG8+w2LAIftJEULZABrF9PPFv+tVkH" crossorigin="anonymous"></script>
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.13.0/dist/contrib/auto-render.min.js" integrity="sha384-bHBqxz8fokvgoJ/sc17HODNxa42TlaEhB+w8ZJXTc2nZf1VgEaFZeZvT4Mznfz0v" crossorigin="anonymous"></script>
    <script>
      document.addEventListener("DOMContentLoaded", function() {
        renderMathInElement(document.body, {
          delimiters: [
            { left: "$$", right: "$$", display: true },
            { left: "$", right: "$", display: false },
          ],
          throwOnError : true
        });
      });
    </script>
    """
  end

  defp before_closing_body_tag(_), do: ""

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ecto_sql, "~> 3.6"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:postgrex, ">= 0.0.0"},
      {:sobelow, "~> 0.9", only: [:dev, :test], runtime: false},
      {:typed_ecto_schema, "~> 0.3"},
      {:uuid, "~> 1.1"}
    ]
  end

  defp aliases do
    [
      test: ["ecto.drop --quiet", "ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end

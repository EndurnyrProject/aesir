defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Lexer do
  @moduledoc """
  Tokenizes a raw rAthena item `Script` string into a flat token list.

  This is the first stage of the rAthena item-script transpiler. It is a pure
  function with no symbol resolution: identifiers, numbers and constants are all
  emitted verbatim; mapping them to Aesir values is the resolver/codegen's job.

  Whitespace and `//` line comments are discarded. Any character that cannot
  start a token (trailing garbage) yields `{:error, _}` instead of raising.
  """

  import NimbleParsec

  @typedoc """
  A single lexical token.

  - `{:ident, name}` — identifier or rAthena constant, e.g. `{:ident, "itemheal"}`,
    `{:ident, "SC_BLESSING"}`. The lexer does not distinguish keywords or constants.
  - `{:int, value}` — unsigned integer literal, e.g. `{:int, 45}`. A leading `-`
    is lexed as the `{:op, :-}` operator, not part of the number.
  - `{:string, value}` — double-quoted string literal with surrounding quotes
    stripped and `\\"` / `\\\\` escapes unescaped.
  - `{:op, op}` — operator, where `op` is one of
    `:>`, `:<`, `:>=`, `:<=`, `:==`, `:!=`, `:&&`, `:||`, `:+`, `:-`, `:*`, `:/`.
  - `{:punct, punct}` — punctuation, where `punct` is one of
    `:comma`, `:semicolon`, `:lparen`, `:rparen`, `:lbrace`, `:rbrace`.
  """
  @type token ::
          {:ident, String.t()}
          | {:int, integer()}
          | {:string, String.t()}
          | {:op, atom()}
          | {:punct, atom()}

  whitespace = ascii_char([?\s, ?\t, ?\n, ?\r, ?\v, ?\f])

  comment =
    string("//")
    |> repeat(lookahead_not(ascii_char([?\n])) |> ascii_char([]))

  skip = ignore(repeat(choice([whitespace, comment])))

  identifier =
    ascii_char([?a..?z, ?A..?Z, ?_])
    |> repeat(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_]))
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:ident)

  integer_token =
    integer(min: 1)
    |> unwrap_and_tag(:int)

  string_char =
    choice([
      ignore(ascii_char([?\\])) |> ascii_char([]),
      ascii_char(not: ?")
    ])

  string_literal =
    ignore(ascii_char([?"]))
    |> repeat(string_char)
    |> ignore(ascii_char([?"]))
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:string)

  operator =
    choice([
      string(">=") |> replace({:op, :>=}),
      string("<=") |> replace({:op, :<=}),
      string("==") |> replace({:op, :==}),
      string("!=") |> replace({:op, :!=}),
      string("&&") |> replace({:op, :&&}),
      string("||") |> replace({:op, :||}),
      string(">") |> replace({:op, :>}),
      string("<") |> replace({:op, :<}),
      string("+") |> replace({:op, :+}),
      string("-") |> replace({:op, :-}),
      string("*") |> replace({:op, :*}),
      string("/") |> replace({:op, :/})
    ])

  punctuation =
    choice([
      string(",") |> replace({:punct, :comma}),
      string(";") |> replace({:punct, :semicolon}),
      string("(") |> replace({:punct, :lparen}),
      string(")") |> replace({:punct, :rparen}),
      string("{") |> replace({:punct, :lbrace}),
      string("}") |> replace({:punct, :rbrace})
    ])

  token =
    choice([
      identifier,
      integer_token,
      string_literal,
      operator,
      punctuation
    ])

  defparsecp(
    :lex,
    skip
    |> repeat(concat(token, skip))
    |> eos()
  )

  @spec tokenize(String.t()) :: {:ok, [token()]} | {:error, term()}
  def tokenize(input) when is_binary(input) do
    case lex(input) do
      {:ok, tokens, "", _, _, _} -> {:ok, tokens}
      {:ok, _, rest, _, _, _} -> {:error, {:unexpected_input, rest}}
      {:error, reason, rest, _, _, _} -> {:error, {reason, rest}}
    end
  end
end

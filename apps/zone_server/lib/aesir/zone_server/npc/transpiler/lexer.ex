defmodule Aesir.ZoneServer.Npc.Transpiler.Lexer do
  @moduledoc """
  Tokenizes an rAthena NPC script body into a flat token list.

  Extends the item-script lexer's token shapes with the full NPC language:
  scoped variables (`.@x`, `@x`, `#x`, `##x`, `$x`, `$@x`, `.x`, `'x`, with a
  `$` suffix marking string vars), hex integers, and the complete C-style
  operator set (ternary, compound assignment, increment/decrement, bitwise).

  Pure and resolution-free: bare identifiers (commands, constants, permanent
  char vars, labels) are all emitted as `{:ident, name}`; classifying them is
  the analyzer's job. Bodies from `FileParser` arrive comment-stripped, but
  `//` line and `/* … */` block comments are tolerated anyway — item `Script`
  bodies (which share this front end) arrive raw and do contain both.
  """

  import NimbleParsec

  @typedoc """
  A single lexical token.

  - `{:ident, name}` — bare identifier: command, constant, permanent char var
    (possibly `name$` for strings), or label name.
  - `{:var, scope, name, :int | :str}` — prefixed variable; `scope` is
    `:local` (`.@`), `:session` (`@`), `:account` (`#`), `:account_global`
    (`##`), `:server` (`$`), `:server_temp` (`$@`), `:npc` (`.`) or
    `:instance` (`'`).
  - `{:int, value}` — integer literal (decimal or `0x` hex).
  - `{:string, value}` — quoted string, escapes unescaped.
  - `{:op, op}` / `{:punct, punct}` — operator / punctuation.
  """
  @type token ::
          {:ident, String.t()}
          | {:var, atom(), String.t(), :int | :str}
          | {:int, integer()}
          | {:string, String.t()}
          | {:op, atom()}
          | {:punct, atom()}

  whitespace = ascii_char([?\s, ?\t, ?\n, ?\r, ?\v, ?\f])

  comment =
    string("//")
    |> repeat(lookahead_not(ascii_char([?\n])) |> ascii_char([]))

  block_comment =
    string("/*")
    |> repeat(lookahead_not(string("*/")) |> ascii_char([]))
    |> concat(string("*/"))

  skip = ignore(repeat(choice([whitespace, comment, block_comment])))

  name =
    ascii_char([?a..?z, ?A..?Z, ?_])
    |> repeat(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_]))
    |> reduce({List, :to_string, []})

  identifier =
    name
    |> optional(string("$"))
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:ident)

  scope_prefix =
    choice([
      string(".@") |> replace(:local),
      string("$@") |> replace(:server_temp),
      string("##") |> replace(:account_global),
      string("$") |> replace(:server),
      string("#") |> replace(:account),
      string(".") |> replace(:npc),
      string("'") |> replace(:instance),
      string("@") |> replace(:session)
    ])

  # Unlike bare identifiers, a prefixed var name may start with a digit
  # (e.g. `$2011_agit_invest`, `'1hmoon`).
  prefixed_name = ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 1)

  variable =
    scope_prefix
    |> concat(prefixed_name)
    |> optional(string("$") |> replace(:str))
    |> reduce(:build_var)

  defp build_var([scope, name]), do: {:var, scope, name, :int}
  defp build_var([scope, name, :str]), do: {:var, scope, name, :str}

  hex_integer =
    ignore(choice([string("0x"), string("0X")]))
    |> ascii_string([?0..?9, ?a..?f, ?A..?F], min: 1)
    |> map({String, :to_integer, [16]})
    |> unwrap_and_tag(:int)

  # rAthena constants may start with digits (e.g. the `4_DR_KID_01` sprite
  # constants); a digit run is only an identifier when letters/underscore
  # follow, so this must be tried after hex but before plain integers.
  digit_identifier =
    ascii_string([?0..?9], min: 1)
    |> ascii_char([?a..?z, ?A..?Z, ?_])
    |> repeat(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_]))
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:ident)

  integer_token = integer(min: 1) |> unwrap_and_tag(:int)

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

  @operators [
    {"<<=", :shl_assign},
    {">>=", :shr_assign},
    {"<<", :shl},
    {">>", :shr},
    {"<=", :<=},
    {">=", :>=},
    {"==", :==},
    {"!=", :!=},
    {"&&", :&&},
    {"||", :||},
    {"++", :inc},
    {"--", :dec},
    {"+=", :add_assign},
    {"-=", :sub_assign},
    {"*=", :mul_assign},
    {"/=", :div_assign},
    {"%=", :mod_assign},
    {"&=", :and_assign},
    {"|=", :or_assign},
    {"^=", :xor_assign},
    {"<", :<},
    {">", :>},
    {"+", :+},
    {"-", :-},
    {"*", :*},
    {"/", :/},
    {"%", :%},
    {"&", :&},
    {"|", :|},
    {"^", :^},
    {"!", :!},
    {"~", :bnot},
    {"=", :assign},
    {"?", :question}
  ]

  operator = choice(for {text, op} <- @operators, do: string(text) |> replace({:op, op}))

  punctuation =
    choice([
      string(",") |> replace({:punct, :comma}),
      string(";") |> replace({:punct, :semicolon}),
      string("(") |> replace({:punct, :lparen}),
      string(")") |> replace({:punct, :rparen}),
      string("{") |> replace({:punct, :lbrace}),
      string("}") |> replace({:punct, :rbrace}),
      string("[") |> replace({:punct, :lbracket}),
      string("]") |> replace({:punct, :rbracket}),
      string(":") |> replace({:punct, :colon})
    ])

  token =
    choice([
      variable,
      identifier,
      hex_integer,
      digit_identifier,
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
      {:ok, _, rest, _, _, _} -> {:error, {:unexpected_input, String.slice(rest, 0, 40)}}
      {:error, reason, rest, _, _, _} -> {:error, {reason, String.slice(rest, 0, 40)}}
    end
  end
end

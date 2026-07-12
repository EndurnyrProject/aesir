defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Parser do
  @moduledoc """
  Turns the `Lexer`'s flat token list into a tagged-tuple AST.

  Second stage of the rAthena item-script transpiler. A pure recursive-descent
  parser with no symbol resolution: identifiers are classified structurally and
  carried verbatim; mapping them to Aesir values is the resolver/codegen's job.

  Malformed or truncated token streams return `{:error, {:parse_error, term()}}`
  instead of raising — an unsupported/broken script is an expected outcome.

  ## Statement nodes

  - `{:call, name, args}` — a bare rAthena command call `name arg, arg, …;`,
    e.g. `{:call, "itemheal", [45, 0]}`. `name` is the verbatim identifier and
    `args` is a (possibly empty) list of expression nodes.
  - `{:if, cond, then_stmts, else_stmts}` — `cond` is an expression node;
    `then_stmts`/`else_stmts` are statement lists. A missing `else` yields `[]`.
    A single-statement branch is a one-element list; a `{ … }` block is the
    block's statement list.
  - `{:incr, name, delta}` — a post-increment/decrement on the permanent char
    variable `name`, `delta` being `1` (`Var++;`) or `-1` (`Var--;`).
  - `{:assign, name, expr}` — an assignment to the `.@`-scoped variable `name`,
    e.g. `{:assign, "r", {:call_expr, "getrefine", []}}` from `.@r = getrefine();`.

  ## Expression nodes

  - `integer()` — integer literal (negative literals come from a unary `-`).
  - `String.t()` — string literal.
  - `{:read, name}` — a known engine read (`BaseLevel`, `JobLevel`, `Class`,
    `Sex`, `Hp`, `MaxHp`, `Sp`, `MaxSp`, `Weight`, `Zeny`).
  - `{:const, name}` — any other bare identifier (rAthena constant such as
    `SC_BLESSING`, `Ele_Fire`, `Job_Knight`); the resolver classifies it later.
  - `{:var, name}` — a `.@`-scoped variable reference, e.g. `{:var, "r"}` from `.@r`.
  - `{:call_expr, name, args}` — an identifier immediately followed by `(`,
    e.g. `{:call_expr, "rand", [45, 65]}`.
  - `{:binop, op, lhs, rhs}` — arithmetic (`:+ :- :* :/`) and comparison
    (`:> :< :>= :<= :== :!=`) operators.
  - `{:logic, op, lhs, rhs}` — logical operators (`:&& :||`).

  ## Identifier classification

  A bare `{:ident, name}` becomes, in order: a `{:call_expr, …}` if the next
  token is `(`; a `{:read, name}` if `name` is in the fixed read-name set above;
  otherwise a `{:const, name}`.

  ## Precedence

  Lowest-to-highest binding: logical (`&& ||`) < comparison (`> < >= <= == !=`)
  < additive (`+ -`) < multiplicative (`* /`) < unary `-` < primary. All binary
  operators are left-associative.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Lexer

  @read_names ~w(BaseLevel JobLevel Class Sex Hp MaxHp Sp MaxSp Weight Zeny)

  @logic_ops [:&&, :||]
  @comparison_ops [:>, :<, :>=, :<=, :==, :!=]
  @additive_ops [:+, :-]
  @multiplicative_ops [:*, :/]

  @type expr ::
          integer()
          | String.t()
          | {:read, String.t()}
          | {:const, String.t()}
          | {:var, String.t()}
          | {:call_expr, String.t(), [expr()]}
          | {:binop, atom(), expr(), expr()}
          | {:logic, atom(), expr(), expr()}

  @type stmt ::
          {:call, String.t(), [expr()]}
          | {:if, expr(), [stmt()], [stmt()]}
          | {:incr, String.t(), 1 | -1}
          | {:assign, String.t(), expr()}

  @spec parse([Lexer.token()]) :: {:ok, [stmt()]} | {:error, {:parse_error, term()}}
  def parse(tokens) when is_list(tokens) do
    case parse_stmts(tokens, []) do
      {:ok, stmts, []} -> {:ok, stmts}
      {:ok, _stmts, [tok | _]} -> {:error, {:parse_error, {:unexpected_token, tok}}}
      {:error, reason} -> {:error, {:parse_error, reason}}
    end
  end

  @spec parse_stmts([Lexer.token()], [stmt()]) ::
          {:ok, [stmt()], [Lexer.token()]} | {:error, term()}
  defp parse_stmts([], acc), do: {:ok, Enum.reverse(acc), []}
  defp parse_stmts([{:punct, :rbrace} | _] = toks, acc), do: {:ok, Enum.reverse(acc), toks}

  defp parse_stmts(toks, acc) do
    with {:ok, stmts, rest} <- parse_stmt(toks) do
      parse_stmts(rest, Enum.reverse(stmts) ++ acc)
    end
  end

  @spec parse_stmt([Lexer.token()]) ::
          {:ok, [stmt()], [Lexer.token()]} | {:error, term()}
  defp parse_stmt([{:punct, :lbrace} | rest]) do
    with {:ok, stmts, rest2} <- parse_stmts(rest, []),
         {:ok, rest3} <- expect(rest2, {:punct, :rbrace}) do
      {:ok, stmts, rest3}
    end
  end

  defp parse_stmt([{:ident, "if"} | rest]), do: parse_if(rest)

  defp parse_stmt([{:ident, name}, {:op, :++} | rest]), do: parse_incr(name, 1, rest)
  defp parse_stmt([{:ident, name}, {:op, :--} | rest]), do: parse_incr(name, -1, rest)

  defp parse_stmt([{:scoped_var, name}, {:op, :=} | rest]) do
    with {:ok, expr, rest2} <- parse_expr(rest),
         {:ok, rest3} <- expect(rest2, {:punct, :semicolon}) do
      {:ok, [{:assign, name, expr}], rest3}
    end
  end

  defp parse_stmt([{:ident, name} | rest]) do
    with {:ok, args, rest2} <- parse_call_args(rest),
         {:ok, rest3} <- expect(rest2, {:punct, :semicolon}) do
      {:ok, [{:call, name, args}], rest3}
    end
  end

  defp parse_stmt([tok | _]), do: {:error, {:unexpected_token, tok}}
  defp parse_stmt([]), do: {:error, :unexpected_eof}

  @spec parse_incr(String.t(), 1 | -1, [Lexer.token()]) ::
          {:ok, [stmt()], [Lexer.token()]} | {:error, term()}
  defp parse_incr(name, delta, rest) do
    with {:ok, rest2} <- expect(rest, {:punct, :semicolon}) do
      {:ok, [{:incr, name, delta}], rest2}
    end
  end

  @spec parse_if([Lexer.token()]) :: {:ok, [stmt()], [Lexer.token()]} | {:error, term()}
  defp parse_if(toks) do
    with {:ok, rest1} <- expect(toks, {:punct, :lparen}),
         {:ok, cond_expr, rest2} <- parse_expr(rest1),
         {:ok, rest3} <- expect(rest2, {:punct, :rparen}),
         {:ok, then_stmts, rest4} <- parse_stmt(rest3),
         {:ok, else_stmts, rest5} <- parse_else(rest4) do
      {:ok, [{:if, cond_expr, then_stmts, else_stmts}], rest5}
    end
  end

  defp parse_else([{:ident, "else"} | rest]), do: parse_stmt(rest)
  defp parse_else(toks), do: {:ok, [], toks}

  @spec parse_call_args([Lexer.token()]) ::
          {:ok, [expr()], [Lexer.token()]} | {:error, term()}
  defp parse_call_args([{:punct, :semicolon} | _] = toks), do: {:ok, [], toks}
  defp parse_call_args(toks), do: parse_expr_list(toks)

  @spec parse_expr_list([Lexer.token()]) ::
          {:ok, [expr()], [Lexer.token()]} | {:error, term()}
  defp parse_expr_list(toks) do
    with {:ok, expr, rest} <- parse_expr(toks) do
      parse_expr_list_rest(expr, rest)
    end
  end

  defp parse_expr_list_rest(expr, [{:punct, :comma} | rest]) do
    with {:ok, more, rest2} <- parse_expr_list(rest) do
      {:ok, [expr | more], rest2}
    end
  end

  defp parse_expr_list_rest(expr, rest), do: {:ok, [expr], rest}

  @spec parse_expr([Lexer.token()]) :: {:ok, expr(), [Lexer.token()]} | {:error, term()}
  defp parse_expr(toks), do: parse_logic(toks)

  defp parse_logic(toks), do: parse_binary_level(toks, @logic_ops, :logic, &parse_comparison/1)

  defp parse_comparison(toks),
    do: parse_binary_level(toks, @comparison_ops, :binop, &parse_additive/1)

  defp parse_additive(toks),
    do: parse_binary_level(toks, @additive_ops, :binop, &parse_multiplicative/1)

  defp parse_multiplicative(toks),
    do: parse_binary_level(toks, @multiplicative_ops, :binop, &parse_unary/1)

  @spec parse_binary_level([Lexer.token()], [atom()], atom(), (... -> any())) ::
          {:ok, expr(), [Lexer.token()]} | {:error, term()}
  defp parse_binary_level(toks, ops, tag, next) do
    with {:ok, lhs, rest} <- next.(toks) do
      parse_binary_rest(lhs, rest, ops, tag, next)
    end
  end

  defp parse_binary_rest(lhs, [{:op, op} | rest], ops, tag, next) do
    if op in ops do
      with {:ok, rhs, rest2} <- next.(rest) do
        parse_binary_rest({tag, op, lhs, rhs}, rest2, ops, tag, next)
      end
    else
      {:ok, lhs, [{:op, op} | rest]}
    end
  end

  defp parse_binary_rest(lhs, rest, _ops, _tag, _next), do: {:ok, lhs, rest}

  @spec parse_unary([Lexer.token()]) :: {:ok, expr(), [Lexer.token()]} | {:error, term()}
  defp parse_unary([{:op, :-} | rest]) do
    with {:ok, expr, rest2} <- parse_unary(rest) do
      {:ok, negate(expr), rest2}
    end
  end

  defp parse_unary(toks), do: parse_primary(toks)

  defp negate(n) when is_integer(n), do: -n
  defp negate(expr), do: {:binop, :-, 0, expr}

  @spec parse_primary([Lexer.token()]) :: {:ok, expr(), [Lexer.token()]} | {:error, term()}
  defp parse_primary([{:int, n} | rest]), do: {:ok, n, rest}
  defp parse_primary([{:string, s} | rest]), do: {:ok, s, rest}

  defp parse_primary([{:punct, :lparen} | rest]) do
    with {:ok, expr, rest2} <- parse_expr(rest),
         {:ok, rest3} <- expect(rest2, {:punct, :rparen}) do
      {:ok, expr, rest3}
    end
  end

  defp parse_primary([{:ident, name}, {:punct, :lparen} | rest]) do
    with {:ok, args, rest2} <- parse_call_expr_args(rest),
         {:ok, rest3} <- expect(rest2, {:punct, :rparen}) do
      {:ok, {:call_expr, name, args}, rest3}
    end
  end

  defp parse_primary([{:scoped_var, name} | rest]), do: {:ok, {:var, name}, rest}

  defp parse_primary([{:ident, name} | rest]), do: {:ok, classify_ident(name), rest}
  defp parse_primary([tok | _]), do: {:error, {:unexpected_token, tok}}
  defp parse_primary([]), do: {:error, :unexpected_eof}

  defp parse_call_expr_args([{:punct, :rparen} | _] = toks), do: {:ok, [], toks}
  defp parse_call_expr_args(toks), do: parse_expr_list(toks)

  defp classify_ident(name) when name in @read_names, do: {:read, name}
  defp classify_ident(name), do: {:const, name}

  @spec expect([Lexer.token()], Lexer.token()) :: {:ok, [Lexer.token()]} | {:error, term()}
  defp expect([tok | rest], tok), do: {:ok, rest}
  defp expect([tok | _], expected), do: {:error, {:expected, expected, :got, tok}}
  defp expect([], expected), do: {:error, {:expected, expected, :got, :eof}}
end

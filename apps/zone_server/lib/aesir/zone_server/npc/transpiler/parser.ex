defmodule Aesir.ZoneServer.Npc.Transpiler.Parser do
  @moduledoc """
  Recursive-descent parser from `Lexer` tokens to an rAthena NPC script AST.

  Statements:

  - `{:cmd, name, args}` — command call, paren-less or parenthesized
  - `{:assign, target, expr}` — `set x, v`, `x = v`, compound ops and
    `++`/`--` are desugared into plain assignments
  - `{:block, stmts}`
  - `{:if, cond, then_stmts, else_stmts}`
  - `{:switch, expr, clauses}` — clauses are `{values | :default, stmts}`,
    where `values` is the list of case expressions sharing the body
    (fall-through cases are merged; a non-empty body falling through is kept
    as `{:fallthrough, values, stmts}`)
  - `{:while, cond, stmts}` / `{:do_while, stmts, cond}` /
    `{:for, init, cond, step, stmts}`
  - `{:break}` / `{:continue}`
  - `{:label, name}` / `{:goto, name}`
  - `{:menu, pairs}` — `{text_expr, label_name}` pairs
  - `{:return, expr | nil}`
  - `{:fn_decl, name}` / `{:function, name, stmts}` — script-local functions

  Expressions:

  - `{:int, n}` / `{:str, s}` — literals
  - `{:var, scope, name, type}` — prefixed variable reference
  - `{:name, name}` — bare identifier: constant, parameter or permanent char
    var (classified by the analyzer)
  - `{:call, name, args}` — parenthesized call
  - `{:index, base, index}` — array element
  - `{:neg, e}` / `{:not, e}` / `{:bnot, e}` — unary
  - `{:bin, op, l, r}` — binary op
  - `{:ternary, c, t, f}`

  All entry points return `{:ok, ast} | {:error, reason}`; nothing raises.
  """

  alias Aesir.ZoneServer.Npc.Transpiler.Lexer

  @type ast :: [tuple()]

  @doc "Tokenizes and parses a script body."
  @spec parse_body(String.t()) :: {:ok, ast()} | {:error, term()}
  def parse_body(source) do
    with {:ok, tokens} <- Lexer.tokenize(source) do
      parse(tokens)
    end
  end

  @doc "Parses a token list into a statement list."
  @spec parse([Lexer.token()]) :: {:ok, ast()} | {:error, term()}
  def parse(tokens) do
    case statements(tokens, []) do
      {:ok, stmts, []} -> {:ok, stmts}
      {:ok, _stmts, rest} -> {:error, unexpected(rest)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp unexpected(tokens), do: {:unexpected, Enum.take(tokens, 5)}

  # -- statements --------------------------------------------------------------

  defp statements(tokens, acc) do
    case tokens do
      [] -> {:ok, Enum.reverse(acc), []}
      [{:punct, :rbrace} | _] -> {:ok, Enum.reverse(acc), tokens}
      [{:ident, kw} | _] when kw in ~w(case default) -> {:ok, Enum.reverse(acc), tokens}
      _ -> with {:ok, stmt, rest} <- statement(tokens), do: statements(rest, add(stmt, acc))
    end
  end

  defp add(:empty, acc), do: acc
  defp add(stmt, acc), do: [stmt | acc]

  defp statement([{:punct, :semicolon} | rest]), do: {:ok, :empty, rest}

  defp statement([{:punct, :lbrace} | rest]) do
    with {:ok, stmts, rest} <- block_tail(rest), do: {:ok, {:block, stmts}, rest}
  end

  defp statement([{:ident, "if"} | rest]), do: if_statement(rest)
  defp statement([{:ident, "switch"} | rest]), do: switch_statement(rest)
  defp statement([{:ident, "while"} | rest]), do: while_statement(rest)
  defp statement([{:ident, "do"} | rest]), do: do_while_statement(rest)
  defp statement([{:ident, "for"} | rest]), do: for_statement(rest)
  defp statement([{:ident, "break"} | rest]), do: terminated({:break}, rest)
  defp statement([{:ident, "continue"} | rest]), do: terminated({:continue}, rest)
  defp statement([{:ident, "menu"} | rest]), do: menu_statement(rest)

  defp statement([{:ident, "goto"}, {:ident, label} | rest]),
    do: terminated({:goto, label}, rest)

  # Script-local functions: `function Name;` forward-declares, `function
  # Name { ... }` defines; calls use the plain `Name(args)` call syntax.
  defp statement([{:ident, "function"}, {:ident, name}, {:punct, :semicolon} | rest]),
    do: {:ok, {:fn_decl, name}, rest}

  defp statement([{:ident, "function"}, {:ident, name}, {:punct, :lbrace} | rest]) do
    with {:ok, stmts, rest} <- block_tail(rest), do: {:ok, {:function, name, stmts}, rest}
  end

  defp statement([{:ident, "return"}, {:punct, :semicolon} | rest]),
    do: {:ok, {:return, nil}, rest}

  defp statement([{:ident, "return"} | rest]) do
    with {:ok, expr, rest} <- expression(rest), do: terminated({:return, expr}, rest)
  end

  # `set <target>, <expr>;` is the legacy assignment command. The target is a
  # full expression: `set getelementofarray(...), v` occurs in the corpus.
  defp statement([{:ident, "set"} | rest]) do
    with {:ok, target, rest} <- expression(rest),
         {:ok, rest} <- expect(rest, {:punct, :comma}),
         {:ok, expr, rest} <- expression(rest) do
      terminated({:assign, target, expr}, rest)
    end
  end

  # A label: `Ident:` not followed by an expression context. Ternary `:` never
  # appears here because expressions are consumed as part of statements.
  defp statement([{:ident, name}, {:punct, :colon} | rest]), do: {:ok, {:label, name}, rest}

  defp statement([{:ident, _} | _] = tokens), do: assign_or_command(tokens)

  # A var-first statement is normally an assignment; a bare expression
  # statement (evaluated and discarded — corpus typos rely on it) is the
  # fallback.
  defp statement([{:var, _, _, _} | _] = tokens) do
    case assignment(tokens) do
      {:ok, _, _} = ok ->
        ok

      {:error, _} ->
        with {:ok, expr, rest} <- expression(tokens), do: terminated({:expr, expr}, rest)
    end
  end

  defp statement([{:op, :inc} | rest]), do: incdec(rest, :+)
  defp statement([{:op, :dec} | rest]), do: incdec(rest, :-)
  defp statement(tokens), do: {:error, unexpected(tokens)}

  @assign_ops [
    :assign,
    :inc,
    :dec,
    :add_assign,
    :sub_assign,
    :mul_assign,
    :div_assign,
    :mod_assign,
    :and_assign,
    :or_assign,
    :xor_assign,
    :shl_assign,
    :shr_assign
  ]

  # Distinguishes `x = v;` / `x[i] = v;` / `x++;` from a command statement
  # (`getitem 501,1;`) by looking at what follows the identifier.
  defp assign_or_command([{:ident, name} | rest] = tokens) do
    case skip_index(rest) do
      {:ok, [{:op, op} | _]} when op in @assign_ops -> assignment(tokens)
      _ -> command(name, rest)
    end
  end

  # Skips a `[...]` index (balanced brackets) after a variable name.
  defp skip_index([{:punct, :lbracket} | rest]), do: skip_brackets(rest, 1)
  defp skip_index(tokens), do: {:ok, tokens}

  defp skip_brackets([{:punct, :lbracket} | rest], depth), do: skip_brackets(rest, depth + 1)
  defp skip_brackets([{:punct, :rbracket} | rest], 1), do: {:ok, rest}
  defp skip_brackets([{:punct, :rbracket} | rest], depth), do: skip_brackets(rest, depth - 1)
  defp skip_brackets([_ | rest], depth), do: skip_brackets(rest, depth)
  defp skip_brackets([], _depth), do: :error

  defp assignment(tokens) do
    with {:ok, target, rest} <- assign_target(tokens) do
      assignment_op(target, rest)
    end
  end

  defp assignment_op(target, [{:op, :assign} | rest]), do: assign_rhs(target, rest)

  defp assignment_op(target, [{:op, :inc} | rest]),
    do: terminated({:assign, target, {:bin, :+, target, {:int, 1}}}, rest)

  defp assignment_op(target, [{:op, :dec} | rest]),
    do: terminated({:assign, target, {:bin, :-, target, {:int, 1}}}, rest)

  defp assignment_op(target, [{:op, op} | rest]) do
    case compound_op(op) do
      nil ->
        {:error, unexpected(rest)}

      bin_op ->
        with {:ok, expr, rest} <- expression(rest),
             do: terminated({:assign, target, {:bin, bin_op, target, expr}}, rest)
    end
  end

  defp assignment_op(_target, tokens), do: {:error, unexpected(tokens)}

  # Right-associative chained assignment (`a = b = 0`) desugars to a block:
  # innermost first, then each outer target copies from the inner one.
  defp assign_rhs(target, tokens) do
    with {:ok, inner_target, [{:op, :assign} | rest]} <- assign_target(tokens),
         {:ok, inner, rest} <- assign_rhs(inner_target, rest) do
      {:ok, {:block, [inner, {:assign, target, inner_target}]}, rest}
    else
      _ ->
        with {:ok, expr, rest} <- expression(tokens),
             do: terminated({:assign, target, expr}, rest)
    end
  end

  defp compound_op(:add_assign), do: :+
  defp compound_op(:sub_assign), do: :-
  defp compound_op(:mul_assign), do: :*
  defp compound_op(:div_assign), do: :/
  defp compound_op(:mod_assign), do: :%
  defp compound_op(:and_assign), do: :&
  defp compound_op(:or_assign), do: :|
  defp compound_op(:xor_assign), do: :^
  defp compound_op(:shl_assign), do: :shl
  defp compound_op(:shr_assign), do: :shr
  defp compound_op(_), do: nil

  # `++.@i;` / `--.@i;` prefix form.
  defp incdec(tokens, op) do
    with {:ok, target, rest} <- assign_target(tokens),
         do: terminated({:assign, target, {:bin, op, target, {:int, 1}}}, rest)
  end

  # An assignment target: a prefixed var, a bare name, optionally indexed.
  # Unlike expression postfix handling, the trailing `++`/`--` is left for the
  # assignment parser to consume.
  defp assign_target([{:var, scope, name, type} | rest]),
    do: target_index({:var, scope, name, type}, rest)

  defp assign_target([{:ident, name} | rest]), do: target_index({:name, name}, rest)
  defp assign_target(tokens), do: {:error, unexpected(tokens)}

  defp target_index(base, [{:punct, :lbracket} | rest]) do
    with {:ok, index, rest} <- expression(rest),
         {:ok, rest} <- expect(rest, {:punct, :rbracket}) do
      {:ok, {:index, base, index}, rest}
    end
  end

  defp target_index(base, rest), do: {:ok, base, rest}

  defp maybe_index(base, [{:punct, :lbracket} | rest]) do
    with {:ok, index, rest} <- expression(rest),
         {:ok, rest} <- expect(rest, {:punct, :rbracket}) do
      maybe_postfix({:index, base, index}, rest)
    end
  end

  defp maybe_index(base, rest), do: maybe_postfix(base, rest)

  # Postfix `++`/`--` in expression position (`.@arr[.@i++]`).
  defp maybe_postfix(base, [{:op, :inc} | rest]), do: {:ok, {:post_inc, base}, rest}
  defp maybe_postfix(base, [{:op, :dec} | rest]), do: {:ok, {:post_dec, base}, rest}
  defp maybe_postfix(base, rest), do: {:ok, base, rest}

  # A command statement: `name arg, arg;`, `name(arg, arg);` or bare `name;`.
  defp command(name, [{:punct, :semicolon} | rest]), do: {:ok, {:cmd, name, []}, rest}
  defp command(name, [{:punct, :rbrace} | _] = rest), do: {:ok, {:cmd, name, []}, rest}

  defp command(name, [{:punct, :lparen} | _] = tokens) do
    # Try the call form (`getitem(501,1);`) first; when the parens turn out to
    # only wrap the first argument of a larger expression
    # (`emotion (Zeny > 50) ? ET_MONEY : ET_HUK;`), back off and parse the
    # whole tail as an argument list.
    case call_command(name, tokens) do
      {:ok, _, _} = ok ->
        ok

      {:error, _} ->
        with {:ok, args, rest} <- expression_list(tokens),
             do: terminated({:cmd, name, args}, rest)
    end
  end

  defp command(name, tokens) do
    with {:ok, args, rest} <- expression_list(tokens),
         do: terminated({:cmd, name, args}, rest)
  end

  defp call_command(name, tokens) do
    with {:ok, {:call, ^name, args}, rest} <- call_expression(name, tokens) do
      call_command_tail(name, args, rest)
    end
  end

  defp call_command_tail(name, args, [{:punct, :comma} | more]) do
    with {:ok, more_args, rest} <- expression_list(more),
         do: terminated({:cmd, name, [wrap_call(name, args) | more_args]}, rest)
  end

  defp call_command_tail(name, args, rest), do: terminated({:cmd, name, args}, rest)

  # `cmd (expr), more` is a parenthesized first argument, not a call.
  defp wrap_call(_name, [single]), do: single
  defp wrap_call(name, args), do: {:call, name, args}

  defp expression_list(tokens) do
    with {:ok, expr, rest} <- expression(tokens) do
      expression_list_tail(expr, rest)
    end
  end

  defp expression_list_tail(expr, [{:punct, :comma} | more]) do
    with {:ok, exprs, rest} <- expression_list(more), do: {:ok, [expr | exprs], rest}
  end

  defp expression_list_tail(expr, rest), do: {:ok, [expr], rest}

  # A statement terminator: `;`, or leniently a following `}` / `)` / `,`
  # (for-loop clauses, left unconsumed) / end of input.
  defp terminated(stmt, [{:punct, :semicolon} | rest]), do: {:ok, stmt, rest}
  defp terminated(stmt, [{:punct, :rbrace} | _] = rest), do: {:ok, stmt, rest}
  defp terminated(stmt, [{:punct, :rparen} | _] = rest), do: {:ok, stmt, rest}
  defp terminated(stmt, [{:punct, :comma} | _] = rest), do: {:ok, stmt, rest}
  defp terminated(stmt, []), do: {:ok, stmt, []}
  defp terminated(_stmt, tokens), do: {:error, unexpected(tokens)}

  defp expect([token | rest], token), do: {:ok, rest}
  defp expect(tokens, expected), do: {:error, {:expected, expected, unexpected(tokens)}}

  # -- control flow ------------------------------------------------------------

  defp block_tail(tokens) do
    with {:ok, stmts, rest} <- statements(tokens, []),
         {:ok, rest} <- expect(rest, {:punct, :rbrace}) do
      {:ok, stmts, rest}
    end
  end

  defp if_statement(tokens) do
    with {:ok, rest} <- expect(tokens, {:punct, :lparen}),
         {:ok, cond_expr, rest} <- expression(rest),
         {:ok, rest} <- expect(rest, {:punct, :rparen}),
         {:ok, then_stmts, rest} <- branch(rest) do
      else_branch(cond_expr, then_stmts, rest)
    end
  end

  defp else_branch(cond_expr, then_stmts, [{:ident, "else"} | rest]) do
    with {:ok, else_stmts, rest} <- branch(rest),
         do: {:ok, {:if, cond_expr, then_stmts, else_stmts}, rest}
  end

  defp else_branch(cond_expr, then_stmts, rest),
    do: {:ok, {:if, cond_expr, then_stmts, []}, rest}

  # A branch body: a block or a single statement, normalized to a list.
  defp branch([{:punct, :lbrace} | rest]), do: block_tail(rest)

  defp branch(tokens) do
    with {:ok, stmt, rest} <- statement(tokens), do: {:ok, List.wrap(unblock(stmt)), rest}
  end

  defp unblock(:empty), do: []
  defp unblock({:block, stmts}), do: stmts
  defp unblock(stmt), do: [stmt]

  defp while_statement(tokens) do
    with {:ok, rest} <- expect(tokens, {:punct, :lparen}),
         {:ok, cond_expr, rest} <- expression(rest),
         {:ok, rest} <- expect(rest, {:punct, :rparen}),
         {:ok, body, rest} <- branch(rest) do
      {:ok, {:while, cond_expr, body}, rest}
    end
  end

  defp do_while_statement(tokens) do
    with {:ok, body, rest} <- branch(tokens),
         {:ok, rest} <- expect(rest, {:ident, "while"}),
         {:ok, rest} <- expect(rest, {:punct, :lparen}),
         {:ok, cond_expr, rest} <- expression(rest),
         {:ok, rest} <- expect(rest, {:punct, :rparen}) do
      terminated({:do_while, body, cond_expr}, rest)
    end
  end

  defp for_statement(tokens) do
    with {:ok, rest} <- expect(tokens, {:punct, :lparen}),
         {:ok, init, rest} <- for_clause(rest, {:punct, :semicolon}),
         {:ok, cond_expr, rest} <- expression(rest),
         {:ok, rest} <- expect(rest, {:punct, :semicolon}),
         {:ok, step, rest} <- for_clause(rest, {:punct, :rparen}),
         {:ok, rest} <- expect(rest, {:punct, :rparen}),
         {:ok, body, rest} <- branch(rest) do
      {:ok, {:for, init, cond_expr, step, body}, rest}
    end
  end

  # An init/step clause: comma-separated assignments (C comma operator) up to
  # `stop`, which is left unconsumed for `;`-vs-`)` symmetry with the caller —
  # except the init's own `;`, which `statement/1` consumes via `terminated`.
  defp for_clause([stop | _] = rest, stop), do: {:ok, [], rest}

  defp for_clause(tokens, stop) do
    with {:ok, stmt, rest} <- statement(tokens) do
      for_clause_tail(stmt, rest, stop)
    end
  end

  defp for_clause_tail(stmt, [{:punct, :comma} | more], stop) do
    with {:ok, stmts, rest} <- for_clause(more, stop),
         do: {:ok, unblock(stmt) ++ stmts, rest}
  end

  defp for_clause_tail(stmt, rest, _stop), do: {:ok, unblock(stmt), rest}

  defp switch_statement(tokens) do
    with {:ok, rest} <- expect(tokens, {:punct, :lparen}),
         {:ok, expr, rest} <- expression(rest),
         {:ok, rest} <- expect(rest, {:punct, :rparen}),
         {:ok, rest} <- expect(rest, {:punct, :lbrace}),
         {:ok, clauses, rest} <- switch_clauses(rest, []) do
      {:ok, {:switch, expr, clauses}, rest}
    end
  end

  defp switch_clauses([{:punct, :rbrace} | rest], acc), do: {:ok, Enum.reverse(acc), rest}

  # Statements before the first `case` are dead code rAthena tolerates
  # (they exist in the corpus); parse and drop them.
  defp switch_clauses([token | _] = tokens, [] = acc)
       when token != {:ident, "case"} and token != {:ident, "default"} do
    with {:ok, _dead, rest} <- statements(tokens, []), do: switch_clauses(rest, acc)
  end

  defp switch_clauses(tokens, acc) do
    with {:ok, values, rest} <- case_values(tokens, []),
         {:ok, stmts, rest} <- statements(rest, []) do
      switch_clauses(rest, [{values, stmts} | acc])
    end
  end

  # Collects consecutive `case v:` labels (and `default:`) sharing one body.
  defp case_values([{:ident, "case"} | rest], acc) do
    with {:ok, value, rest} <- expression(rest),
         {:ok, rest} <- expect(rest, {:punct, :colon}) do
      case_values(rest, [value | acc])
    end
  end

  defp case_values([{:ident, "default"}, {:punct, :colon} | rest], acc),
    do: case_values(rest, [:default | acc])

  defp case_values(tokens, []), do: {:error, unexpected(tokens)}
  defp case_values(tokens, acc), do: {:ok, Enum.reverse(acc), tokens}

  defp menu_statement(tokens) do
    with {:ok, args, rest} <- expression_list(tokens),
         {:ok, pairs} <- menu_pairs(args, []) do
      terminated({:menu, pairs}, rest)
    end
  end

  defp menu_pairs([], acc), do: {:ok, Enum.reverse(acc)}

  defp menu_pairs([text, {:name, label} | rest], acc),
    do: menu_pairs(rest, [{text, label} | acc])

  defp menu_pairs(args, _acc), do: {:error, {:bad_menu_args, args}}

  # -- expressions -------------------------------------------------------------

  # Precedence climbing, C-like levels; ternary is lowest and right-associative.
  @levels [
    [:||],
    [:&&],
    [:|],
    [:^],
    [:&],
    [:==, :!=],
    [:<, :<=, :>, :>=],
    [:shl, :shr],
    [:+, :-],
    [:*, :/, :%]
  ]

  defp expression(tokens), do: ternary(tokens)

  defp ternary(tokens) do
    with {:ok, cond_expr, rest} <- binary(tokens, 0) do
      ternary_tail(cond_expr, rest)
    end
  end

  defp ternary_tail(cond_expr, [{:op, :question} | rest]) do
    with {:ok, then_expr, rest} <- ternary(rest),
         {:ok, rest} <- expect(rest, {:punct, :colon}),
         {:ok, else_expr, rest} <- ternary(rest) do
      {:ok, {:ternary, cond_expr, then_expr, else_expr}, rest}
    end
  end

  defp ternary_tail(cond_expr, rest), do: {:ok, cond_expr, rest}

  defp binary(tokens, level) when level >= length(@levels), do: unary(tokens)

  defp binary(tokens, level) do
    with {:ok, left, rest} <- binary(tokens, level + 1) do
      binary_tail(left, rest, level)
    end
  end

  defp binary_tail(left, [{:op, op} | rest] = tokens, level) do
    if op in Enum.at(@levels, level) do
      with {:ok, right, rest} <- binary(rest, level + 1) do
        binary_tail({:bin, op, left, right}, rest, level)
      end
    else
      {:ok, left, tokens}
    end
  end

  defp binary_tail(left, tokens, _level), do: {:ok, left, tokens}

  defp unary([{:op, :-} | rest]) do
    with {:ok, expr, rest} <- unary(rest), do: {:ok, {:neg, expr}, rest}
  end

  defp unary([{:op, :!} | rest]) do
    with {:ok, expr, rest} <- unary(rest), do: {:ok, {:not, expr}, rest}
  end

  defp unary([{:op, :bnot} | rest]) do
    with {:ok, expr, rest} <- unary(rest), do: {:ok, {:bnot, expr}, rest}
  end

  defp unary(tokens), do: primary(tokens)

  defp primary([{:int, n} | rest]), do: {:ok, {:int, n}, rest}
  defp primary([{:string, s} | rest]), do: {:ok, {:str, s}, rest}

  defp primary([{:var, scope, name, type} | rest]),
    do: maybe_index({:var, scope, name, type}, rest)

  defp primary([{:ident, name}, {:punct, :lparen} | rest]),
    do: call_expression(name, [{:punct, :lparen} | rest])

  defp primary([{:ident, name} | rest]), do: maybe_index({:name, name}, rest)

  defp primary([{:punct, :lparen} | rest]) do
    with {:ok, expr, rest} <- expression(rest),
         {:ok, rest} <- expect(rest, {:punct, :rparen}) do
      {:ok, expr, rest}
    end
  end

  defp primary(tokens), do: {:error, unexpected(tokens)}

  # `name(...)` — tokens start at the `(`.
  defp call_expression(name, [{:punct, :lparen}, {:punct, :rparen} | rest]),
    do: {:ok, {:call, name, []}, rest}

  defp call_expression(name, [{:punct, :lparen} | rest]) do
    with {:ok, args, rest} <- expression_list(rest),
         {:ok, rest} <- expect(rest, {:punct, :rparen}) do
      {:ok, {:call, name, args}, rest}
    end
  end
end

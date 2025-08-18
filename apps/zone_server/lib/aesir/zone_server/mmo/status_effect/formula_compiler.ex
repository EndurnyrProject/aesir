defmodule Aesir.ZoneServer.Mmo.StatusEffect.FormulaCompiler do
  @moduledoc """
  Compiles formula strings into executable functions using NimbleParsec.

  Formulas are parsed at startup and compiled into native Elixir functions
  for efficient runtime execution using quote-based compilation.
  """

  import NimbleParsec
  require Logger

  alias Aesir.ZoneServer.Mmo.StatusEffect.GameFunctions

  # Built-in math functions
  @builtin_functions ~w(min max floor ceil abs)

  @doc """
  Compile a formula string into an executable function.

  ## Supported variables:
    - `max_hp`, `max_sp` - Target's maximum HP/SP
    - `hp`, `sp` - Target's current HP/SP
    - `level` - Target's level
    - `str`, `agi`, `vit`, `int`, `dex`, `luk` - Target's stats
    - `val1`, `val2`, `val3`, `val4` - Status effect values
    - `caster.X` - Caster's properties (if available)
    - `state.X` - Instance state values

  ## Supported operations:
    - Basic math: +, -, *, /, %
    - Comparisons: <, >, <=, >=, ==, !=
    - Logic: and, or, not
    - Functions: min, max, floor, ceil, abs
  """
  def compile(formula) when is_binary(formula) do
    case parse(formula) do
      {:ok, [ast], "", _, _, _} ->
        quoted = compile_to_quoted(ast)

        # Return a function that evaluates the quoted expression
        fn context ->
          {result, _} = Code.eval_quoted(quoted, context: context)
          result
        end

      {:ok, _, rest, _, _, _} ->
        Logger.error("Failed to parse complete formula: #{formula}, unparsed: #{rest}")
        fn _context -> 0 end

      {:error, reason, _, _, _, _} ->
        Logger.error("Failed to parse formula: #{formula}, error: #{inspect(reason)}")
        fn _context -> 0 end
    end
  end

  def compile(nil), do: fn _context -> 0 end
  def compile(value) when is_number(value), do: fn _context -> value end

  # Parser combinators using NimbleParsec
  # We build from the bottom up to avoid forward references

  # Whitespace helpers
  ws = ascii_string([?\s, ?\t, ?\n, ?\r], min: 1) |> ignore()
  optional_ws = optional(ws)

  # Numbers - optimized to detect integers vs floats
  integer =
    optional(string("-"))
    |> ascii_string([?0..?9], min: 1)
    |> reduce(:parse_integer)
    |> unwrap_and_tag(:num)

  float =
    optional(string("-"))
    |> ascii_string([?0..?9], min: 1)
    |> string(".")
    |> ascii_string([?0..?9], min: 1)
    |> reduce(:parse_float)
    |> unwrap_and_tag(:num)

  number = choice([float, integer])

  # Variables - pre-parse paths to atom lists
  variable =
    ascii_string([?a..?z, ?A..?Z, ?_], min: 1)
    |> repeat(
      choice([
        ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 1),
        string(".") |> concat(ascii_string([?a..?z, ?A..?Z, ?_], min: 1))
      ])
    )
    |> reduce(:parse_variable_path)
    |> unwrap_and_tag(:var)

  # Function names - now accepts any valid identifier
  function_name =
    ascii_string([?a..?z, ?A..?Z, ?_], min: 1)
    |> repeat(ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 1))
    |> reduce(:join_function_name)

  # Primary expressions (before function calls to avoid circular ref)
  defcombinatorp(
    :primary_no_func,
    choice([
      number,
      variable,
      ignore(string("("))
      |> concat(optional_ws)
      |> parsec(:expression)
      |> concat(optional_ws)
      |> ignore(string(")"))
    ])
  )

  # Function calls (uses expression)
  defcombinatorp(
    :function_call,
    function_name
    |> concat(optional_ws)
    |> ignore(string("("))
    |> concat(optional_ws)
    |> parsec(:expression)
    |> repeat(
      optional_ws
      |> ignore(string(","))
      |> concat(optional_ws)
      |> parsec(:expression)
    )
    |> concat(optional_ws)
    |> ignore(string(")"))
    |> reduce(:build_function_call)
  )

  # Primary with functions
  defcombinatorp(
    :primary,
    choice([
      parsec(:function_call),
      parsec(:primary_no_func)
    ])
  )

  # Unary expressions
  defcombinatorp(
    :unary,
    choice([
      string("not")
      |> replace(:not)
      |> concat(ws)
      |> parsec(:primary)
      |> reduce(:build_unary),
      string("-")
      |> replace(:neg)
      |> concat(optional_ws)
      |> parsec(:primary)
      |> reduce(:build_unary),
      parsec(:primary)
    ])
  )

  # Multiplicative operators
  mult_op =
    choice([
      string("*") |> replace(:mul),
      string("/") |> replace(:div),
      string("%") |> replace(:mod)
    ])

  # Multiplicative expressions
  defcombinatorp(
    :multiplicative,
    parsec(:unary)
    |> repeat(
      optional_ws
      |> concat(mult_op)
      |> concat(optional_ws)
      |> parsec(:unary)
    )
    |> reduce(:build_left_assoc)
  )

  # Additive operators
  add_op =
    choice([
      string("+") |> replace(:add),
      string("-") |> replace(:sub)
    ])

  # Additive expressions
  defcombinatorp(
    :additive,
    parsec(:multiplicative)
    |> repeat(
      optional_ws
      |> concat(add_op)
      |> concat(optional_ws)
      |> parsec(:multiplicative)
    )
    |> reduce(:build_left_assoc)
  )

  # Comparison operators
  comp_op =
    choice([
      string("<=") |> replace(:lte),
      string(">=") |> replace(:gte),
      string("==") |> replace(:eq),
      string("!=") |> replace(:neq),
      string("<") |> replace(:lt),
      string(">") |> replace(:gt)
    ])

  # Comparison expressions
  defcombinatorp(
    :comparison,
    parsec(:additive)
    |> optional(
      optional_ws
      |> concat(comp_op)
      |> concat(optional_ws)
      |> parsec(:additive)
    )
    |> reduce(:build_comparison)
  )

  # Logical AND
  defcombinatorp(
    :logical_and,
    parsec(:comparison)
    |> repeat(
      optional_ws
      |> ignore(string("and"))
      |> concat(ws)
      |> parsec(:comparison)
    )
    |> reduce(:build_and)
  )

  # Logical OR (top level expression)
  defcombinatorp(
    :expression,
    parsec(:logical_and)
    |> repeat(
      optional_ws
      |> ignore(string("or"))
      |> concat(ws)
      |> parsec(:logical_and)
    )
    |> reduce(:build_or)
  )

  # Root parser
  defparsec(
    :parse,
    optional_ws
    |> parsec(:expression)
    |> concat(optional_ws)
    |> eos()
  )

  # Helper functions for building AST

  defp parse_integer(parts) do
    parts
    |> Enum.join()
    |> String.to_integer()
  end

  defp parse_float(parts) do
    parts
    |> Enum.join()
    |> Float.parse()
    |> elem(0)
  end

  # Pre-parse variable paths to atom lists for efficiency
  defp parse_variable_path(parts) do
    parts
    |> Enum.join()
    |> String.split(".")
    |> Enum.map(&String.to_atom/1)
  end

  defp join_function_name(parts) do
    Enum.join(parts)
  end

  defp build_function_call([func | args]) do
    {:func, func, args}
  end

  defp build_unary([op, expr]) do
    {op, expr}
  end

  defp build_left_assoc([first | rest]) do
    Enum.chunk_every(rest, 2)
    |> Enum.reduce(first, fn [op, right], left ->
      {op, left, right}
    end)
  end

  defp build_comparison([left, op, right]) do
    {op, left, right}
  end

  defp build_comparison([expr]), do: expr

  defp build_and([first | rest]) do
    case rest do
      [] -> first
      _ -> Enum.reduce(rest, first, fn right, left -> {:and, left, right} end)
    end
  end

  defp build_or([first | rest]) do
    case rest do
      [] -> first
      _ -> Enum.reduce(rest, first, fn right, left -> {:or, left, right} end)
    end
  end

  # Quote-based compilation functions
  # Transform AST directly to quoted Elixir expressions

  defp compile_to_quoted({:num, n}) when is_integer(n) do
    n
  end

  defp compile_to_quoted({:num, n}) when is_float(n) do
    n
  end

  defp compile_to_quoted({:var, path}) when is_list(path) do
    # Special handling for 'caster' and 'target' as standalone variables
    # These should resolve to the atom :caster or :target for function calls
    case path do
      [:caster] ->
        quote do: :caster

      [:target] ->
        quote do: :target

      [:source] ->
        quote do: :source

      _ ->
        quote do
          get_in(var!(context), unquote(path)) || 0
        end
    end
  end

  defp compile_to_quoted({:add, left, right}) do
    left_quoted = compile_to_quoted(left)
    right_quoted = compile_to_quoted(right)

    quote do
      unquote(left_quoted) + unquote(right_quoted)
    end
  end

  defp compile_to_quoted({:sub, left, right}) do
    left_quoted = compile_to_quoted(left)
    right_quoted = compile_to_quoted(right)

    quote do
      unquote(left_quoted) - unquote(right_quoted)
    end
  end

  defp compile_to_quoted({:mul, left, right}) do
    left_quoted = compile_to_quoted(left)
    right_quoted = compile_to_quoted(right)

    quote do
      unquote(left_quoted) * unquote(right_quoted)
    end
  end

  defp compile_to_quoted({:div, left, right}) do
    left_quoted = compile_to_quoted(left)
    right_quoted = compile_to_quoted(right)

    quote do
      divisor = unquote(right_quoted)
      if divisor == 0, do: 0, else: unquote(left_quoted) / divisor
    end
  end

  defp compile_to_quoted({:mod, left, right}) do
    left_quoted = compile_to_quoted(left)
    right_quoted = compile_to_quoted(right)

    quote do
      divisor = unquote(right_quoted)
      if divisor == 0, do: 0, else: rem(trunc(unquote(left_quoted)), trunc(divisor))
    end
  end

  defp compile_to_quoted({:neg, expr}) do
    expr_quoted = compile_to_quoted(expr)

    quote do
      -unquote(expr_quoted)
    end
  end

  defp compile_to_quoted({:not, expr}) do
    expr_quoted = compile_to_quoted(expr)

    quote do
      if unquote(expr_quoted) == 0, do: 1, else: 0
    end
  end

  defp compile_to_quoted({:lt, left, right}) do
    left_quoted = compile_to_quoted(left)
    right_quoted = compile_to_quoted(right)

    quote do
      if unquote(left_quoted) < unquote(right_quoted), do: 1, else: 0
    end
  end

  defp compile_to_quoted({:gt, left, right}) do
    left_quoted = compile_to_quoted(left)
    right_quoted = compile_to_quoted(right)

    quote do
      if unquote(left_quoted) > unquote(right_quoted), do: 1, else: 0
    end
  end

  defp compile_to_quoted({:lte, left, right}) do
    left_quoted = compile_to_quoted(left)
    right_quoted = compile_to_quoted(right)

    quote do
      if unquote(left_quoted) <= unquote(right_quoted), do: 1, else: 0
    end
  end

  defp compile_to_quoted({:gte, left, right}) do
    left_quoted = compile_to_quoted(left)
    right_quoted = compile_to_quoted(right)

    quote do
      if unquote(left_quoted) >= unquote(right_quoted), do: 1, else: 0
    end
  end

  defp compile_to_quoted({:eq, left, right}) do
    left_quoted = compile_to_quoted(left)
    right_quoted = compile_to_quoted(right)

    quote do
      if unquote(left_quoted) == unquote(right_quoted), do: 1, else: 0
    end
  end

  defp compile_to_quoted({:neq, left, right}) do
    left_quoted = compile_to_quoted(left)
    right_quoted = compile_to_quoted(right)

    quote do
      if unquote(left_quoted) != unquote(right_quoted), do: 1, else: 0
    end
  end

  defp compile_to_quoted({:and, left, right}) do
    left_quoted = compile_to_quoted(left)
    right_quoted = compile_to_quoted(right)

    quote do
      if unquote(left_quoted) != 0 and unquote(right_quoted) != 0, do: 1, else: 0
    end
  end

  defp compile_to_quoted({:or, left, right}) do
    left_quoted = compile_to_quoted(left)
    right_quoted = compile_to_quoted(right)

    quote do
      if unquote(left_quoted) != 0 or unquote(right_quoted) != 0, do: 1, else: 0
    end
  end

  # Handle function calls - both built-in and custom
  defp compile_to_quoted({:func, name, args}) when is_binary(name) do
    if name in @builtin_functions do
      compile_builtin_function(name, args)
    else
      compile_custom_function(name, args)
    end
  end

  # Legacy support for atom function names (if any exist)
  defp compile_to_quoted({:func, name, args}) when is_atom(name) do
    compile_to_quoted({:func, Atom.to_string(name), args})
  end

  # Fallback for unrecognized expressions
  defp compile_to_quoted(_), do: quote(do: 0)

  defp compile_builtin_function("min", [a, b]) do
    a_quoted = compile_to_quoted(a)
    b_quoted = compile_to_quoted(b)

    quote do
      min(unquote(a_quoted), unquote(b_quoted))
    end
  end

  defp compile_builtin_function("max", [a, b]) do
    a_quoted = compile_to_quoted(a)
    b_quoted = compile_to_quoted(b)

    quote do
      max(unquote(a_quoted), unquote(b_quoted))
    end
  end

  defp compile_builtin_function("floor", [a]) do
    a_quoted = compile_to_quoted(a)

    quote do
      Float.floor(unquote(a_quoted) * 1.0)
    end
  end

  defp compile_builtin_function("ceil", [a]) do
    a_quoted = compile_to_quoted(a)

    quote do
      Float.ceil(unquote(a_quoted) * 1.0)
    end
  end

  defp compile_builtin_function("abs", [a]) do
    a_quoted = compile_to_quoted(a)

    quote do
      abs(unquote(a_quoted))
    end
  end

  defp compile_builtin_function(name, args) do
    raise CompileError,
      description:
        "Built-in function #{name} called with wrong number of arguments: #{length(args)}"
  end

  defp compile_custom_function(name, args) do
    registry = GameFunctions.registry()

    case Map.get(registry, name) do
      {module, fun, expected_arity} ->
        actual_arity = length(args || [])

        if actual_arity != expected_arity do
          raise CompileError,
            description:
              "Function #{name}/#{actual_arity} has incorrect arity, expected #{expected_arity}"
        end

        compiled_args = Enum.map(args || [], &compile_to_quoted/1)

        quote do
          apply(unquote(module), unquote(fun), [var!(context) | unquote(compiled_args)])
        end

      nil ->
        raise CompileError,
          description: "Undefined function: #{name}/#{length(args || [])}"
    end
  end
end

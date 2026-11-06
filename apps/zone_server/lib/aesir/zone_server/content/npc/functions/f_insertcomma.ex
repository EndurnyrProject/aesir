defmodule Aesir.ZoneServer.Content.Npc.Functions.FInsertcomma do
  @moduledoc """
  Inserts a comma between every three digits of a number.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @doc """
  Callable rAthena global function `F_InsertComma(number)`; returns the digits with a comma every
  three places.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), term()}
  def call(ctx, args) do
    digits = Enum.at(args, 0, 0)

    comma_positions =
      digits
      |> Rathena.getstrlen()
      |> Kernel.-(3)
      |> Stream.iterate(&(&1 - 3))
      |> Enum.take_while(&(&1 > 0))

    {ctx, Enum.reduce(comma_positions, digits, &Rathena.insertchar(&2, ",", &1))}
  end
end

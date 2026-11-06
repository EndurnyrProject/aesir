defmodule Aesir.ZoneServer.Content.Npc.Functions.FGetnumsuffix do
  @moduledoc """
  Appends the ordinal suffix that matches a number.

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
  Callable rAthena global function `F_GetNumSuffix(number)`; returns the number with `-st`, `-nd`,
  `-rd` or `-th` appended.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), String.t()}
  def call(ctx, args) do
    number = Enum.at(args, 0, 0)

    suffix =
      case rem(number, 10) do
        1 when number != 11 -> "st"
        2 when number != 12 -> "nd"
        3 when number != 13 -> "rd"
        _other -> "th"
      end

    {ctx, Rathena.concat(number, suffix)}
  end
end

defmodule Aesir.ZoneServer.Content.Npc.Functions.FInsertplural do
  @moduledoc """
  Formats a count and a noun, pluralizing the noun unless the count is one.

  ## Behavior

  The template defaults to `"%d %s"` and receives the count followed by the noun. The noun is
  uppercased when the third argument is non-zero, and is left untouched for a count of one.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  alias Aesir.ZoneServer.Content.Npc.Functions.FGetplural
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @doc """
  Callable rAthena global function `F_InsertPlural(count, noun, uppercase, template)`; returns the
  formatted string.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), String.t()}
  def call(ctx, args) do
    count = Enum.at(args, 0, 0)
    noun = Enum.at(args, 1, 0)

    {ctx, plural} = FGetplural.call(ctx, [noun, Enum.at(args, 2, 0)])

    {ctx,
     Rathena.format(Enum.at(args, 3, "%d %s"), [count, if(count == 1, do: noun, else: plural)])}
  end
end

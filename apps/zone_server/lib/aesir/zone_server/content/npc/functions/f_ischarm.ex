defmodule Aesir.ZoneServer.Content.Npc.Functions.FIscharm do
  @moduledoc """
  Reports whether an item id belongs to an enchant card.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @doc """
  Callable rAthena global function `F_IsCharm(item_id)`; returns `1` for a charm (enchant card).
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), 0 | 1}
  def call(ctx, args) do
    id = Enum.at(args, 0, 0)

    {ctx,
     Rathena.bool_int(
       within?(id, 4700, 4999) or within?(id, 29_000, 29_689) or within?(id, 310_000, 311_091)
     )}
  end

  defp within?(id, first, last), do: id >= first and id <= last
end

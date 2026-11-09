defmodule Aesir.ZoneServer.Content.Npc.Functions.FOkolnir do
  @moduledoc """
  Derives the castle suffix for an Okolnir instance.

  ## Behavior

  - Selects the instance suffix from the current NPC's map.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Joseph
    - L0ne_W0lf
    - Toshiro90
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/okolnir.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl, warn: false

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @doc "Returns the current Okolnir instance suffix with the updated context."
  @spec call(Ctx.t(), list()) :: {Ctx.t(), String.t()}
  def call(ctx, _args) do
    if Rathena.truthy?(Rathena.compare(strnpcinfo(ctx, 0), "main")) do
      throw({:script_end, ctx})
    end

    ctx = set_local(ctx, :"sub$", suffix(ctx))
    {ctx, get_local(ctx, :"sub$", "")}
  end

  # A castle map ("aldeg_cas01") contributes its guild prefix and number; a que_* challenge
  # map contributes everything after the map prefix.
  defp suffix(ctx) do
    map = strnpcinfo(ctx, 4)

    if Rathena.truthy?(Rathena.compare(map, "cas")),
      do: Rathena.substr(map, 0, 2) <> Rathena.substr(map, 8, 9),
      else: Rathena.substr(map, 5, 9)
  end
end

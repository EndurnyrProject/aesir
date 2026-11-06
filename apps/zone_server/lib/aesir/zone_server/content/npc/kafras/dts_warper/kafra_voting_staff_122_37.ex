defmodule Aesir.ZoneServer.Content.Npc.Kafras.DtsWarper.KafraVotingStaff12237 do
  @moduledoc """
  Kafra voting staff in Geffen for the Dungeon Teleport Service election.

  ## Behavior

  - Hands the conversation to the shared Kafra voting helper with this branch's portrait, which
    explains the election, records the player's vote and sells the trial-period dungeon teleports
    while the Kafra Corporation holds the service.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Silent
    - Lupus
    - L0ne_W0lf
    - Euphy
    - Liam

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/dts_warper.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen",
        x: 122,
        y: 37,
        dir: 4,
        sprite: 116,
        name: "Kafra Voting Staff",
        scope: :shared,
        unique_name: "Kafra Voting Staff#gef"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FVotekafra
  alias Aesir.ZoneServer.Script.Ctx

  @portrait 2

  @impl true
  @spec on_talk(Ctx.t()) :: no_return()
  def on_talk(ctx) do
    FVotekafra.call(ctx, [@portrait])
  end
end

defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Odininit do
  @moduledoc """
  A timer activates a random Odin Shrine entrance.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "odin_tem03", x: 4, y: 2, dir: 0, sprite: -1, name: "OdinInit", scope: :shared}
    ]

  @impl true
  def on_event("OnInit", ctx), do: initnpctimer(ctx)

  def on_event("OnTimer100000", ctx) do
    ctx = stopnpctimer(ctx)

    case Enum.random(1..5) do
      1 -> donpcevent(ctx, "warpinside#1::OnEnter")
      2 -> donpcevent(ctx, "warpinside#2::OnEnter")
      3 -> donpcevent(ctx, "warpinside#3::OnEnter")
      4 -> donpcevent(ctx, "warpinside#4::OnEnter")
      5 -> donpcevent(ctx, "warpinside#5::OnEnter")
    end
  end

  @impl true
  def on_talk(ctx), do: initnpctimer(ctx)
end

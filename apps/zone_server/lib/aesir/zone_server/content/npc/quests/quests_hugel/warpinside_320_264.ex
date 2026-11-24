defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Warpinside320264 do
  @moduledoc """
  A rotating entrance leads eligible adventurers inside the Odin Shrine.

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
      %{
        map: "odin_tem03",
        x: 320,
        y: 264,
        dir: 0,
        sprite: 139,
        name: "warpinside",
        scope: :shared,
        unique_name: "warpinside#5",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "warpinside#5")
  def on_event("OnEnter", ctx), do: enablenpc(ctx, "warpinside#5")
  def on_event("OnTouch_", ctx), do: enter_shrine(ctx)

  @impl true
  def on_talk(ctx), do: disablenpc(ctx, "warpinside#5")

  defp enter_shrine(ctx) do
    stage = get_char_var(ctx, :hg_odin, 0)

    if stage > 19 and stage < 23 do
      destination =
        case Enum.random(1..4) do
          1 -> "warpinside#1::OnEnter"
          2 -> "warpinside#2::OnEnter"
          3 -> "warpinside#3::OnEnter"
          4 -> "warpinside#4::OnEnter"
        end

      ctx
      |> donpcevent(destination)
      |> disablenpc("warpinside#5")
      |> set_char_var(:hg_odin, 21)
      |> warp("que_hugel", 36, 179)
    else
      ctx
    end
  end
end

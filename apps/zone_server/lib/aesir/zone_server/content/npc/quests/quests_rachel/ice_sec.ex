defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.IceSec do
  @moduledoc """
  Controls the temporary passage to the ice cave's fourth floor.

  ## Behavior

  - Enables the four entrances with effects for one minute.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ice_dun03",
        x: 1,
        y: 175,
        dir: 3,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#ice_sec"
      }
    ]

  @impl true
  def on_event("OnStart", ctx), do: handle_start(ctx)
  def on_event("OnTimer60000", ctx), do: handle_timer60000(ctx)
  @impl true
  def on_talk(ctx) do
    handle_start(ctx)
  end

  defp handle_start(ctx) do
    ctx
    |> initnpctimer()
    |> enablenpc("#ice_4f_1")
    |> enablenpc("#ice_4f_2")
    |> enablenpc("#ice_4f_3")
    |> enablenpc("#ice_4f_4")
    |> specialeffect(:mappillar2, :area, "#ice_4f_1")
    |> specialeffect(:mappillar2, :area, "#ice_4f_2")
    |> specialeffect(:mappillar2, :area, "#ice_4f_3")
    |> specialeffect(:mappillar2, :area, "#ice_4f_4")
  end

  defp handle_timer60000(ctx) do
    ctx
    |> stopnpctimer()
    |> disablenpc("#ice_4f_1")
    |> disablenpc("#ice_4f_2")
    |> disablenpc("#ice_4f_3")
    |> disablenpc("#ice_4f_4")
  end
end

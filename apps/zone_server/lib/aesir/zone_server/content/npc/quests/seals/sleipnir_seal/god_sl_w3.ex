defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.SleipnirSeal.GodSlW3 do
  @moduledoc """
  Security door of the Sleipnir research facility that only opens for a temporary pass holder.

  ## Behavior

  - Walking into or clicking the door warps a player in the pass stage of the Sleipnir Seal quest through it; anyone else is told the door is locked.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
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
        map: "que_god01",
        x: 17,
        y: 80,
        dir: 0,
        sprite: 45,
        name: "god_sl_w3",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: open_door(ctx)

  @impl true
  def on_talk(ctx), do: open_door(ctx)

  defp open_door(ctx) do
    if pass_holder?(ctx) do
      ctx
      |> mes(
        "^3355FFThe door is locked. You slide your temporary pass on the security device on the right side of the door, and the door unlocks.^000000"
      )
      |> next()
      |> warp("que_god01", 12, 52)
    else
      ctx
      |> mes(
        "^3355FFThe door is locked. There is some sort of security device on the right side. It seems the device needs to detect some kind of pass before you can enter.^000000"
      )
      |> close()
    end
  end

  defp pass_holder?(ctx) do
    stage = get_char_var(ctx, :god_sl_1, 0)
    stage > 1 and stage < 51
  end
end

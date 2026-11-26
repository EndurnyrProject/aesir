defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.SleipnirSeal.Switch1997 do
  @moduledoc """
  Security device beside a Sleipnir research facility door that only opens it for a temporary pass holder.

  ## Behavior

  - A player in the pass stage of the Sleipnir Seal quest is warped through the door; anyone else is told the door is locked.

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
        x: 19,
        y: 97,
        dir: 0,
        sprite: 111,
        name: "Switch",
        scope: :shared,
        unique_name: "Switch#God2"
      }
    ]

  @impl true
  def on_talk(ctx), do: open_door(ctx)

  defp open_door(ctx) do
    if pass_holder?(ctx) do
      ctx
      |> mes(
        "^3355FFThe door is locked. You slide your temporary pass on the security device on the right side of the door, and the door unlocks.^000000"
      )
      |> next()
      |> warp("que_god01", 12, 119)
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

defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.WoundedManSwitch do
  @moduledoc """
  Reveals the wounded man during the investigation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_fild02",
        x: 224,
        y: 220,
        dir: 0,
        sprite: 111,
        name: "Wounded Man Switch",
        scope: :shared,
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: reveal_wounded_man(ctx)

  @impl true
  def on_talk(ctx), do: reveal_wounded_man(ctx)

  defp reveal_wounded_man(ctx) do
    if get_char_var(ctx, :lhz_boss, 0) == 18 do
      ctx
      |> mes("[?????]")
      |> mes("^333333*Cough cough*^000000")
      |> mes("Everything's getting")
      |> mes("darker. So c-cold...")
      |> enablenpc("Wounded Man")
      |> close()
    else
      ctx
    end
  end
end

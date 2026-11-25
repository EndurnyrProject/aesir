defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.EsunaTrigger do
  @moduledoc """
  Guides the investigator to the mysterious woman.

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
        map: "lhz_fild01",
        x: 76,
        y: 214,
        dir: 0,
        sprite: 111,
        name: "Esuna Trigger",
        scope: :shared,
        trigger: {5, 5}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: guide_to_esuna(ctx)

  @impl true
  def on_talk(ctx), do: guide_to_esuna(ctx)

  defp guide_to_esuna(ctx) do
    if get_char_var(ctx, :lhz_boss, 0) in [26, 36, 38, 40] do
      ctx
      |> mes("[????]")
      |> mes("Here,")
      |> mes("Come this way.")
      |> close2()
      |> enablenpc("Mysterious Woman")
      |> warp("lhz_fild01", 64, 223)
    else
      ctx
    end
  end
end

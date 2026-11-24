defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Hint01Ayohint do
  @moduledoc """
  A dungeon hint that reveals the stone slate locations.

  ## Behavior

  - Sometimes reveals the slate locations before the dungeon quest reaches stage 11.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Fredzilla
    - MasterOfMuppets
    - Lupus
    - Silent
    - Evera
    - SinSloth
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ayo_dun01",
        x: 156,
        y: 148,
        dir: 0,
        sprite: -1,
        name: " ",
        scope: :shared,
        unique_name: "AyoHint",
        trigger: {0, 4}
      },
      %{
        map: "ayo_dun01",
        x: 259,
        y: 42,
        dir: 0,
        sprite: -1,
        name: " ",
        scope: :shared,
        unique_name: " #hint02",
        trigger: {2, 0}
      },
      %{
        map: "ayo_dun01",
        x: 259,
        y: 44,
        dir: 0,
        sprite: -1,
        name: " ",
        scope: :shared,
        unique_name: " #hint02_2",
        trigger: {2, 0}
      },
      %{
        map: "ayo_dun01",
        x: 259,
        y: 46,
        dir: 0,
        sprite: -1,
        name: " ",
        scope: :shared,
        unique_name: " #hint02_3",
        trigger: {2, 0}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  end

  defp ev_ontouch(ctx) do
    if Enum.random(1..100) > 60 and get_char_var(ctx, :ayodunquest, 0) < 11 do
      ctx
      |> mes(
        "^3355FFThe Holy Thread in your pocket suddenly began to glow. You feel that something is near you...^000000"
      )
      |> close()
      |> viewpoint(1, 198, 164, 0, 16_711_680)
      |> viewpoint(1, 87, 16, 1, 16_711_680)
      |> viewpoint(1, 268, 214, 2, 16_711_680)
      |> viewpoint(1, 147, 274, 3, 16_711_680)
      |> viewpoint(1, 99, 118, 4, 16_711_680)
      |> viewpoint(1, 16, 188, 5, 16_711_680)
    else
      ctx
    end
  end
end

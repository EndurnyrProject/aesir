defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.ThDun111Ayotrap1 do
  @moduledoc """
  A warning at a drop into water in the Ayothaya dungeon.

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
        x: 273,
        y: 26,
        dir: 0,
        sprite: 111,
        name: " ",
        scope: :shared,
        unique_name: "AyoTrap1",
        trigger: {0, 4}
      },
      %{
        map: "ayo_dun01",
        x: 273,
        y: 27,
        dir: 0,
        sprite: 111,
        name: " ",
        scope: :shared,
        unique_name: " #th_dun1_1_2"
      },
      %{
        map: "ayo_dun01",
        x: 272,
        y: 27,
        dir: 0,
        sprite: 111,
        name: " ",
        scope: :shared,
        unique_name: " #th_dun1_1_3",
        trigger: {0, 4}
      },
      %{
        map: "ayo_dun01",
        x: 272,
        y: 26,
        dir: 0,
        sprite: 111,
        name: " ",
        scope: :shared,
        unique_name: " #th_dun1_1_4"
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFYou look down and see a pool")
    |> mes("of water in the distance. It looks like a long drop to the bottom.^000000")
    |> next()
    |> mes("^3355FFYou are filled")
    |> mes("with apprehension,")
    |> mes("After all, if you fall down,^000000")
    |> mes("^2F2F4Fyou might get killed.^000000")
    |> close()
  end

  defp ev_ontouch(ctx) do
    ctx
    |> mes("^3355FFYou look down and see a pool")
    |> mes("of water in the distance. It looks like a long drop to the bottom.^000000")
    |> next()
    |> mes("^3355FFYou are filled")
    |> mes("with apprehension.")
    |> mes("After all, if you fall down,")
    |> mes("^2F2F4Fyou might get killed.^000000")
    |> close()
  end
end

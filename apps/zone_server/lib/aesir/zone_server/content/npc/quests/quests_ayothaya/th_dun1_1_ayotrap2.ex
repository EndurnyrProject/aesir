defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.ThDun11Ayotrap2 do
  @moduledoc """
  A lethal water trap in the Ayothaya dungeon.

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
        x: 26,
        y: 27,
        dir: 0,
        sprite: -1,
        name: " ",
        scope: :shared,
        unique_name: "AyoTrap2",
        hidden_name: "th_dun1_1",
        trigger: {1, 1}
      },
      %{
        map: "ayo_dun01",
        x: 28,
        y: 27,
        dir: 0,
        sprite: -1,
        name: " ",
        scope: :shared,
        unique_name: " #th_dun1_2",
        trigger: {0, 1}
      },
      %{
        map: "ayo_dun01",
        x: 27,
        y: 25,
        dir: 0,
        sprite: -1,
        name: " ",
        scope: :shared,
        unique_name: " #th_dun1_3",
        trigger: {1, 0}
      },
      %{
        map: "ayo_dun01",
        x: 25,
        y: 25,
        dir: 0,
        sprite: -1,
        name: " ",
        scope: :shared,
        unique_name: " #th_dun1_4"
      },
      %{
        map: "ayo_dun01",
        x: 272,
        y: 273,
        dir: 0,
        sprite: -1,
        name: " ",
        scope: :shared,
        unique_name: " #th_dun1_5",
        trigger: {1, 1}
      },
      %{
        map: "ayo_dun01",
        x: 274,
        y: 273,
        dir: 0,
        sprite: -1,
        name: " ",
        scope: :shared,
        unique_name: " #th_dun1_6",
        trigger: {0, 1}
      },
      %{
        map: "ayo_dun01",
        x: 273,
        y: 271,
        dir: 0,
        sprite: -1,
        name: " ",
        scope: :shared,
        unique_name: " #th_dun1_7",
        trigger: {1, 0}
      },
      %{
        map: "ayo_dun01",
        x: 271,
        y: 271,
        dir: 0,
        sprite: -1,
        name: " ",
        scope: :shared,
        unique_name: " #th_dun1_8"
      },
      %{
        map: "ayo_dun01",
        x: 26,
        y: 273,
        dir: 0,
        sprite: -1,
        name: " ",
        scope: :shared,
        unique_name: " #th_dun1_9",
        trigger: {1, 1}
      },
      %{
        map: "ayo_dun01",
        x: 28,
        y: 273,
        dir: 0,
        sprite: -1,
        name: " ",
        scope: :shared,
        unique_name: " #th_dun1_10",
        trigger: {0, 1}
      },
      %{
        map: "ayo_dun01",
        x: 27,
        y: 271,
        dir: 0,
        sprite: -1,
        name: " ",
        scope: :shared,
        unique_name: " #th_dun1_11",
        trigger: {1, 0}
      },
      %{
        map: "ayo_dun01",
        x: 25,
        y: 271,
        dir: 0,
        sprite: -1,
        name: " ",
        scope: :shared,
        unique_name: " #th_dun1_12"
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  end

  defp ev_ontouch(ctx) do
    percent_heal(ctx, hp: -100, sp: 0)
  end
end

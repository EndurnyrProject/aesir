defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.NativeWarrior do
  @moduledoc """
  A native warrior longs for Iara at the waterfall.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "bra_fild01",
        x: 188,
        y: 301,
        dir: 5,
        sprite: 472,
        name: "Native Warrior",
        scope: :shared,
        unique_name: "Native Warrior#nk"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Native Warrior]")
      |> mes("Ah... the face I would never forget even in my dreams.")
      |> next()
      |> mes("[Native Warrior]")
      |> mes("When will she come out of the waterfall again...?")
      |> next()

    ctx =
      if checkquest(ctx, 4133) >= 0 or checkquest(ctx, 4134) >= 0 do
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("(Wh...what's this guy?)")
      else
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("(This guy will never")
        |> mes("get over Iara's curse...)")
      end

    close(ctx)
  end
end

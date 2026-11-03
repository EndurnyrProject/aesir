defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuArcher.NewGuildMaster do
  @moduledoc """
  Prontera guild master boasting about his Emperium, one stop of the Archer training errand.

  ## Behavior

  - Always gives his recruiting speech.
  - At Archer errand step 3, hearing the speech advances the errand step to 4.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - SinSloth
    - Capuche
    - Euphy
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 167,
        y: 281,
        dir: 3,
        sprite: 753,
        name: "New Guild Master",
        scope: :shared,
        unique_name: "New Guild Master#tu"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[New Guild Master]")
      |> mes("Hearken, all")
      |> mes("of you who seek")
      |> mes("fame and glory!")
      |> next()
      |> mes("[New Guild Master]")
      |> mes(
        "I hold in my hand this ^3131FFEmperium^000000, sign that I am favored by destiny! Brave ones, I bid you, lend me"
      )
      |> mes("your power!")
      |> next()
      |> mes("[New Guild Master]")
      |> mes("Nothing can stop us!")
      |> mes("So long as this jewel")
      |> mes("is in my possession,")
      |> mes("those who call themselves")
      |> mes("my comrades will never")
      |> mes("know the taste of defeat!")

    if get_char_var(ctx, :tu_archer02, 0) == 3 do
      ctx
      |> set_char_var(:tu_archer02, 4)
      |> close()
    else
      close(ctx)
    end
  end
end

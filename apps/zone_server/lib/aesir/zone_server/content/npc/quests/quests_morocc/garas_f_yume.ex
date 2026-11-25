defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.GarasFYume do
  @moduledoc """
  The player witnesses Eva and her companion escaping the laboratory.

  ## Behavior

  - At the relevant quest stage, the vision advances before returning the player to the library.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_ba",
        x: 53,
        y: 232,
        dir: 0,
        sprite: 139,
        name: "",
        scope: :shared,
        unique_name: "#garas_f_yume",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch", ctx), do: show_vision(ctx)
  @impl true
  def on_talk(ctx) do
    show_vision(ctx)
  end

  defp show_vision(ctx) do
    if get_char_var(ctx, :barmunt_crow, 0) == 5 do
      ctx =
        ctx
        |> mes(
          "^660000Suddenly a flash of light stung your eyes. A few seconds later, you opened your eyes and found that you were somewhere in Schwarzwald.^000000"
        )
        |> next()
        |> mes(
          "^660000And you aren't alone: you can now clearly see the man and woman that escaped the laboratory.^000000"
        )
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Umm...")
      |> next()
      |> mes("[Grotesque Man]")
      |> mes("Where should we go?")
      |> mes("No one will welcome us... We look like monsters!")
      |> next()
      |> mes("[Eva]")
      |> mes("...")
      |> mes("I know a cave that's hidden in the north.")
      |> mes("We can stay there for a while.")
      |> next()
      |> mes("^660000They seemed completely oblivious of your presence, and headed north.^000000")
      |> next()
      |> mes(
        "^660000You were looking at their backs as they left, and then noticed that you were holding the book you were reading in your hands. Then....^000000"
      )
      |> set_char_var(:barmunt_crow, 6)
      |> specialeffect2(:flasher)
      |> close2()
      |> warp("yuno_in04", 100, 3)
    else
      warp(ctx, "yuno_in04", 100, 3)
    end
  end
end

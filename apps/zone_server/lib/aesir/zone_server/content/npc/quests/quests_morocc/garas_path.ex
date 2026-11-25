defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.GarasPath do
  @moduledoc """
  The library passage resumes the Crow of the Fate quest after the vision.

  ## Behavior

  - The player recalls the vision and decides to search for newspaper reports.

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
        map: "yuno_in04",
        x: 100,
        y: 3,
        dir: 0,
        sprite: 139,
        name: "",
        scope: :shared,
        unique_name: "#garas_path",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch", ctx) do
    resume_quest(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    resume_quest(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp resume_quest(ctx) do
    case get_char_var(ctx, :barmunt_crow, 0) do
      6 ->
        ctx =
          ctx
          |> mes("...................................")
          |> next()
          |> mes("...................................")
          |> mes("...................................")
          |> next()
          |> mes("...................................")
          |> mes("...................................")
          |> mes("...................................")
          |> next()
          |> mes("^660000You are still inside the library,")
          |> mes("but you do not know if this is a dream or reality.^000000")
          |> next()
          |> mes(
            "^660000You turned your head toward the bookshelf, and found the bookshelf with the empty shelf.^000000"
          )
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Phew... I guess I had a dream or something... Ahchoo!")
          |> specialeffect2(:venomdust)
          |> next()
          |> mes(
            "^660000It was an indescribable dream: a burning laboratory in an unknown place in Schwarzwald."
          )
          |> mes("You tried to think hard, but could not figure out what the dream meant.^000000")
          |> next()
          |> mes("^660000You carefully opened the book again, but nothing happened.^000000")
          |> next()
          |> mes(
            "<....at the end of the sooty fog and chaotic screams, there was a creature that looked too outrageous to be a human...>"
          )
          |> next()
          |> mes("...................................")
          |> next()
          |> mes("<- Eva, what are you doing? Come over here! Hurry!-")
          |> mes("-I can't leave him here!-")
          |> mes(
            "Ignoring the collapsing laboratory ceiling, Eva approached a test tube, carefully took out something, and then put it under her jacket. >"
          )
          |> next()
          |> mes("^660000...................................^000000")
          |> next()
          |> mes(
            "^660000The books was telling the exact scene that you have seen in your dream.^000000"
          )
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Deja Vu? Am I having Deja Vu?")
        |> next()
        |> mes(
          "^660000Of course, it was just a dream, but still was a very mysterious experience.^000000"
        )
        |> next()
        |> mes("...................................")
        |> next()
        |> mes("...................................")
        |> next()
        |> mes(
          "'^660000Now I wonder if the scene is describing an accident that really happened in the past. If there was such big fire, I'm sure I can verify it in a newspaper."
        )
        |> mes("...I just want to know it out of curiosity...^000000'")
        |> set_char_var(:barmunt_crow, 7)
        |> changequest(2064, 2065)
        |> close()

      7 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("If I want to read news articles about fires, which section should I go to?")
        |> close()

      _ ->
        ctx
    end
  end
end

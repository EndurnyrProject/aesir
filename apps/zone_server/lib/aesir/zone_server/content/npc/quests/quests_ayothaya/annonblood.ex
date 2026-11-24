defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Annonblood do
  @moduledoc """
  Bloodstained bushes conceal Annon's hiding place.

  ## Behavior

  - Stepping near (or talking while Annon is out) on the blood trail step may reveal the blood
    stain, advancing the quest to the bushes step.
  - Lets questing visitors search the bushes and possibly reveal the Haggard Man.
  - Shows different descriptions depending on quest progress.

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
        map: "ayo_dun02",
        x: 91,
        y: 263,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#Annonblood",
        trigger: {2, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx), do: spot_blood(ctx)

  @impl true
  def on_talk(ctx) do
    cond do
      Rathena.truthy?(get_server_temp_var(ctx, "annonactive", 0)) -> spot_blood(ctx)
      get_char_var(ctx, :thai_find, 0) == 13 -> inspect_bushes(ctx)
      get_char_var(ctx, :thai_find, 0) == 14 -> empty_burrow(ctx)
      true -> dead_bushes(ctx)
    end
  end

  defp spot_blood(ctx) do
    if get_char_var(ctx, :thai_find, 0) == 12 and not Rathena.truthy?(Enum.random(0..2)) do
      speaker = "[#{char_name(ctx, 0)}]"

      ctx
      |> emotion(:surprise, playerattached(ctx))
      |> mes(speaker)
      |> mes("Huh...?")
      |> next()
      |> mes(speaker)
      |> mes("That looks")
      |> mes("like blood!")
      |> next()
      |> mes(speaker)
      |> mes("Hmm...")
      |> mes("Yes...")
      |> mes("That's definitely blood.")
      |> next()
      |> mes(speaker)
      |> mes("Strange to see")
      |> mes("a blood stain in")
      |> mes("this kind of place...")
      |> set_char_var(:thai_find, 13)
      |> changequest(12_033, 12_034)
      |> close()
    else
      ctx
    end
  end

  defp inspect_bushes(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("A blood stain?")
      |> mes("What's going on?")
      |> mes("I should take a look...")
      |> next()
      |> mes("^3355FFUnder a giant tree,")
      |> mes("you find some bushes with")
      |> mes("blood smudged on some")
      |> mes("of the leaves.^000000")
      |> next()
      |> mes("^3355FFWithin the bushes, you see")
      |> mes(
        "that the trail of blood continues, almost as if a bleeding animal struggled to find refuge within"
      )
      |> mes("the bushes.^000000")
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hmmm....")
      |> next()
      |> select(["Scatter the bushes.", "Dig up the bushes."])

    case choice do
      1 -> scatter(ctx)
      2 -> dig(ctx)
      _ -> ctx
    end
  end

  defp scatter(ctx) do
    if not Rathena.truthy?(Enum.random(0..2)) do
      find_burrow(ctx)
    else
      dusty_scatter(ctx)
    end
  end

  defp find_burrow(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("^666666*Cough cough*^000000")
      |> mes("It's so dusty!")
      |> next()
      |> mes("[?]")
      |> mes("...Awwww")
      |> mes("Oh... Oh God...!")
      |> next()

    ctx = emotion(ctx, :surprise, playerattached(ctx))

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Huh...?")
      |> mes("I heard something")
      |> mes("from below! Let's")
      |> mes("dig it up!")
      |> next()
      |> mes("^3355FFYou pull up the bushes,")
      |> mes("^3355FFand beneath the dust and")
      |> mes("^3355FFshrubbery, you find")
      |> mes("a small burrow.^000000")
      |> next()
      |> set_server_temp_var("annonactive", 1)
      |> enablenpc("Haggard Man")
      |> mes("[Haggard Man]")
      |> mes("^666666*Cough cough!*^000000")
      |> mes("Wh...who's there?")
      |> mes("Shuda?! If that's you,")
      |> mes("stay back, or I'll kill myself!")

    {ctx, choice} =
      ctx
      |> emotion(:huk, playerattached(ctx))
      |> next()
      |> select(["What are you doing here?", "I'm not Shuda!"])

    case choice do
      1 -> scare_annon(ctx)
      2 -> reassure_annon(ctx)
      _ -> ctx
    end
  end

  defp dusty_scatter(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou dig up the bushes, stirring")
      |> mes("up a large, choking cloud of dust.^000000")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("^666666*Cough cough!*^000000")
    |> mes("What a large,")
    |> mes("choking cloud")
    |> mes("of dust!")
    |> close()
  end

  defp dig(ctx) do
    ctx =
      ctx
      |> mes(
        "^3355FFAs you dig up the bushes, the ground beneath one of the bushes crumbles and you hear a scream"
      )
      |> mes("from beneath.^000000")
      |> next()

    if not Rathena.truthy?(Enum.random(0..2)) do
      reveal_annon(ctx)
    else
      dusty_dig(ctx)
    end
  end

  defp scare_annon(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Hey...")
    |> mes("What are you doi--")
    |> next()
    |> set_server_temp_var("annonactive", 0)
    |> disablenpc("Haggard Man")
    |> mes("^3355FFHe vanished!^000000")
    |> close()
  end

  defp reassure_annon(ctx) do
    ctx
    |> mes("[Haggard Man]")
    |> mes("Hmmm...?")
    |> mes(
      "I sense kindess, sincerity and a general love for mankind in your voice. Verily, you are not Shuda."
    )
    |> next()
    |> mes("[Haggard Man]")
    |> mes(
      "You are unfamiliar to me, outsider. I'm unsure of how you found my hiding place, but if you have something to say, make it short!"
    )
    |> close()
  end

  defp reveal_annon(ctx) do
    ctx
    |> set_server_temp_var("annonactive", 1)
    |> enablenpc("Haggard Man")
    |> mes("[?]")
    |> mes("^666666*Cough cough*^000000")
    |> mes("...M-my legs!")
    |> close()
  end

  defp dusty_dig(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Hmmm...?")
    |> mes("What was that noise?")
    |> mes("Ugh, it's awfully dusty.")
    |> mes("I better stop digging.")
    |> mes("^666666*cough cough cough*^000000")
    |> close()
  end

  defp empty_burrow(ctx) do
    ctx
    |> mes(
      "^3355FFYou find that the burrow is empty. It seems Annon has found a new hiding place.^000000"
    )
    |> close()
  end

  defp dead_bushes(ctx) do
    ctx
    |> mes(
      "^3355FFYou find a pile of dead bushes under a large tree. The area around the bushes seems awfully dusty.^000000"
    )
    |> close()
  end
end

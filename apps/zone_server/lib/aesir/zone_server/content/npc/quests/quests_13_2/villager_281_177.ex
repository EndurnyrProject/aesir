defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Villager281177 do
  @moduledoc """
  Lets a visitor overhear villagers discussing a captured fairy.

  ## Behavior

  - Dialogue depends on carrying capacity, translation equipment and quest progress.
  - Interrupting or listening advances the search for Terra.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "manuk",
        x: 281,
        y: 177,
        dir: 3,
        sprite: 449,
        name: "Villager",
        scope: :shared,
        unique_name: "Villager#ep13_12"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if checkweight(ctx, [{1201, 2}]) == 0 do
      ctx
      |> mes("Wait a moment!!")
      |> mes("You have too many items.")
      |> mes("You can't receive this.")
      |> mes("Lighten your weight and")
      |> mes("try again.")
      |> close()
    else
      speak(ctx)
    end
  end

  defp speak(ctx) do
    cond do
      is_equipped(ctx, 2782) != 1 ->
        unintelligible(ctx)

      get_char_var(ctx, :ep13_mdrama, 0) == 10 ->
        ctx =
          ctx
          |> mes("[Villager Lawine]")
          |> mes("By the way, how did that Fairy come this far?")
          |> mes("Is she captured?")
          |> next()
          |> mes("[Villager Rivier]")
          |> mes("No, She's not.")
          |> mes("That Fairy came here by her own accord.")
          |> mes("How impudent. She was horribly wounded when she got here.")
          |> next()

        {ctx, choice} =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("(Hmm? a Fairy? Wounded?")
          |> mes("Are they talking about Terra..?!)")
          |> next()
          |> select(["Break into their conversation.", "Keep quiet and listen."])

        case choice do
          1 ->
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Excuse me for interrupting your conversation.")
            |> mes("You were talking about a Fairy, would you be kind to tell me the details?")
            |> next()
            |> mes("[Villager Lawine]")
            |> mes("Outsider!!")
            |> mes("Why is he here?")
            |> next()
            |> mes("[Villager Rivier]")
            |> mes("We weren't saying anything.")
            |> mes("There's nothing to tell you.")
            |> mes("Lawine, Come with me to the Refinery later.")
            |> next()
            |> mes("- The Sapha people are not willing to tell you anything. But the")
            |> mes("captured Fairy may be Terra. -")
            |> set_char_var(:ep13_mdrama, 11)
            |> changequest(7060, 7061)
            |> close()

          2 ->
            ctx
            |> mes("[Villager Lawine]")
            |> mes("I heard a fairy was crying and begging, she was badly hurt.")
            |> next()
            |> mes("[Villager Rivier]")
            |> mes("No one understand the words of fairy...")
            |> mes("In the end we had no idea what to do.")
            |> next()
            |> mes("[Villager Rivier]")
            |> mes("Anyway, that fairy is now in prison.")
            |> mes("By the way, pull within feather")
            |> mes("Today we have to go to the refinery,")
            |> mes("do not forget.")
            |> next()
            |> mes("[Villager Lawine]")
            |> mes("You know, right?")
            |> mes("Ahh! A foreign visitor!")
            |> next()
            |> mes("[Villager Rivier]")
            |> mes("Nevermind him, he can not understand our words.")
            |> next()
            |> mes("- Fortunately, Sapha had thought I could not understand them,")
            |> mes("but they must be talking about Terra... -")
            |> set_char_var(:ep13_mdrama, 11)
            |> changequest(7060, 7061)
            |> close()

          _ ->
            ctx
        end

      get_char_var(ctx, :ep13_mdrama, 0) > 10 ->
        ctx
        |> mes(
          "- The Sapha are having a conversation and not paying attention to my movements. -"
        )
        |> next()
        |> mes(
          "- They are talking mostly about common town matters, not much useful information. -"
        )
        |> next()
        |> mes("- I'd better move away from them before they get suspicious of my presence. -")
        |> close()

      true ->
        ctx
        |> mes("[Villager]")
        |> mes("...Outsider, huh...")
        |> mes("Since when did we allow outsiders to come and visit?")
        |> mes("That's right..Do you even understand me?")
        |> next()
        |> mes("[Villager]")
        |> mes("...I guess it doesn't matter....")
        |> mes("Ah, Do we even understand each other?")
        |> close()
    end
  end

  defp unintelligible(ctx) do
    ctx
    |> mes("[Villager]")
    |> mes("Fsd a idh as?")
    |> mes("Nsf iu ai sd a sd!")
    |> mes("Asd fo sdj fso df.")
    |> close()
  end
end

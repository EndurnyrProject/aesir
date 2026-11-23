defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.PetrifiedSapha do
  @moduledoc """
  Presents the petrified Sapha as the Two Tribes investigation progresses.

  ## Behavior

  - Advances the investigation and lets the player collect evidence.
  - Reveals Ogen’s fate when the player returns with Snorren’s ring.

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
        map: "nyd_dun01",
        x: 58,
        y: 223,
        dir: 0,
        sprite: 844,
        name: "Petrified Sapha",
        scope: :shared,
        unique_name: "Petrified Sapha#ep13md03"
      }
    ]

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
      sapha_talk(ctx, get_char_var(ctx, :ep13_mdrama, 0))
    end
  end

  defp sapha_talk(ctx, 6), do: discover_statue(ctx)

  defp sapha_talk(ctx, progress) when progress in [7, 8] do
    ctx
    |> player_header()
    |> mes("I'm done with this place.")
    |> mes("I should go back to Arc...")
    |> mes("Let's find an exit.")
    |> close()
  end

  defp sapha_talk(ctx, 9) do
    ctx
    |> mes("I came back here, but there's no trace of Terra...")
    |> mes(
      "There's only one thing different from the last time..Small particles of an ore are sprinkled around the Sapha's dead body."
    )
    |> next()
    |> player_header()
    |> mes("So...Terra was here.....")
    |> mes("Powdered Bradium...")
    |> mes("What was she trying to do with this Sapha?")
    |> next()
    |> player_header()
    |> mes("I can't just go back to Arc without anything... he'd be so disappointed...")
    |> mes("Hmm, Should I go to the Sapha's village?")
    |> set_char_var(:ep13_mdrama, 10)
    |> changequest(7059, 7060)
    |> close()
  end

  defp sapha_talk(ctx, 10) do
    ctx
    |> player_header()
    |> mes("I can't find any traces of Terra anymore.")
    |> mes("One thing that bugs me is...These particles of an ore.")
    |> next()
    |> player_header()
    |> mes(
      "I should go back to Arc and ask about it, or go to Sapha's Village and investigate some more."
    )
    |> close()
  end

  defp sapha_talk(ctx, progress) when progress > 10 and progress < 21 do
    ctx
    |> mes("A giant from the race called Sapha is petrified here.")
    |> mes("It looks like it's dead...")
    |> close()
  end

  defp sapha_talk(ctx, 21), do: collect_evidence(ctx)

  defp sapha_talk(ctx, 22) do
    ctx
    |> mes("Petrified Sapha.")
    |> mes("Now I have the muffler, let's go back to Luik and Snorren.")
    |> close()
  end

  defp sapha_talk(ctx, 23) do
    if is_equipped(ctx, 2782) == 1 do
      mourn_ogen(ctx)
    else
      ctx
      |> player_header()
      |> mes("Whoa, I almost forgot the ring.")
      |> close()
    end
  end

  defp sapha_talk(ctx, progress) when progress > 23 do
    ctx
    |> mes("Ogen... was petrified as he covered Terra...")
    |> mes("What was going on between them that they would see past their racial differences...?")
    |> close()
  end

  defp sapha_talk(ctx, _progress) do
    ctx
    |> mes("Before you is a statue made of stone and wood. It's so life-like it's eerie.")
    |> close()
  end

  defp discover_statue(ctx) do
    ctx
    |> mes("This is the only spot where sunlight is shining down through a hole in the ceiling.")
    |> next()
    |> mes(
      "Looking up I see the roots of the tree and stems digging up a mud-plastered wall, so the sunlight could shine through....2.j...There is a statue of Giant on the ground."
    )
    |> next()
    |> player_header()
    |> mes("A statue in a place like this...")
    |> mes("Interesting.")
    |> next()
    |> player_header()
    |> mes("Hm, This resembles... that giant tribe in Manuk...")
    |> mes("Huh? It's wearing a muffler...")
    |> mes("...It can't be!")
    |> next()
    |> player_header()
    |> mes("It has a lot of scars on it... as if it had been in a severe fight...")
    |> next()
    |> player_header()
    |> mes("And it appears like it's holding something in its arms...")
    |> mes("Just what happened here?")
    |> next()
    |> player_header()
    |> mes("I can't imagine what happened here, but I don't see Terra's marks anymore...")
    |> mes("and this cave looks unsafe... I'd better go back to Arc for now.")
    |> next()
    |> player_header()
    |> mes("Could it be... Terra was fighting this Giant?")
    |> set_char_var(:ep13_mdrama, 7)
    |> changequest(7057, 7058)
    |> next()
    |> player_header()
    |> mes("Anyways... How do I get out of here?")
    |> mes("That hole I came in is too slippery to climb back out...")
    |> next()
    |> player_header()
    |> mes(
      "Light is coming in from the ceiling above... Maybe I should just climb a stem around here..."
    )
    |> close()
  end

  defp collect_evidence(ctx) do
    {ctx, choice} =
      ctx
      |> mes("I need to bring back some evidence of this giant in the cave.")
      |> mes("What should I bring with me?")
      |> next()
      |> select(["Hair", "Muffler", "Pants", "Fragment of Bradium"])

    case choice do
      1 -> take_hair(ctx)
      2 -> take_muffler_first(ctx)
      3 -> take_pants(ctx)
      4 -> take_bradium_first(ctx)
      _ -> ctx
    end
  end

  defp take_muffler_first(ctx) do
    {ctx, choice} =
      ctx
      |> mes("You carefully strip a worn muffler off of the Sapha's neck.")
      |> mes("We will see if this muffler belongs to Ogen or not.")
      |> next()
      |> mes("And...what else should I take?")
      |> next()
      |> select(["Hair", "Pants", "Fragment of Bradium"])

    case choice do
      1 ->
        take_hair(ctx)

      2 ->
        take_pants(ctx)

      3 ->
        ctx
        |> mes("You pick up a fragment of Bradium scattered on the ground.")
        |> mes("This should be enough.")
        |> evidence_collected()

      _ ->
        ctx
    end
  end

  defp take_bradium_first(ctx) do
    {ctx, choice} =
      ctx
      |> mes("You pick up a fragment of Bradium scattered on the ground.")
      |> mes("This will prove Terra's effort...")
      |> mes("And what else?")
      |> next()
      |> select(["Hair", "Muffler", "Pants"])

    case choice do
      1 ->
        take_hair(ctx)

      2 ->
        ctx
        |> mes("You carefully strip a worn muffler off of the Sapha's neck.")
        |> mes("We will see if this muffler belongs to Ogen or not...")
        |> mes("This should be enough.")
        |> evidence_collected()

      3 ->
        take_pants(ctx)

      _ ->
        ctx
    end
  end

  defp take_hair(ctx) do
    ctx
    |> mes("It won't come off. It's as if it is a tree rooted on a rock.")
    |> close()
  end

  defp take_pants(ctx) do
    ctx
    |> mes("... I don't want to take off a dead MAN's pants...")
    |> close()
  end

  defp evidence_collected(ctx) do
    ctx
    |> set_char_var(:ep13_mdrama, 22)
    |> give_item(6085, 1)
    |> give_item(6084, 1)
    |> changequest(7066, 7067)
    |> close()
  end

  defp mourn_ogen(ctx) do
    {ctx, _} =
      ctx
      |> donpcevent("Snorren#ep13md17::OnEnable")
      |> mes("[Snorren]")
      |> mes("Ogen!!!!!!")
      |> mes("...Ogen... Ogen...")
      |> mes("....Ogeeen......")
      |> next()
      |> select(["You don't mean..?"])

    ctx
    |> mes("[Snorren]")
    |> mes("This.. is.. worse than I could have imagined.....")
    |> mes("Ogen... this doesn't look like it can be reversed...")
    |> next()
    |> mes("[Snorren]")
    |> mes("No matter how much bradium fluid we inject... Ogen can't come back alive...")
    |> next()
    |> mes("[Snorren]")
    |> mes("Ogen... really was adament... about protecting that Laphine... to protect Terra.....")
    |> mes("He did his best 'til the last...")
    |> next()
    |> mes("[Snorren]")
    |> mes("Look at this, #{char_name(ctx, 0)}...")
    |> mes("His petrifyied body...")
    |> mes("protected Terra...like this.")
    |> next()
    |> mes("[Snorren]")
    |> mes("Ogen... made himself an unbreakable shield...")
    |> next()
    |> mes("[Snorren]")
    |> mes("Ogen... you can now go back to the bosom of the Motherland...")
    |> mes("This statue will be a monument to your courage...")
    |> next()
    |> mes("- - I can't begin to describe the sorrow of losing a close friend... -")
    |> next()
    |> mes("- All I could do was to keep tapping his shoulder... as he quietly sobbed... -")
    |> next()
    |> player_header()
    |> mes("Let's.. go back...")
    |> mes("Ogen wouldn't want you to be so sad and depressed.")
    |> next()
    |> mes("[Snorren]")
    |> mes("I guess you are right...")
    |> mes("There's... sunlight shining here...")
    |> mes("This... must be a comfort resting place for Ogen.")
    |> next()
    |> mes("[Snorren]")
    |> mes("I should go and tell Luik and the townspeople about this...")
    |> mes("I will go on ahead.")
    |> next()
    |> donpcevent("Snorren#ep13md17::OnDisable")
    |> mes("- Snorren stood up with a bitter smile...")
    |> mes("...I should go back too... I'm worried about Terra. -")
    |> set_char_var(:ep13_mdrama, 24)
    |> changequest(7068, 7069)
    |> close()
  end

  defp player_header(ctx), do: mes(ctx, "[#{char_name(ctx, 0)}]")
end

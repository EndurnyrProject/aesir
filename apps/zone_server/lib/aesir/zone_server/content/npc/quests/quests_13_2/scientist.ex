defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Scientist do
  @moduledoc """
  Helps Dr. Lifeguard research a treatment for the Sapha.

  ## Behavior

  - Explains the Sapha's disease and assigns a daily mineral-gathering quest.
  - Exchanges completed mineral deliveries for Manuk coins.

  ## Credits

  - Original from rAthena, authors and Contributors
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
        map: "man_in01",
        x: 372,
        y: 221,
        dir: 5,
        sprite: 449,
        name: "Scientist",
        scope: :shared,
        unique_name: "Scientist#lifeguard"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx = mes(ctx, "[Dr. Lifeguard]")
      talk_quest(ctx, get_char_var(ctx, :ep13_2_tre, 0))
    else
      ctx
      |> mes("[Scientist]")
      |> mes("Pdh doud pjfdd")
      |> mes("fo pdi Wrdpp doff")
      |> mes("WosNuffremu Ha TurAshTi")
      |> mes("SeGothShar An AshDur")
      |> mes("UorVeLars No Ador")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp talk_quest(ctx, 0) do
    {ctx, _} =
      ctx
      |> mes("Recently, it seems like my skin is becoming really dry.")
      |> next()
      |> mes("[Dr. Lifeguard]")
      |> mes(
        "I don't know if it's caused by the cold weather or our chronic disease getting worse."
      )
      |> mes("It hasn't been too long since we administered the Bradium, so why.")
      |> next()
      |> mes("[Dr. Lifeguard]")
      |> mes("Huu... You see, we are afraid of such things... What a hard life.")
      |> next()
      |> select(["A chronic disease?", "Bradium?"])

    ctx
    |> mes("[Dr. Lifeguard]")
    |> mes(
      "We Sapha, who are descendants of Hwergelmir, survived and rebuilt the Giant tribe in the flood of the blood of Ymir."
    )
    |> next()
    |> mes("[Dr. Lifeguard]")
    |> mes(
      "For no apparent reason, we developed a chronic disease that makes our bodies dry and harden over time just like an old tree."
    )
    |> next()
    |> mes("[Dr. Lifeguard]")
    |> mes("I think that this is the curse of Ymir who bled by the gods?")
    |> next()
    |> mes("[Dr. Lifeguard]")
    |> mes(
      "But we couldn't just wait for death to slowly creep up on us and exterminate our entire race."
    )
    |> next()
    |> mes("[Dr. Lifeguard]")
    |> mes("To heal this rare disease the smartest Sapha studied and studied.")
    |> next()
    |> mes("[Dr. Lifeguard]")
    |> mes(
      "What they found was that by injecting a refined Bradium, which is buried around Jotunheim, it can postpone the progression of the disease."
    )
    |> next()
    |> mes("[Dr. Lifeguard]")
    |> mes(
      "So all of the giants of Sapha established their towns around mines to get Bradium easier."
    )
    |> next()
    |> mes("[Dr. Lifeguard]")
    |> mes("It seems the amount of buried Bradium is enough.")
    |> mes(
      "But for the eternal prosperity of our tribe, and to make the vaccine for this incurable disease, we have to study more and more."
    )
    |> next()
    |> mes("[Dr. Lifeguard]")
    |> mes("Bradium is the stem of our life.")
    |> mes(
      "But the buried Bradium will be exhausted someday, so we Scientists have to find an alternative for our descendants."
    )
    |> next()
    |> mes("[Dr. Lifeguard]")
    |> mes("Recently, we've learned that there are various minerals in the human world Midgard.")
    |> next()
    |> mes("[Dr. Lifeguard]")
    |> mes("Now the world called Midgard is")
    |> mes("like a holy place for us,")
    |> mes("which can bring the wind of")
    |> mes("revolution for us.")
    |> next()
    |> mes("[Dr. Lifeguard]")
    |> mes("Contact with Midgard")
    |> mes("must be the lead of Hwergelmir")
    |> mes("for us, the Sapha which has such")
    |> mes("a closed-off society.")
    |> next()
    |> mes("[Dr. Lifeguard]")
    |> mes("I'll draw a result that can")
    |> mes("satisfy his lead!")
    |> set_char_var(:ep13_2_tre, 1)
    |> close()
  end

  defp talk_quest(ctx, stage) when stage in [1, 100] do
    if checkweight(ctx, [{1201, 1}]) == 0 do
      ctx
      |> mes("It looks like you're carrying too many things.")
      |> mes("Why not put some of your items in storage and come back?")
      |> close()
    else
      ctx = set_local(ctx, :dayq_chk, checkquest(ctx, 2182, :playtime))

      if get_local(ctx, :dayq_chk, 0) in [0, 1] do
        ctx
        |> mes("The future of the Sapha is up to you.")
        |> mes("I do not have any need of your help right now.")
        |> close()
      else
        assign_quest(ctx)
      end
    end
  end

  defp talk_quest(ctx, stage) when stage in [2, 3, 4] do
    if (get_char_var(ctx, :ep13_2_tre, 0) == 2 and count_item(ctx, 6077) > 9) or
         (get_char_var(ctx, :ep13_2_tre, 0) != 2 and count_item(ctx, 6077) > 4) do
      ctx =
        ctx
        |> mes("Oh! Yes, that's it!")
        |> mes("This much will be enough!")
        |> next()
        |> mes("[Dr. Lifeguard]")
        |> mes("I really appreciate your help.")
        |> next()
        |> mes("[Dr. Lifeguard]")
        |> mes("These are coins of the Manuk.")
        |> mes(
          "This may not be much, but if you collect more, they can be used to buy some items from our merchants."
        )
        |> next()
        |> mes("[Dr. Lifeguard]")
        |> mes("If you want to help my study for the sake of the Sapha, come to me at any time.")
        |> mes("I will be very happy for any help you can give.")

      ctx = set_local(ctx, :stone_chk, count_item(ctx, 6077))
      ctx = set_local(ctx, :stoneelse_chk, count_item(ctx, 6078))
      ctx = delitem(ctx, 6077, get_local(ctx, :stone_chk, 0))

      ctx =
        ctx
        |> delitem(6078, get_local(ctx, :stoneelse_chk, 0))
        |> delitem(6076, 1)
        |> give_item(6080, 3)

      ctx
      |> changequest(2179 + (get_char_var(ctx, :ep13_2_tre, 0) - 2), 2182)
      |> set_char_var(:ep13_2_tre, 100)
      |> close()
    else
      ctx
      |> mes("The future of the Sapha is up to you.")
      |> mes("I wish you good luck.")
      |> close()
    end
  end

  defp talk_quest(ctx, _stage) do
    ctx |> mes("Hmm...") |> close()
  end

  defp assign_quest(ctx) do
    ctx = erasequest(ctx, 2182)
    destination = Enum.random(1..3)

    ctx =
      case destination do
        1 ->
          set_local(ctx, :"rand_dayq$", ["Mt. Mjolnir", "10", "2"])

        2 ->
          set_local(ctx, :"rand_dayq$", ["Abyss Lake", "5", "3"])

        3 ->
          set_local(ctx, :"rand_dayq$", ["Thor Volcano", "5", "4"])

        _ ->
          ctx
      end

    ctx =
      ctx
      |> mes(
        "Recently, someone who came from Schwarzwald gave me a small mineral as a gift from his home town when he saw our study of Bradium."
      )
      |> next()
      |> mes("[Dr. Lifeguard]")
      |> mes("I can't say for sure until now,")
      |> mes("but this mineral seems to have")
      |> mes("many interesting features.")
      |> next()
      |> mes("[Dr. Lifeguard]")
      |> mes("As I examine this mineral")
      |> mes("more and more, it's really")
      |> mes("different from the one in Jotunheim.")
      |> mes("This mineral must be helpful")
      |> mes("to make a new vaccine!")
      |> next()
      |> mes("[Dr. Lifeguard]")
      |> mes("But the amount of the mineral")
      |> mes("is too little to make a")
      |> mes("preparation for the")
      |> mes("examination.")
      |> next()
      |> mes("[Dr. Lifeguard]")
      |> mes(
        "You said you're from Midgard, right? Do you think you can bring me a little bit more of that mineral.."
      )
      |> next()
      |> mes("[Dr. Lifeguard]")
      |> mes("He said it's from")

    ctx =
      mes(
        ctx,
        Rathena.concat(
          Rathena.concat("^FF0000", Enum.at(get_local(ctx, :"rand_dayq$", []), 0, "")),
          "^000000."
        )
      )

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat(
            "I think ^FF0000",
            Enum.at(get_local(ctx, :"rand_dayq$", []), 1, "")
          ),
          "^000000 would be enough."
        )
      )
      |> next()
      |> mes("[Dr. Lifeguard]")
      |> mes("I'll give you this portable toolbox.")
      |> mes(
        "Things like a detector and a little hammer for mining minerals are included in this toolbox."
      )
      |> next()
      |> mes("[Dr. Lifeguard]")
      |> mes("Take it, it shold be")
      |> mes("helpful in collecting")
      |> mes("the minerals I need.")

    ctx =
      set_char_var(
        ctx,
        :ep13_2_tre,
        Rathena.atoi(Enum.at(get_local(ctx, :"rand_dayq$", []), 2, ""))
      )

    ctx
    |> setquest(2179 + (Rathena.atoi(Enum.at(get_local(ctx, :"rand_dayq$", []), 2, "")) - 2))
    |> give_item(6076, 1)
    |> close()
  end
end

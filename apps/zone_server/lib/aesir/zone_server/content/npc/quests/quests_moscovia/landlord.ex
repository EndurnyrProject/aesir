defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Landlord do
  @moduledoc """
  The landlord operates the Sticky Herb Tree inn.

  ## Behavior

  - Offers a save point and paid rest, and shares clues about Mikhail.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_in",
        x: 135,
        y: 191,
        dir: 5,
        sprite: 961,
        name: "Landlord",
        scope: :shared,
        unique_name: "Landlord#mos"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Landlord]")
      |> mes("Oh, welcome to the Inn 'Sticky Herb Tree'.")
      |> mes("It is the most comfortable and calmest place in all of Moscovia.")
      |> next()

    if get_char_var(ctx, :mos_swan, 0) in [4, 5] do
      ctx
      |> mes("[Landlord]")
      |> mes("You're up already?")
      |> mes("Well since you're young you've probably already recovered all of your strength.")
      |> mes("Hohoho.")
      |> next()
      |> ask_about_inn()
    else
      inn_menu(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp inn_menu(ctx) do
    {ctx, choice} =
      select(
        ctx,
        Enum.flat_map(
          [
            "Save",
            "Stay the night - 5000z",
            if(get_char_var(ctx, :mos_swan, 0) == 3, do: "Ask her about Mikhail.", else: "")
          ],
          &String.split(&1, ":")
        )
      )

    case choice do
      1 ->
        ctx
        |> mes("[Landlord]")
        |> mes("Your respawn point has been saved.")
        |> mes("Hope we can see you again next time hoho.")
        |> savepoint("mosk_in", 142, 189)
        |> close()

      2 ->
        stay(ctx)

      3 ->
        ask_for_information(ctx)

      _ ->
        ctx
    end
  end

  defp stay(ctx) do
    if zeny(ctx) > 4999 do
      ctx = mes(ctx, "[Landlord]")

      ctx =
        if get_char_var(ctx, :mos_swan, 0) == 3 do
          ctx
          |> mes("Ok, I'll bring you the best room.")
          |> mes("Please have a rest, young adventurer.")
        else
          mes(ctx, "Please be comfortable.")
        end

      rest(ctx)
    else
      ctx
      |> mes("[Landlord]")
      |> mes("The service charge is 5000z.")
      |> mes("Please make sure you have enough money for the service.")
      |> close()
    end
  end

  defp ask_for_information(ctx) do
    ctx = ctx |> mes("[Landlord]") |> emotion(:throb)

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat(
            "Oh~! You look great! Look at the ",
            if(sex(ctx) == 1, do: "solid muscle", else: "fair skin")
          ),
          "!"
        )
      )
      |> mes("But you look tired. Is it because of a long journey?")
      |> next()
      |> mes("[Landlord]")

    ctx =
      mes(
        ctx,
        Rathena.concat(
          "We've got a room available just for you. ",
          if(sex(ctx) == 1,
            do: "It's the best in town. How about staying the night?",
            else: "It's like a princess' room."
          )
        )
      )

    ctx =
      ctx
      |> mes(
        if sex(ctx) == 1,
          do: "I'll charge you at reasonable price for you, handsome guy.",
          else: "How about staying the night? I'll mark down the price for you, beautiful lady."
      )
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Oh, I'm sorry but I didn't come to stay here.")
      |> mes("I'm looking for a kid and I've got something to ask you...")
      |> next()
      |> emotion(:huk)
      |> mes("[Landlord]")
      |> mes("What!?!?")
      |> next()
      |> mes("[Landlord]")
      |> mes("Hey~ You've heard about 'give and take'?")
      |> mes("Haven't you?")
      |> mes("If you're my customer, I could offer you what you want but you're not!")
      |> next()
      |> mes("[Landlord]")
      |> mes(
        "If you promise me to stay overnight, I'll tell you about what you want to know. Deal?"
      )
      |> next()
      |> select(["Refuse.", "Stay overnight and get the info. - 5000z"])

    cond do
      choice == 1 ->
        ctx
        |> emotion(:anger)
        |> mes("[Landlord]")
        |> mes("Well, get the info by yourself then.")
        |> close()

      zeny(ctx) < 5000 ->
        ctx
        |> mes("[Landlord]")
        |> mes("No way. You don't have enough money.")
        |> mes("Go away! I can't offer you a room.")
        |> close()

      true ->
        ctx
        |> prepare_room()
        |> rest()
    end
  end

  defp prepare_room(ctx) do
    ctx
    |> mes("[Landlord]")
    |> mes("Oh, God! You're as great as you look~")
    |> mes("Ok, I'll bring you to the room in a bit!!")
    |> next()
    |> mes("[Landlord]")
    |> mes("Come on, please follow me with your luggage.")
    |> mes("Oh, let me carry them. Hohoho, you must be exhausted.")
    |> mes("I wish you a good night's rest. Hohoho.")
    |> set_char_var(:mos_swan, 4)
  end

  defp rest(ctx) do
    ctx
    |> close2()
    |> pay_zeny(5000)
    |> percent_heal(hp: 100, sp: 100)
    |> warp("mosk_in", 215, 181)
  end

  defp ask_about_inn(ctx) do
    {ctx, choice} =
      select(ctx, ["Ask her about the inn", "Ask her about Mikhail.", "End the conversation"])

    case choice do
      1 ->
        ctx
        |> mes("[Landlord]")
        |> mes("The name of our inn came from a big apple tree which is outside of the village.")
        |> mes(
          "I hope our inn will be the most famous place in Moscovia like the apple tree that distinguishes itself in the thick wood."
        )
        |> next()
        |> ask_about_inn()

      2 ->
        share_clue(ctx)

      3 ->
        end_conversation(ctx)

      _ ->
        ctx
    end
  end

  defp share_clue(ctx) do
    ctx
    |> mes("[Landlord]")
    |> mes("Mikhail?")
    |> mes("Ah! You're talking about a cute boy, Mr. Ibanoff's son?")
    |> mes("Yes I saw him. He was here a few hours ago.")
    |> next()
    |> mes("[Landlord]")
    |> mes(
      "He looked pale and asked me for a high-strength adhesive. He might've broken something important."
    )
    |> next()
    |> mes("[Landlord]")
    |> mes(
      "I felt sorry for him because he was so tense. He's such a sweet boy. I'd like to make him my son."
    )
    |> mes("Hohoho")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("So what happened?")
    |> mes("Did Mikhail get it?")
    |> next()
    |> mes("[Landlord]")
    |> mes("Hoho, I don't really know. Maybe my husband does...")
    |> mes("He's not much to look at, but he's good at repairing and making stuff! hoho")
    |> next()
    |> mes("[Landlord]")
    |> mes(
      "But it's been a long time since he was out of Moscovia so I can't ask him how to make adhesives now..."
    )
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("......And then?")
    |> next()
    |> mes("[Landlord]")
    |> mes("I told him to go to the pub over there.")
    |> mes("I also told him not to drink what those guys offer to him!")
    |> mes("Cause he's such a cute boy!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("So, did he go there?")
    |> next()
    |> mes("[Landlord]")
    |> mes("Yes he did-.")
    |> mes("As he's a good boy, he would go there.")
    |> mes("He's really gentle.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("OK. Thank you for your answers!")
    |> next()
    |> mes("[Landlord]")
    |> mes("I was unkind to make you stay here but wasn't it easier for you? hoho.")
    |> mes("When it gets dark, promise me to come here again. Hoho")
    |> set_char_var(:mos_swan, 7)
    |> changequest(18061, 18062)
    |> close()
  end

  defp end_conversation(ctx) do
    ctx
    |> mes("[Landlord]")
    |> mes("When you need to take a rest, where will you go?")
    |> next()
    |> mes("[Landlord]")
    |> mes("You should come back here to Inn 'Sticky Herb Tree'. Ok?")
    |> mes("I'll offer you better service next time.")
    |> close()
  end
end

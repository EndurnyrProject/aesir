defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Hunter.GuildReceptionist do
  @moduledoc """
  Demon Hunter who registers Hunter applicants for the arrow material test.

  ## Behavior

  - Confirms the applicant's name and sends away those who keep joking about it.
  - Assigns one of seven random material sets, with renewal-specific items in some sets.
  - Collects the materials and directs the applicant to the Guildmaster in Payon or at the Archer Guild.
  - Lists the required materials when the applicant has not gathered them all.

  ## Credits

  - Original from rAthena, authors and Contributors
    - EREMES THE CANIVALIZER
    - yoshiki
    - kobra_k88
    - Lupus
    - celest
    - Poki#3
    - Vicious
    - Silent
    - FlavioJS
    - Samuray22
    - L0ne_W0lf
    - Kisuka
    - Vali

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_in01",
        x: 382,
        y: 382,
        dir: 4,
        sprite: 732,
        name: "Guild Receptionist",
        scope: :shared,
        unique_name: "Guild Receptionist#hnt"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest = get_char_var(ctx, :HNTR_Q, 0)

    cond do
      quest == 2 ->
        confirm_name(ctx)

      quest >= 3 and quest <= 9 ->
        check_materials(ctx)

      quest > 9 and quest < 17 ->
        ctx
        |> mes("[Demon Hunter]")
        |> mes(
          "Hmm? You didn't go to the Guildmaster either in Payon Central Palace or at the Archer Guild? He should be at one of the two places, so go look for him."
        )
        |> close()

      quest == 17 ->
        ctx
        |> mes("[Demon Hunter]")
        |> mes("Ooh. You passed the test. Congratulations~ You should go talk to Sherin now.")
        |> close()

      true ->
        ctx
        |> mes("[Guild Receptionist]")
        |> mes("If you wish to change your job to a Hunter, you must register first.")
        |> close()
    end
  end

  defp confirm_name(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Guild Receptionist]")
      |> mes(
        "Greetings. They call me... ^660000The Demon Hunter^000000. I am the one in charge of processing applications. Your name is ... #{char_name(ctx, 0)}, correct?"
      )
      |> next()
      |> select(["Yes, that is correct.", "Nope~~(heeheehee)"])

    if choice == 2, do: reconfirm_name(ctx), else: assign_materials(ctx)
  end

  defp reconfirm_name(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Demon Hunter]")
      |> mes("Hey, stop messing around.")
      |> mes("Your name is #{char_name(ctx, 0)}, right?")
      |> next()
      |> select(["Yes...", "Hehehe. I keep telling you, it's not~~"])

    if choice == 2 do
      ctx
      |> mes("[Demon Hunter]")
      |> mes(
        "Leave if you plan to trifle me your petty tricks. Do you not realize that you are toying with ^660000The Demon Hunter^000000?!'"
      )
      |> close()
      |> warp("hugel", 208, 223)
    else
      assign_materials(ctx)
    end
  end

  defp assign_materials(ctx) do
    ctx =
      ctx
      |> mes("[Demon Hunter]")
      |> mes(
        "Okay. These are the items you need for the test. Since we provide all the arrows you will be using for this test, we need you to get the materials to make them."
      )
      |> next()
      |> mes("[Demon Hunter]")
      |> mes(
        "You see, we're having some financial problems. Let's see, we're short on these items..."
      )
      |> next()

    renewal? = checkre(ctx, 0) == 1
    roll = Enum.random(1..7)
    stage = roll + 2
    [{tip, tip_amount}, {part, part_amount}, {extra, extra_amount}] = materials(stage, renewal?)

    ctx =
      ctx
      |> changequest(4001, 4001 + roll)
      |> mes("[Demon Hunter]")
      |> mes(
        "Hmm. ^660000#{tip_amount} #{Rathena.getitemname(tip)}^000000 to use for arrow tips. ^660000#{part_amount} #{Rathena.getitemname(part)}^000000 to use here and there. And ^660000#{extra_amount} #{Rathena.getitemname(extra)}^000000 please."
      )
      |> set_char_var(:HNTR_Q, stage)
      |> next()
      |> mes("[Demon Hunter]")

    ctx =
      if get_char_var(ctx, :HNTR_Q, 0) >= 5 do
        mes(
          ctx,
          "By the way, a member of our Hunter Guild is at the Archer Guild on official business. I believe you have to go visit this person since he is in charge of the testing."
        )
      else
        ctx
        |> mes(
          "Oh right. Our Guildmaster has gone on an official trip to the Payon Central Palace. You have to go visit him because the one that administers the test."
        )
        |> mes("You can find him in a building east of the Payon Central Palace.")
      end

    ctx
    |> next()
    |> mes("[Demon Hunter]")
    |> mes("Alright then, come back to me when you have everything ready~")
    |> close()
  end

  defp check_materials(ctx) do
    stage = get_char_var(ctx, :HNTR_Q, 0)
    materials = materials(stage, checkre(ctx, 0) == 1)

    ctx =
      ctx
      |> mes("[Demon Hunter]")
      |> mes("Hmm?")
      |> next()

    if Enum.all?(materials, fn {item, amount} -> count_item(ctx, item) >= amount end) do
      hand_in_materials(ctx, materials, next_stage(stage))
    else
      list_materials(ctx, materials)
    end
  end

  defp hand_in_materials(ctx, materials, next_stage) do
    ctx =
      ctx
      |> set_char_var(:HNTR_Q, next_stage)
      |> advance_quest()

    ctx =
      materials
      |> Enum.reduce(ctx, fn {item, amount}, acc -> delitem(acc, item, amount) end)
      |> mes("[Demon Hunter]")

    if get_char_var(ctx, :HNTR_Q, 0) == 10 do
      ctx
      |> mes(
        "You brought all of the necessary materials... You can get directions to the testing area from our Guildmaster who is currently in the Payon Central Palace."
      )
      |> close()
    else
      ctx
      |> mes(
        "You brought all of the necessary materials... To get directions to the testing area, go talk to our Guildmaster who is at the Archer Guild."
      )
      |> close()
    end
  end

  defp advance_quest(ctx) do
    cond do
      isbegin_quest(ctx, 4002) == 1 -> changequest(ctx, 4002, 4009)
      isbegin_quest(ctx, 4003) == 1 -> changequest(ctx, 4003, 4009)
      isbegin_quest(ctx, 4004) == 1 -> changequest(ctx, 4004, 4009)
      isbegin_quest(ctx, 4005) == 1 -> changequest(ctx, 4005, 4009)
      isbegin_quest(ctx, 4006) == 1 -> changequest(ctx, 4006, 4010)
      isbegin_quest(ctx, 4007) == 1 -> changequest(ctx, 4007, 4010)
      true -> changequest(ctx, 4008, 4010)
    end
  end

  defp list_materials(ctx, [{tip, tip_amount}, {part, part_amount}, {extra, extra_amount}]) do
    ctx
    |> mes("[Demon Hunter]")
    |> mes("You don't have all")
    |> mes("of the required materials...")
    |> next()
    |> mes("[Demon Hunter]")
    |> mes("The items you need are")
    |> mes("^660000#{tip_amount} #{Rathena.getitemname(tip)}^000000,")
    |> mes("^660000#{part_amount} #{Rathena.getitemname(part)}^000000 and")
    |> mes("^660000#{extra_amount} #{Rathena.getitemname(extra)}^000000.")
    |> mes("Come back once you have")
    |> mes("gathered all the items.")
    |> close()
  end

  defp materials(3, renewal?), do: [{if(renewal?, do: 928, else: 7030), 5}, {1019, 5}, {509, 3}]
  defp materials(4, _renewal?), do: [{925, 3}, {932, 5}, {511, 3}]
  defp materials(5, renewal?), do: [{if(renewal?, do: 1013, else: 937), 3}, {919, 3}, {507, 5}]

  defp materials(6, renewal?) do
    [{if(renewal?, do: 947, else: 1021), 3}, {if(renewal?, do: 7033, else: 7032), 3}, {914, 10}]
  end

  defp materials(7, _renewal?), do: [{935, 9}, {955, 9}, {508, 9}]
  defp materials(8, _renewal?), do: [{913, 3}, {938, 1}, {948, 1}]
  defp materials(9, _renewal?), do: [{1027, 2}, {942, 1}, {1026, 1}]
  defp materials(_stage, _renewal?), do: [{0, 0}, {0, 0}, {0, 0}]

  defp next_stage(stage) when stage in 3..6, do: 10
  defp next_stage(stage) when stage in 7..9, do: 11
  defp next_stage(_stage), do: 0
end

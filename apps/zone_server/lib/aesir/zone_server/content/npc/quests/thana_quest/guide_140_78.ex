defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.Guide14078 do
  @moduledoc """
  Liei exchanges mission proof for zeny.

  ## Behavior

  - Explains employment and exchanges all selected proof items for rewards.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "tha_t01",
        x: 140,
        y: 78,
        dir: 4,
        sprite: 831,
        name: "Guide",
        scope: :shared,
        unique_name: "Guide#reward"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FGetplural
  alias Aesir.ZoneServer.Content.Npc.Functions.FInsertplural
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = mes(ctx, "[Liei]")

    if get_char_var(ctx, :thana_tower, 0) == 0 do
      introduction(ctx)
    else
      reward_menu(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp introduction(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Good day, I'm")
      |> mes("Liei Kuniziet of the")
      |> mes("Employee Mission")
      |> mes("Reward Department")
      |> mes("here in Thanatos Tower.")
      |> next()
      |> select(["Employee's mission reward?", "Keep up the good work."])

    case choice do
      1 ->
        ctx
        |> mes("[Liei]")
        |> mes("Currently, Rekenber Corporation")
        |> mes("is contracting temp employees")
        |> mes("to develop the higher levels")
        |> mes("of Thanatos Tower. If you'd")
        |> mes("like to apply, please ask")
        |> mes("Ditze right next to me.")
        |> close()

      2 ->
        ctx
        |> mes("[Liei]")
        |> mes("Thank you. Ah, and I hope")
        |> mes("that you enjoy your visit")
        |> mes("here to Thanatos Tower.")
        |> close()

      _ ->
        ctx
    end
  end

  defp reward_menu(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Ah, hello~")
      |> mes("How may I help you?")
      |> next()
      |> select(["Reward", "Nothing"])

    if choice == 2 do
      ctx
      |> mes("[Liei]")
      |> mes("Alright, then.")
      |> mes("Please do your best")
      |> mes("to exterminate the")
      |> mes("monsters that infest")
      |> mes("the higher floors of")
      |> mes("the Thanatos Tower~")
      |> close()
    else
      choose_proof(ctx)
    end
  end

  defp choose_proof(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Liei]")
      |> mes(Rathena.concat(Rathena.concat("You're ", char_name(ctx, 0)), ", yes?"))
      |> mes("Let me check our temp")
      |> mes("employee records for--ah.")
      |> mes("Here it is. Alright, so would")
      |> mes("you please tell me what kind")
      |> mes("of mission proof you brought?")
      |> next()
      |> select(["Golden Ornament", "Red Feather", "Blue Feather", "Cursed Seal"])

    item = Enum.at([0, 7435, 7440, 7441, 7442], choice, 0)
    ctx = mes(ctx, "[Liei]")

    if not Rathena.truthy?(count_item(ctx, item)) do
      ctx = mes(ctx, "I'm sorry, but you are not")

      {ctx, plural} =
        FGetplural.call(ctx, [Rathena.getitemname(item)])

      ctx
      |> mes(Rathena.concat(Rathena.concat("carrying any ", plural), "."))
      |> mes("Please check your inventory")
      |> mes("one more time, and then come")
      |> mes("to me to redeem your items")
      |> mes("for a reward later, alright?")
      |> close()
    else
      exchange(ctx, item)
    end
  end

  defp exchange(ctx, item) do
    ctx =
      ctx
      |> mes("The reward for each")
      |> mes(Rathena.concat(Rathena.getitemname(item), " is..."))
      |> mes(" ")
      |> mes("1,000 zeny")
      |> next()

    reward = count_item(ctx, item) * 1000
    ctx = mes(ctx, "[Liei]")

    {ctx, quantity} =
      FInsertplural.call(ctx, [
        count_item(ctx, item),
        Rathena.getitemname(item)
      ])

    ctx =
      ctx
      |> mes(Rathena.concat(quantity, ", then"))
      |> mes("you will receive a total of...")
      |> mes(" ")
      |> mes(Rathena.concat(Rathena.concat("", reward), " zeny"))
      |> next()
      |> mes("[Liei]")
      |> mes("Would you like to exchange")

    {ctx, plural} =
      FGetplural.call(ctx, [Rathena.getitemname(item)])

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat("all of your ", plural))
      |> mes("for your reward right now?")
      |> next()
      |> select(["Yes", "No"])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Liei]")
          |> mes("Great! Here is your")
          |> mes(Rathena.concat(reward, " zeny. Thank you,"))
          |> mes("and please keep up")
          |> mes("the good work~")

        ctx |> delitem(item, count_item(ctx, item)) |> credit_zeny(reward) |> close()

      2 ->
        ctx
        |> mes("[Liei]")
        |> mes("Sure, no problem.")
        |> mes("Just come back and")
        |> mes("talk to me whenever")
        |> mes("you want to receive")
        |> mes("your reward, alright?")
        |> close()

      _ ->
        ctx
    end
  end
end

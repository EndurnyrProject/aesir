defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.OddGrandma do
  @moduledoc """
  The confused grandmother recalls Allysia during the Kiel Hyre investigation.

  ## Behavior

  - Advances the investigation when asked about her imaginary baby.
  - Recognizes Allysia when shown her portrait and later offers reassurance.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "yuno", x: 257, y: 140, dir: 4, sprite: 846, name: "Odd Grandma", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest_stage < 54 ->
        ctx
        |> mes("[Grandma]")
        |> mes("Where did you go,")
        |> mes("my darling? Where")
        |> mes("are you, my little dear?")
        |> close()

      quest_stage == 54 ->
        ask_about_baby(ctx)

      quest_stage >= 56 and quest_stage < 60 ->
        ask_about_allysia(ctx)

      quest_stage >= 60 ->
        ctx
        |> mes("[Grandma]")
        |> mes("Don't worry, Allysia...")
        |> mes("Mommy will always be")
        |> mes("here for you. There's no")
        |> mes("need to be sad...")
        |> close()

      true ->
        ctx
    end
  end

  defp ask_about_baby(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Grandma]")
      |> mes("Lullabye...")
      |> mes("Say goodnight...")
      |> mes("Hush little baby...")
      |> mes("Go to sleeeeep~")
      |> next()
      |> select(["What are you doing?", "Um, I don't see a baby..."])

    case choice do
      1 ->
        hear_about_baby(ctx)

      2 ->
        ctx
        |> mes("[Grandma]")
        |> mes("What are you...?")
        |> mes("Oh, look at that.")
        |> mes("You made my little")
        |> mes("darling cry! Shhh,")
        |> mes("hush, little ^0000FFAllysia^000000.")
        |> mes("Go to sleeeeeeep~")
        |> close()

      _ ->
        ctx
    end
  end

  defp hear_about_baby(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Grandma]")
      |> mes("Oh? My baby won't stop")
      |> mes("crying and can't seem")
      |> mes("to sleep. She needs to")
      |> mes("rest, so I can go to work.")
      |> mes("The house is so messy,")
      |> mes("and the boss is unhappy...")
      |> set_char_var(:KielHyreQuest, 56)
      |> next()
      |> select(["Um, I don't see a baby..."])

    ctx
    |> mes("[Grandma]")
    |> mes("What, she's right--")
    |> mes("Well. Darling, what")
    |> mes("are you doing? Don't")
    |> mes("misbehave in front of")
    |> mes("our friend! Shhh, be")
    |> mes("good, my little girl.")
    |> close()
  end

  defp ask_about_allysia(ctx) do
    ctx =
      ctx
      |> mes("[Grandma]")
      |> mes("Allysia...?!")
      |> mes("Allysia, where did")
      |> mes("you go? You were")
      |> mes("supposed to come")
      |> mes("home a while ago!")

    if count_item(ctx, 7500) < 1 do
      close(ctx)
    else
      {ctx, choice} = ctx |> next() |> select(["Allysia? Isn't she..."])

      case choice do
        1 -> show_portrait(ctx)
        _ -> ctx
      end
    end
  end

  defp show_portrait(ctx) do
    ctx
    |> cutin("kh_ellisia_port", 1)
    |> mes("^3355FFYou show Allysia's")
    |> mes("portrait to the old woman.^000000")
    |> next()
    |> cutin("", 255)
    |> mes("[Grandma]")
    |> mes("Oh, do you know")
    |> mes("Allysia? She's been")
    |> mes("missing! She left home")
    |> mes("yesterday and hasn't")
    |> mes("come back! C-can you")
    |> mes("tell me where she is?!")
    |> close()
  end
end

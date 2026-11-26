defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Lowentrace1 do
  @moduledoc """
  A trace of Lowen lets players speak to her spirit during the Brisingamen seal quest.

  ## Behavior

  - Offers a first encounter and later summons Lowen when the seal is active.
  - Sends eligible players into her past and reacts to nearby quest participants.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
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
        map: "gef_dun01",
        x: 203,
        y: 48,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#lowentrace1",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :god_brising, 0) > 9 and get_char_var(ctx, :god_brising, 0) < 34 do
      emotion(ctx, :surprise)
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check1", 0) ->
        old_wood(ctx)

      get_server_var(ctx, "God3", 0) >= get_server_temp_var(ctx, "god_check2", 0) ->
        old_wood(ctx)

      get_char_var(ctx, :god_brising, 0) > 20 and get_char_var(ctx, :god_brising, 0) < 34 ->
        summon(ctx)

      get_char_var(ctx, :god_brising, 0) == 20 ->
        first_encounter(ctx)

      true ->
        ctx
        |> mes(
          "^3355FFYou find a piece of twisted, dry wood. Looking at it seems to bring out a feeling of sadness within you for some reason.^000000"
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp old_wood(ctx) do
    ctx |> mes("^3355FFIt's just an old,") |> mes("dry piece of wood.^000000") |> close()
  end

  defp summon(ctx) do
    {ctx, choice} =
      ctx |> mes("Would you") |> mes("like to summon her? ") |> next() |> select(["Yes", "No"])

    case choice do
      1 ->
        {ctx, name} = input(ctx, :string)
        ctx = set_temp_var(ctx, :"lowenstring$", name)

        if get_temp_var(ctx, :"lowenstring$", "") == "Lowen" do
          summoned_lowen(ctx)
        else
          close(ctx)
        end

      2 ->
        close(ctx)

      _ ->
        ctx
    end
  end

  defp summoned_lowen(ctx) do
    case get_char_var(ctx, :god_brising, 0) do
      31 ->
        {ctx, choice} =
          ctx
          |> mes("[Lowen Ellenen]")
          |> mes("^6E7B8BYou came back!")
          |> mes("You'll be with me")
          |> mes("...Won't you?^000000")
          |> next()
          |> select(["Of course.", "Sorry, I don't think I can..."])

        case choice do
          1 ->
            ctx
            |> mes("[Lowen Ellenen]")
            |> mes("^6E7B8BThank you,")
            |> mes("thank you so much...^000000")
            |> close2()
            |> warp("que_god02", 47, 53)

          2 ->
            ctx
            |> mes("[Lowen Ellenen]")
            |> mes("^6E7B8BI understand.")
            |> mes("Please take")
            |> mes("care of yourself...^000000")
            |> close()

          _ ->
            ctx
        end

      30 ->
        ctx
        |> mes("[Lowen Ellenen]")
        |> mes("^6E7B8BAh yes. This is it.")
        |> mes(
          "You look very curious about me, yet I am amazed that you can hear my voice. Please let me tell you an old story.^000000"
        )
        |> close2()
        |> warp("que_god02", 47, 53)

      25 ->
        ctx
        |> mes("[Lowen Ellenen]")
        |> mes("^6E7B8BYou've come back.")
        |> mes("Have you met Rosa?")
        |> mes(
          "Hm, yes, it sounds like she'd say that. But thank you for sending her my message.^000000"
        )
        |> next()
        |> mes("[Lowen Ellenen]")
        |> mes("^6E7B8BAh, it's too dangero--")
        |> mes(
          "This place is too dangerous for you. I hate myself for not being able to help protect you from"
        )
        |> mes("these evil creatures. Be careful...^000000")
        |> close()

      _ ->
        ctx
        |> mes("[Lowen Ellenen]")
        |> mes("^6E7B8BMy spirit is")
        |> mes("growing weaker...")
        |> mes("Please be careful...")
        |> mes("This place is too dangerous.^000000")
        |> close()
    end
  end

  defp first_encounter(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[The voice of a female]")
      |> mes("^6E7B8BI-It's dangerous...")
      |> mes("Be careful...^000000")
      |> next()
      |> select(["Ignore it.", "What are you talking about?"])

    case choice do
      1 -> close(ctx)
      2 -> hear_lowen(ctx)
      _ -> ctx
    end
  end

  defp hear_lowen(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[The voice of a female]")
      |> mes("^6E7B8B...No way...")
      |> mes("You can hear me?")
      |> mes("I can't believe this.")
      |> mes("It's impossible...")
      |> mes("But if you don't mind,")
      |> mes("may I talk to you...?^000000")
      |> next()
      |> select(["Holy...! Run!", "What are you?!"])

    case choice do
      1 ->
        close(ctx)

      2 ->
        ctx
        |> mes("[The voice of a female]")
        |> mes("^6E7B8BI...")
        |> mes(
          "I don't have my body anymore, so... I think I'm a ghost. Yes, I've been wandering in this place ever since I got here.^000000"
        )
        |> next()
        |> mes("[The voice of a female]")
        |> mes("^6E7B8BI'm still not sure why I'm")
        |> mes("bound to this realm. If you")
        |> mes("don't mind, would you visit")
        |> mes("my sister for me?")
        |> next()
        |> mes("[The voice of a female]")
        |> mes("^6E7B8BPlease tell her...")
        |> mes("Please tell her that her")
        |> mes("little sister Lowen is fine.^000000")
        |> next()
        |> mes("[The voice of a female]")
        |> mes("^6E7B8BUm...")
        |> mes(
          "If you want to meet me again, just say my name out loud. '^000000Lowen^6E7B8B.'^000000"
        )
        |> set_char_var(:god_brising, 21)
        |> close()

      _ ->
        ctx
    end
  end
end

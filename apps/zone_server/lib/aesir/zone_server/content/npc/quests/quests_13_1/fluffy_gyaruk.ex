defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.FluffyGyaruk do
  @moduledoc """
  Fluffy Gyaruk, the Cat Trading representative who explains the company and takes on new
  members.

  ## Behavior

  - Below one Cat Trading Point only sniffs for fish and tells the player to come back.
  - With one point runs the whole membership pitch (company story, services, credit) and, on
    acceptance, sets `ep13_yong1` to 2.
  - With three points explains the daily fishing and mining work, setting the credit to 4 when
    the player agrees to start.
  - With four points points at the two Cat Agents, and with any other credit reports the current
    points and how to raise them.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "mid_camp", x: 72, y: 94, dir: 4, sprite: 421, name: "Fluffy Gyaruk", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_yong1, 0) do
      credit when credit < 1 -> no_fish_smell(ctx)
      1 -> membership_pitch(ctx)
      3 -> daily_work_pitch(ctx)
      4 -> cat_agents_hint(ctx)
      _credit -> credit_status(ctx)
    end
  end

  defp no_fish_smell(ctx) do
    ctx
    |> mes("[Fluffy Gyaruk]")
    |> mes("*Sniff Sniff* Can't you smell fish")
    |> mes("around here?")
    |> close()
  end

  defp membership_pitch(ctx) do
    {ctx, _} = company_story(ctx)

    {ctx, choice} =
      ctx
      |> mes("[Fluffy Gyaruk]")
      |> mes(
        "As you might know already, we're a considerably small company struggling to make ends meet in this niche market."
      )
      |> mes("We desperately need your support to grow.")
      |> next()
      |> mes("[Fluffy Gyaruk]")
      |> mes(
        "You can increase your credit by helping us secure our food or by collecting minerals."
      )
      |> next()
      |> mes("[Fluffy Gyaruk]")
      |> mes(
        "The more credits you earn, the more services you can use. You can also apply for special events."
      )
      |> mes("Say, how'd you like to make a membership contract with us?")
      |> next()
      |> select(["Sure.", "I need to think it over."])

    case choice do
      1 -> join(ctx)
      2 -> declines(ctx)
      _ -> ctx
    end
  end

  defp company_story(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Fluffy Gyaruk]")
      |> mes("Hmm?")
      |> mes("Oh, did the Cat Paw Agent send you?")
      |> next()
      |> select(["Yes."])

    {ctx, _} =
      ctx
      |> mes("[Fluffy Gyaruk]")
      |> mes("Oh, okay...")
      |> mes("Well, where should I begin.")
      |> mes("(Mumble Mumble)")
      |> next()
      |> select(["What do you guys do?"])

    {ctx, _} =
      ctx
      |> mes("[Fluffy Gyaruk]")
      |> mes("Oh, sure.")
      |> mes("I can start from there.")
      |> mes("You used Kafra Corporation services on the Midgard Continent, didn't you?")
      |> next()
      |> select(["Yes."])

    {ctx, _} =
      ctx
      |> mes("[Fluffy Gyaruk]")
      |> mes("Cat Trading is a new trading company based on this undeveloped continent.")
      |> next()
      |> mes("[Fluffy Gyaruk]")
      |> mes("Well, frankly we wanted to join the Midgard Market, but it was too competitive...")
      |> mes("Not only that, they don't have enough fish for all of us either... (Mumble Mumble)")
      |> next()
      |> select(["What services do you offer?"])

    ctx
    |> mes("[Fluffy Gyaruk]")
    |> mes(
      "*Purr* Oh, our service range is similar to the Kafra's Location Saving, Storage Service, Warp Service, and more."
    )
    |> next()
    |> mes("[Fluffy Gyaruk]")
    |> mes(
      "The only difference is that, our services are limited depending on the customer's credit."
    )
    |> next()
    |> select(["Credit?"])
  end

  defp join(ctx) do
    ctx
    |> mes("[Fluffy Gyaruk]")
    |> mes("Excellent! Thank you for joining the Cat Trading membership service.")
    |> mes("We hope you'll support our exploration of this unknown land.")
    |> next()
    |> mes("[Fluffy Gyaruk]")
    |> mes("Please go speak to the Cat Paw Agent over there to use a basic service.")
    |> mes("Oh, and please come back afterwards.")
    |> set_char_var(:ep13_yong1, 2)
    |> close()
  end

  defp declines(ctx) do
    ctx
    |> mes("[Fluffy Gyaruk]")
    |> mes("How disappointing!")
    |> mes("But I understand.")
    |> close()
  end

  defp daily_work_pitch(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Fluffy Gyaruk]")
      |> mes("We offer one service to new customers.")
      |> mes("If you want to use more services, you must do some things for us.")
      |> next()
      |> select(["What kind of things?"])

    {ctx, choice} =
      ctx
      |> mes("[Fluffy Gyaruk]")
      |> mes("For now...")
      |> mes(
        "Please catch the main dish of the Cat Trading employees, fish, and collect minerals once every day."
      )
      |> mes("Your credit will increase each day if you do those things.")
      |> next()
      |> mes("[Fluffy Gyaruk]")
      |> mes("Of course, we'll reward you with a reasonable amount of EXP for the services.")
      |> next()
      |> mes("[Fluffy Gyaruk]")
      |> mes("This is a good opportunity to increase your credit and EXP ate the same time.")
      |> mes("Doesn't that sound like a win-win situation?")
      |> mes("Would you like to start now?")
      |> next()
      |> select(["Sure.", "I need to go prepare first."])

    case choice do
      1 -> start_working(ctx)
      2 -> not_ready(ctx)
      _ -> ctx
    end
  end

  defp start_working(ctx) do
    ctx
    |> mes("[Fluffy Gyaruk]")
    |> mes("Excellent.")
    |> mes(
      "For more information about fishing and mining, please speak to the two Cat Agents standing at the river over there."
    )
    |> set_char_var(:ep13_yong1, 4)
    |> close()
  end

  defp not_ready(ctx) do
    ctx
    |> mes("[Fluffy Gyaruk]")
    |> mes("No problem.")
    |> mes("Please take your time.")
    |> close()
  end

  defp cat_agents_hint(ctx) do
    ctx
    |> mes("[Fluffy Gyaruk]")
    |> mes(
      "For more information about fishing and mining, please speak to the two Cat Agents standing at the river over there."
    )
    |> close()
  end

  defp credit_status(ctx) do
    ctx = mes(ctx, "[Fluffy Gyaruk]")

    {ctx, choice} =
      ctx
      |> mes(
        "Your current credit points with us are ^0000FF#{get_char_var(ctx, :ep13_yong1, 0)}^000000."
      )
      |> next()
      |> select(["How can I increase my points?", "I'm not interested."])

    case choice do
      1 -> how_to_earn(ctx)
      2 -> close(ctx)
      _ -> ctx
    end
  end

  defp how_to_earn(ctx) do
    ctx
    |> mes("[Cat Paw Agent]")
    |> mes(
      "You can increase them daily by fishing and mining, you need to submit caught Pieces of Fish to Gorurung and minerals to the Mining Agent."
    )
    |> close()
  end
end

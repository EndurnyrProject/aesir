defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.LowenEllenen do
  @moduledoc """
  Lowen recounts her past and asks why she cannot rest.

  ## Behavior

  - Discusses her fallen comrades and the player’s offer to help.
  - Directs the player onward or returns unexpected visitors to Geffen.

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
        map: "que_god02",
        x: 48,
        y: 55,
        dir: 3,
        sprite: 745,
        name: "Lowen Ellenen",
        scope: :shared
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :god_brising, 0) do
      30 -> tell_story(ctx)
      31 -> stairs(ctx)
      _ -> send_back(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp tell_story(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lowen Ellenen]")
      |> mes("Can you see me now?")
      |> mes("You must be surprised.")
      |> mes("This is the story I will")
      |> mes("share with you.")
      |> next()
      |> mes("[Lowen Ellenen]")
      |> mes("Look around.")
      |> mes("Recognize it?")
      |> mes("We're still in the same place, except now we're in my past.")
      |> next()
      |> mes("[Lowen Ellenen]")
      |> mes(
        "All of us came here to Geffen to cleanse this area of evil spirits. You asked for the reason I remained in this awful place?"
      )
      |> next()
      |> mes("[Lowen Ellenen]")
      |> mes("I couldn't forgive myself for what I've done to my comrades. They")
      |> mes("were killed because of me.")
      |> next()
      |> select(["You were cursed...?", "You still have something to do."])

    case choice do
      1 -> cursed(ctx)
      2 -> offer_help(ctx)
      _ -> ctx
    end
  end

  defp cursed(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("You're saying...")
      |> mes("The anger of your")
      |> mes("comrades manifested")
      |> mes("into a curse?")
      |> next()
      |> mes("[Lowen Ellenen]")
      |> mes(
        "Cursed by my fallen comrades... Yes, that's what I thought at first. So I tried to redeem myself as well as avenge their deaths."
      )
      |> next()
      |> mes("[Lowen Ellenen]")
      |> mes("I have been trying my best to comfort their spirits for 2 years.")
      |> next()

    {ctx, _} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes(
        "Ever since you guys failed on a mission, you've spent two years here killing monsters?"
      )
      |> next()
      |> mes("[Lowen Ellenen]")
      |> mes("Yes, that's right.")
      |> mes("I thought it would bring comfort to the spirits of my comrades.")
      |> next()
      |> mes("[Lowen Ellenen]")
      |> mes(
        "But once I died, I met all of my old friends in Niflheim, the town of the dead. You've heard of it, haven't you?"
      )
      |> next()
      |> mes("[Lowen Ellenen]")
      |> mes("No one seemed to")
      |> mes("blame me for what")
      |> mes("had happened. In fact, they all seemed worried about me.")
      |> next()
      |> select(["Then why?"])

    ctx
    |> mes("[Lowen Ellenen]")
    |> mes(
      "They waited for me in Niflheim for two years, since they didn't want me to misunderstand them. They never blamed me for what happened."
    )
    |> next()
    |> mes("[Lowen Ellenen]")
    |> mes(
      "But I still feel like something is wrong. Out of all of us, I'm the only one unable to rest in peace. Everyone else was selected to go to Valhalla."
    )
    |> next()
    |> mes("[Lowen Ellenen]")
    |> mes(
      "But Valhalla is where all honorable Crusaders are supposed to go. What have I done wrong?"
    )
    |> close()
  end

  defp offer_help(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Lowen Ellenen]")
      |> mes(
        "I don't think I have any unfinished business. But who knows, maybe there is something I have to do."
      )
      |> next()
      |> mes("[Lowen Ellenen]")
      |> mes(
        "All of my late comrades that I met in Niflheim were selected by Valkyrie and sent to Valhalla. That's how honorable Crusaders spend the afterlife. But it looks like I don't deserve it..."
      )
      |> next()
      |> select(["I can help you!"])

    ctx =
      ctx
      |> mes("[Lowen Ellenen]")
      |> mes("You can")
      |> mes("help me?")
      |> mes("How...?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes(
        "You said this is the place where the subjugation mission happened, right? I'll fight with you!"
      )
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes(
        "Now come on, you don't deserve to feel guilty like this. Let's think about how we're gonna fight these monsters!"
      )
      |> next()
      |> mes("[Lowen Ellenen]")
      |> mes("...")
      |> mes("Thank you.")
      |> mes("Thank you so much.")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Now,")
    |> mes("shall we go in?")
    |> set_char_var(:god_brising, 31)
    |> close()
  end

  defp stairs(ctx) do
    ctx
    |> mes("[Lowen Ellenen]")
    |> mes("Walk down the stairs")
    |> mes("ahead. From this point")
    |> mes("I can only travel with")
    |> mes("you in your mind...")
    |> close()
  end

  defp send_back(ctx) do
    ctx
    |> mes("[Lowen Ellenen]")
    |> mes("How come...")
    |> mes("You're here?")
    |> close2()
    |> warp("geffen", 120, 101)
  end
end

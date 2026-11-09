defmodule Aesir.ZoneServer.Content.Npc.Floating.Cities.Gonryun.KunlunEnvoyGonryun do
  @moduledoc """
  Wa Bai Hu, envoy of Kunlun, who tells travelers about the city and sails them
  there.

  ## Behavior

  - Describes Kunlun's floating village, its food and the danger of the Kunlun
    dungeon, or offers the crossing.
  - The crossing costs 10,000 zeny: it is charged before the ship leaves and
    takes the player to the Kunlun harbour fields.
  - Declining, whichever menu it happens on, ends with the standing invitation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/gonryun.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 246,
        y: 62,
        dir: 3,
        sprite: 776,
        name: "Kunlun Envoy",
        scope: :renewal,
        unique_name: "Kunlun Envoy#gon"
      },
      %{
        map: "alberta",
        x: 245,
        y: 69,
        dir: 3,
        sprite: 776,
        name: "Kunlun Envoy",
        scope: :pre_renewal,
        unique_name: "Kunlun Envoy#gon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @fare 10_000

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Wa Bai Hu]")
      |> mes("Good day~")
      |> mes("Let me invite you all")
      |> mes("to my homeland, Kunlun.")
      |> mes("It is my honor to guide")
      |> mes("such distinguished quests from")
      |> mes("the Rune-Midgarts kingdom.")
      |> next()
      |> select(["About Kunlun", "Visit Kunlun", "Cancel"])

    case choice do
      1 -> describe_kunlun(ctx)
      2 -> offer_the_crossing(ctx)
      3 -> invitation(ctx)
      _ -> ctx
    end
  end

  defp describe_kunlun(ctx) do
    ctx
    |> mes("[Wa Bai Hu]")
    |> mes("Kunlun is a beautiful place,")
    |> mes("rich with history, and its")
    |> mes("own traditions. I also think")
    |> mes("Kunlun is the best place for")
    |> mes("sightseeing.")
    |> next()
    |> mes("[Wa Bai Hu]")
    |> mes("When you arrive at the harbor of")
    |> mes("Kunlun, you'll be able to see")
    |> mes("miniature replicas of")
    |> mes("buildings found in Alberta")
    |> mes("and Prontera.")
    |> next()
    |> mes("[Wa Bai Hu]")
    |> mes("After enjoying a nice, leisurely")
    |> mes("stroll, step into the beautiful")
    |> mes("column of light that will take")
    |> mes("you up into the clouds to")
    |> mes("Kunlun Village.")
    |> next()
    |> mes("[Wa Bai Hu]")
    |> mes("I've heard that on the")
    |> mes("Rune-Midgarts continent,")
    |> mes("there is another city that is")
    |> mes("is kept aloft in the sky by")
    |> mes("an ancient, mysterious power...")
    |> next()
    |> mes("[Wa Bai Hu]")
    |> mes("Well, my Kunlun also floats")
    |> mes("in the air, but without any")
    |> mes("so called technology or")
    |> mes("power supply. We consider")
    |> mes("our land especially blessed...")
    |> next()
    |> mes("[Wa Bai Hu]")
    |> mes("When you're in Kunlun, don't")
    |> mes("forget to try our specialties")
    |> mes("such as the giant dumpling or the heaven peach.")
    |> next()
    |> mes("[Wa Bai Hu]")
    |> mes("You'd better prepare yourself")
    |> mes("if you are planning to visit")
    |> mes("the Kunlun dungeon. I must")
    |> mes("say, that is not a safe place to go for fun.")
    |> next()
    |> mes("[Wa Bai Hu]")
    |> mes("If you are interested in visiting")
    |> mes("Kunlun, do not hesitate to let")
    |> mes("me know. It's my great pleasure")
    |> mes("to serve you, honorable guest.")
    |> close()
  end

  defp offer_the_crossing(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Wa Bai Hu]")
      |> mes("Excellent choice, I am glad")
      |> mes("to have you as our guest~")
      |> mes("However, a small fee is required")
      |> mes("to board the ship to Kunlun.")
      |> next()
      |> mes("[Wa Bai Hu]")
      |> mes("We ask that you pay 10,000 zeny")
      |> mes("prior to departure. That fee also")
      |> mes("covers the cost of returning")
      |> mes("to Alberta. I am ready to guide")
      |> mes("you to Kunlun at any time.")
      |> next()
      |> mes("[Wa Bai Hu]")
      |> mes("Would you like to board?")
      |> next()
      |> select(["To Kunlun~!", "No."])

    if answer == 1 do
      sail(ctx)
    else
      ctx
      |> mes("[Wa Bai Hu]")
      |> mes("I see. However, whenever you")
      |> mes("change your mind, please let")
      |> mes("me know. It would be a great")
      |> mes("please to serve you, most")
      |> mes("honorable guest.")
      |> close()
    end
  end

  defp sail(ctx) do
    if zeny(ctx) > 9_999 do
      ctx
      |> mes("[Wa Bai Hu]")
      |> mes("Thank you, let me guide you there immediately.")
      |> close()
      |> pay_zeny(@fare)
      |> warp("gon_fild01", 258, 82)
    else
      ctx
      |> mes("[Wa Bai Hu]")
      |> mes("I am sorry, but you must have")
      |> mes("10,000 zeny to travel to Kunlun.")
      |> mes("Please make sure you have enough")
      |> mes("zeny with you. Thank you, and")
      |> mes("please come again.")
      |> close()
    end
  end

  defp invitation(ctx) do
    ctx
    |> mes("[Wa Bai Hu]")
    |> mes("I see. However, whenever you")
    |> mes("change your mind, please let me")
    |> mes("know. It would be a great pleasure to serve you, most honorable guest.")
    |> close()
  end
end

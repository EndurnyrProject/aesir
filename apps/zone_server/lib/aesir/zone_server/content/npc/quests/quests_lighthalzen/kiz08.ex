defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Kiz08 do
  @moduledoc """
  A cursed spirit reveals a memory of the city.

  ## Behavior

  - Shows a memory and advances the curse at the appropriate stage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 272,
        y: 227,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#kiz08",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    if count_item(ctx, 7345) > 0 do
      case get_char_var(ctx, :lhz_curse, 0) do
        0 -> sc_start(ctx, :sc_curse, 1000, 0)
        curse when curse > 0 and curse < 26 -> witness_memory(ctx)
        _ -> ctx
      end
    else
      ctx
    end
  end

  defp witness_memory(ctx) do
    ctx =
      ctx
      |> mes("............")
      |> next()
      |> soundeffect("tao_gunka_stand.wav", 0)
      |> sc_start(:sc_blind, 60_000, 0)
      |> mes("............")
      |> next()
      |> mes("[????]")
      |> mes("Oh, I'm so sorry to")
      |> mes("hear that you want to")
      |> mes("quit. Are you sure there")
      |> mes("isn't anything we can do")
      |> mes("to change your mind?")
      |> next()
      |> mes("[???]")
      |> mes("Well, I'm thinking of")
      |> mes("retiring early and just")
      |> mes("spending more time")
      |> mes("with my family. But I won't")
      |> mes("ever talk about the company")
      |> mes("or any of its, well, secrets.")
      |> next()
      |> mes("[????]")
      |> mes("I really appreciate")
      |> mes("your honesty and sincerity.")
      |> mes("You've really done a great")
      |> mes("job for us and I can't thank")
      |> mes("you enough for your years of")
      |> mes("dedication to this company.")
      |> next()
      |> mes("[???]")
      |> mes("Thank you, sir.")
      |> next()
      |> mes("[????]")
      |> mes("It would be a great loss")
      |> mes("for this company to let you")
      |> mes("go now. But I guess we have")
      |> mes("no choice, since you've had")
      |> mes("that horrible accident.")
      |> next()
      |> mes("[???]")
      |> mes("Sir...?")
      |> mes("Accident...?")
      |> mes("I don't understand")
      |> mes("what you're talking ab--")
      |> next()
      |> mes("[???]")
      |> mes("N-no! Please...!")
      |> mes("I didn't, I swear on")
      |> mes("my life that I won't ever")
      |> mes("say anything about this")
      |> mes("place! I'm begging you,")
      |> mes("for the love of god!")
      |> next()
      |> mes("[????]")
      |> mes("Your life...?")
      |> mes("Sorry, not good enough.")
      |> mes("You should have known.")
      |> next()
      |> mes("[???]")
      |> mes("Ssstop! I have chil--")
      |> mes("MY LEEEEGS!! OH MY GOD")
      |> mes("WHAT HAVE YOU DONE TO")
      |> mes("MY LEGS?! HELP ME, OH MY G--")
      |> next()
      |> mes("............")
      |> next()
      |> mes("............")
      |> close2()
      |> soundeffect("tao_gunka_stand.wav", 0)
      |> sc_end(:sc_blind)
      |> sc_start(:sc_curse, 3000, 0)

    if get_char_var(ctx, :lhz_curse, 0) == 11 do
      set_char_var(ctx, :lhz_curse, 12)
    else
      ctx
    end
  end
end

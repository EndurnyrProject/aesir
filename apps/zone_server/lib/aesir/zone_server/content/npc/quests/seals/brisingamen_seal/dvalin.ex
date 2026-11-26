defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Dvalin do
  @moduledoc """
  Dvalin guides adventurers seeking the Brisingamen seal.

  ## Behavior

  - Reveals how to find Berling after the adventurer mentions Alfrik.
  - Hides again after each conversation and reminds returning visitors of their task.

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
        map: "prt_fild02",
        x: 185,
        y: 270,
        dir: 3,
        sprite: 826,
        name: "Dvalin",
        scope: :shared,
        unique_name: "Dvalin#1"
      }
    ]

  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :god_brising, 0) do
      stage when stage > 43 -> reminisce(ctx)
      42 -> ask_visitor(ctx)
      43 -> remind_visitor(ctx)
      _ -> ev_oninit(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_oninit(ctx), do: hideonnpc(ctx, "Dvalin#1")

  defp reminisce(ctx) do
    ctx
    |> mes("[Dvalin]")
    |> mes("A human?")
    |> mes("You woke me up?")
    |> next()
    |> mes("[Dvalin]")
    |> mes("Hmm...")
    |> mes(
      "And you'd be acting pretty pushy right about now if you were acting on behalf of a god. What could you want...?"
    )
    |> next()
    |> mes("[Dvalin]")
    |> mes(
      "It makes sense that you want a replica of Brisingamen for its power. But remember, we originally made Brisingamen as a necklace fit for a goddess."
    )
    |> next()
    |> mes("[Dvalin]")
    |> mes(
      "Some might say that we seduced Freya with the necklace, but we really loved her with all of our hearts."
    )
    |> close2()
    |> hideonnpc("Dvalin#1")
  end

  defp ask_visitor(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Dvalin]")
      |> mes("Wah, it's not Alfrik?")
      |> mes("Who are you to wake Dvalin?")
      |> mes("Tell me right now, or I'll...")
      |> mes("I'll kick your ass!")
      |> next()
      |> select(["Help!", "Alfrik sent me to wake you up!"])

    case choice do
      1 -> reject_visitor(ctx)
      2 -> guide_visitor(ctx)
      _ -> ctx
    end
  end

  defp reject_visitor(ctx) do
    ctx
    |> mes("[Dvalin]")
    |> mes("I don't know")
    |> mes("what the hell")
    |> mes("you're doing here,")
    |> mes("but leave!")
    |> close2()
    |> hideonnpc("Dvalin#1")
  end

  defp guide_visitor(ctx) do
    ctx =
      ctx
      |> mes("[Dvalin]")
      |> mes("Did you just say Alfrik sent you? How do you know my brother?!")
      |> next()
      |> mes("[Dvalin]")
      |> mes("Brisingamen?!")
      |> mes("Then, that means")
      |> mes("we can meet Freya again?!")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Umm...")
    |> mes("I'm afraid not.")
    |> mes("Or, at least, that's")
    |> mes("not why I'm here.")
    |> next()
    |> mes("[Dvalin]")
    |> mes("Okay...")
    |> mes("I understand.")
    |> mes("Sorry, I was just")
    |> mes("hoping you were a")
    |> mes("herald of Freya.")
    |> next()
    |> mes("[Dvalin]")
    |> mes("So, an imitation")
    |> mes("of Brisingamen...")
    |> mes(
      "Even if it's not the original, I'm sure it can possess power comparable to the real thing. Yes..."
    )
    |> next()
    |> mes("[Dvalin]")
    |> mes(
      "It's no use trying to predict the future, but I can't help but wonder what would mankind do with the power of the gods?"
    )
    |> next()
    |> mes("[Dvalin]")
    |> mes(
      "If my brother Alfrik already approved of you, then I'll help you out. I'll tell you how to wake my brother Berling."
    )
    |> next()
    |> mes("[Dvalin]")
    |> mes(
      "We hid ourselves near traces of Freya. The path where I am staying is one that my goddess has walked through."
    )
    |> next()
    |> mes("[Dvalin]")
    |> mes(
      "The air that quietly drifts here holds her fragrant scent. You can use this wind to borrow her power."
    )
    |> next()
    |> mes("[Dvalin]")
    |> mes("Aside from Freya, I have")
    |> mes(
      "no special love for the gods or giants. But I am intrigued by you humans. Your race is one of both love and hatred, life and destruction."
    )
    |> next()
    |> mes("[Dvalin]")
    |> mes(
      "Go now and seek Berling. He is sleeping near a river linked to Mount Mjolnir. Travel West to find the river were Freya's Teardrops have fallen."
    )
    |> next()
    |> mes("[Dvalin]")
    |> mes(
      "If the phantom of water gives you a question, answer it. The answer is the punishment that Odin gave to our goddess."
    )
    |> next()
    |> mes("[Dvalin]")
    |> mes(
      "Until thousands of Valkyries filled up Valhala, they had to repeatedly live, die, then be reborn the next day only to die again."
    )
    |> next()
    |> mes("[Dvalin]")
    |> mes("Think about")
    |> mes("who they were.")
    |> mes("That's all I can tell you.")
    |> next()
    |> mes("[Dvalin]")
    |> mes("Somehow, I know")
    |> mes("you are the one who")
    |> mes("can answer the question.")
    |> mes("Hahahaha!")
    |> set_char_var(:god_brising, 43)
    |> close2()
    |> hideonnpc("Dvalin#1")
  end

  defp remind_visitor(ctx) do
    ctx
    |> mes("[Dvalin]")
    |> mes(
      "Why do you keep calling me? I did everything I can do for you. I even gave you the key to the question."
    )
    |> next()
    |> mes("[Dvalin]")
    |> mes("From now on,")
    |> mes("it's all up to you.")
    |> mes("Now, go wake Berling...")
    |> close2()
    |> hideonnpc("Dvalin#1")
  end
end

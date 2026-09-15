defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.Master do
  @moduledoc """
  Surveys visitors about their favorite Kafra employee.

  ## Behavior

  - Presents six Kafra candidates to visitors who agree to the survey.
  - Responds differently to each candidate choice.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldeba_in",
        x: 156,
        y: 179,
        dir: 4,
        sprite: 61,
        name: "Master",
        scope: :shared,
        unique_name: "Master#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Master]")
      |> mes("The Kafra Corporation Headquarters is located here in Al De Baran.")
      |> mes("Do you know")
      |> mes("what that means?")
      |> next()
      |> mes("[Master]")
      |> mes(
        "That means those cute Kafra Employees come here for their lunch breaks! Isn't that great?!"
      )
      |> next()
      |> mes("[Master]")
      |> mes("Alright, then!")
      |> mes("Pop Quiz Time!")
      |> mes("Who's your")
      |> mes("favorite Kafra girl?")
      |> next()

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_FEMALE, 0) do
        ctx
        |> mes("[Master]")
        |> mes(
          "Oh, and don't worry. I know that girls have some kind of opinion about how pretty other girls are."
        )
        |> next()
      else
        ctx
      end

    {ctx, choice} = select(ctx, ["Awesome!", "No way, I ain't a perv."])

    if choice == 1 do
      run_survey(ctx)
    else
      reject_survey(ctx)
    end
  end

  defp run_survey(ctx) do
    {ctx, candidate} =
      ctx
      |> mes("[Master]")
      |> mes("Alright, here we go!")
      |> mes("Choose your favorite Kafra Lady!")
      |> next()
      |> mes("[Master]")
      |> mes(
        "The original Kafra Mascot, the classic blue haired lady! Candidate Number One: ^3355FFPavianne^000000!"
      )
      |> next()
      |> mes("[Master]")
      |> mes(
        "Her graceful ponytail takes men's breath away! The fan favorite amongst teen males! Candidate Number Two: ^5533FFBlossom^000000!"
      )
      |> next()
      |> mes("[Master]")
      |> mes(
        "Her long, straight hair, like silk from the East, is her charm point. Direct from Payon, it's Candidate Number Three: ^555555Jasmine^000000!"
      )
      |> next()
      |> mes("[Master]")
      |> mes(
        "A tomboy with bright orange, shortly cut hair. Candidate Number Four: ^1133DDRoxie^000000!"
      )
      |> next()
      |> mes("[Master]")
      |> mes(
        "Intelligent, sophisticated and never seen without her luxurious glasses. It's Candidate Number Five: ^33FF55Leilah^000000!"
      )
      |> next()
      |> mes("[Master]")
      |> mes(
        "Pretty, cute and fresh faced. Although She looks young and immature, she's the best staff!"
      )
      |> mes("Candidate Number (6) ^AAAA00Curly Sue^000000 !!")
      |> next()
      |> select([
        "(1) Pavianne",
        "(2) Blossom",
        "(3) Jasmine",
        "(4) Roxie",
        "(5) Leilah",
        "(6) Curly Sue"
      ])

    respond_to_candidate(ctx, candidate)
  end

  defp respond_to_candidate(ctx, 1) do
    ctx
    |> mes("[Master]")
    |> mes("Oh~")
    |> mes("So you're a lover of classics. I respect that very much.")
    |> next()
    |> mes("[Master]")
    |> mes(
      "I'll also guess that you tend to enjoy the original movie more than sequels, and dislike bad imitations. Am I right?"
    )
    |> close()
  end

  defp respond_to_candidate(ctx, 2) do
    ctx
    |> mes("[Master]")
    |> mes("Hmmm...")
    |> mes(
      "Blossom strikes me as the girl-next-door type. So I guess that's the type of girl you're attracted to, eh?"
    )
    |> close()
  end

  defp respond_to_candidate(ctx, 3) do
    ctx
    |> mes("[Master]")
    |> mes("So...")
    |> mes(
      "Long, luxurious hair is important to you, hmm? I suppose it such hair makes a woman look quite elegant."
    )
    |> close()
  end

  defp respond_to_candidate(ctx, 4) do
    ctx
    |> mes("[Master]")
    |> mes("Ah, so you tend to like active, spontaneous types. I can understand that...")
    |> next()
    |> mes("[Master]")
    |> mes(
      "Since Roxie isn't exactly the demure housewife type, you probably have an open mind when it comes to defining femininity, right?"
    )
    |> close()
  end

  defp respond_to_candidate(ctx, 5) do
    ctx
    |> mes("[Master]")
    |> mes("Ah, so you like the intellectual type. That's good, that's good.")
    |> next()
    |> mes("[Master]")
    |> mes(
      "Still, that Leilah can be cold as stone sometimes. I've seen her shrug off many young men and crush even more hearts!"
    )
    |> close()
  end

  defp respond_to_candidate(ctx, 6) do
    ctx
    |> mes("[Master]")
    |> mes("Say whaaat?!")
    |> mes("She's too young!")
    |> close()
  end

  defp respond_to_candidate(ctx, _candidate), do: reject_survey(ctx)

  defp reject_survey(ctx) do
    ctx
    |> mes("[Master]")
    |> mes(
      "But I worked so hard on this delightful survey! Come now, be a sport! Admiring a pretty woman is like appreciating fine art."
    )
    |> close()
  end
end

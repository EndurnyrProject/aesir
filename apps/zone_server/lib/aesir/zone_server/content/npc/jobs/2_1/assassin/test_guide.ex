defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Assassin.TestGuide do
  @moduledoc """
  Barcardi's briefing for the Assassin target test that follows the written exam.

  ## Behavior

  - Sends applicants who have not passed the written test back to the exam entrance.
  - Briefs applicants who just passed about finding and killing the target monsters.
  - Lets other applicants continue or quit, resetting their test progress on quitting.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - Silent
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Zephyrus_cr
    - brianluau
    - Kisuka
    - JayPee
    - Euphy
    - MrAntares
    - Atemo

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_moc_16",
        x: 21,
        y: 165,
        dir: 2,
        sprite: 725,
        name: "Test Guide",
        scope: :shared,
        unique_name: "Test Guide#ASN",
        trigger: {4, 4}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    cond do
      get_char_var(ctx, :ASSIN_Q2, 0) < 5 ->
        ctx
        |> mes("[Barcardi]")
        |> mes(
          "You can't take the next trial without passing the written test first. You better speak to the Anonymous One..."
        )
        |> close()
        |> warp("in_moc_16", 19, 76)

      get_char_var(ctx, :ASSIN_Q, 0) == 1 and get_char_var(ctx, :ASSIN_Q2, 0) == 5 ->
        brief_target_test(ctx)

      true ->
        offer_break(ctx)
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp brief_target_test(ctx) do
    ctx
    |> mes("[Barcardi]")
    |> mes("#{char_name(ctx, 0)}...")
    |> mes("You passed the test..?")
    |> next()
    |> mes("[Barcardi]")
    |> mes(
      "To be honest, I want to grant you the job change without any other condition. Too many pathetic people don't even have the basic knowledge to be Assassins..."
    )
    |> next()
    |> mes("[Barcardi]")
    |> mes(
      "We must keep our dignity as Assassins and be truly great! Regrettably, there are too many idiots that don't have any pride."
    )
    |> next()
    |> mes("[Barcardi]")
    |> mes(
      "All Assassins must respect the enemies they slay, the blood that they spill, and above all, maintain their sense of dignity!"
    )
    |> next()
    |> mes("[Barcardi]")
    |> mes("Alright. This next trial will test your ability to quickly find your target.")
    |> next()
    |> mes("[Barcardi]")
    |> mes(
      "If you're going to be an Assassin, we need to determine whether or not you can distinguish friend from foe in an instant."
    )
    |> next()
    |> mes("[Barcardi]")
    |> mes(
      "The main goal of this test is to find and kill as many monsters named ^008800Job change target^000000 as possible."
    )
    |> next()
    |> mes("[Barcardi]")
    |> mes("You must kill at least")
    |> mes(
      "6 ^008800Job change target^000000 monsters. They're intermingled among similar looking monsters, so you need to be careful..."
    )
    |> next()
    |> mes("[Barcardi]")
    |> mes("If you fail, you'll have to restart this test. Go to the room above")
    |> mes("me to be transported to the Test Hall.")
    |> next()
    |> mes("[Barcardi]")
    |> mes(
      "Only one person is allowed to take the test at a time, so if anyone is taking the test, you'll have to wait until that person finishes."
    )
    |> close()
  end

  defp offer_break(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Barcardi]")
      |> mes("Hey, don't be too hard")
      |> mes("on yourself. Cheer up!")
      |> next()
      |> mes("[Barcardi]")
      |> mes(
        "Hmm, if you're exhausted, I'm willing to bring you back. Of course, if you leave, you'll have to take the job test over again. So what do you want to do?"
      )
      |> next()
      |> select(["Continue!", "Quit the job change test for now."])

    if choice == 1 do
      ctx
      |> mes("[Barcardi]")
      |> mes("Good choice!")
      |> mes("Remember, you")
      |> mes("must find and kill")
      |> mes("6 ^008800Job change target^000000 monsters!")
      |> mes("Good luck!")
      |> close()
    else
      ctx
      |> mes("[Barcardi]")
      |> mes("Alright...")
      |> mes("I guess you")
      |> mes("could use a break...")
      |> close()
      |> set_char_var(:ASSIN_Q, 0)
      |> set_char_var(:ASSIN_Q2, 0)
      |> changequest(8003, 8000)
      |> warp("in_moc_16", 19, 13)
    end
  end
end
